#!/usr/bin/env python3
"""Generate the Dungeon atlas and the MDL-vs-ZIL prose comparison.

Reads the 1981-07-22 MDL dungeon and the Zork I/II/III ZIL trees,
cross-references them, and writes the two documents under docs/games/.

    bin/atlas/build_atlas.py
    bin/atlas/build_atlas.py --audit    # list every pairing, write nothing

The source trees are third-party checkouts and are deliberately not vendored:
the 1981 MDL is the one body of source `THIRD_PARTY_NOTICES` records as having
reached the public without a clear licence grant, which is why the adopted prose
policy reproduces none of its text. Fetch them yourself and point the generator
at them with --sources or GNUSTO_ZORK_SOURCES; the default is .context/reference/,
which is gitignored.
"""

from __future__ import annotations

import argparse
import difflib
import os
import re
import subprocess
import sys
import textwrap
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from mdl_reader import MdlRoom, ZilEntity, parse_mdl_dungeon, parse_zil

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs" / "games"
DEFAULT_SOURCES = ROOT / ".context" / "reference"

MDL_SUBPATH = Path("mdlzork/mdlzork_810722/original_source/dung.355")
ZIL_SUBPATHS = {
    "Zork I": Path("historicalsource-zork1"),
    "Zork II": Path("historicalsource-zork2"),
    "Zork III": Path("historicalsource-zork3"),
}

# Where a trilogy room can be paired in more than one game — which only graph
# matching can produce, since a name shared by two games is ambiguous by
# construction — the earliest game wins. Zork I first: it is the game
# `Sources/Zork1/` is built from, so its row is the one a reader can check.
GAME_ORDER = list(ZIL_SUBPATHS)

# Areas the mainframe map divides into, in the order the atlas lists them.
# Used only to group it readably; not a claim about the original's own
# structure, which has no region concept.
MAIN_REGION = "Main dungeon"
REGION_PREFIXES = [
    ("Bank of Zork", "BK"),
    ("Mirror box / Royal Puzzle", "MR"),
]
ENDGAME_REGION = "Endgame"
REGION_ORDER = [MAIN_REGION, *(label for label, _ in REGION_PREFIXES), ENDGAME_REGION]


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def norm(text: str) -> str:
    """Collapse whitespace and case for comparison."""
    return re.sub(r"\s+", " ", text or "").strip().lower()


def similarity(a: str, b: str) -> float:
    return difflib.SequenceMatcher(None, norm(a), norm(b)).ratio()


def bucket(a: str, b: str) -> str:
    if not a or not b:
        return "unmatched"
    if norm(a) == norm(b):
        return "identical"
    return "minor" if similarity(a, b) >= 0.85 else "substantial"


@dataclass(frozen=True)
class Comparison:
    """One entity's mainframe text set against its trilogy text."""

    kind: str  # 'room' | 'object'
    id: str
    name: str
    mainframe: str
    trilogy: str
    game: str


@dataclass(frozen=True)
class Sources:
    """Where the two bodies of third-party source live.

    All four trees are a hard precondition. A run missing one still writes a
    perfectly plausible-looking Coverage table, with figures quietly too low —
    and these documents are committed, so a degraded run is worse than none.
    """

    root: Path

    @property
    def mdl(self) -> Path:
        return self.root / MDL_SUBPATH

    def zil(self, game: str) -> Path:
        return self.root / ZIL_SUBPATHS[game]

    def mdl_code(self) -> list[Path]:
        """The MDL game code — every source file beside `dung.355`.

        `dung.355` is data: it declares the dungeon and says where things start.
        Anything that arrives later is put there from here — the diamond the
        machine makes, the bauble the songbird drops — so these files are the only
        evidence separating content a puzzle produces from content nothing reaches.
        """
        return sorted(
            p for p in self.mdl.parent.glob("*") if p.is_file() and p != self.mdl
        )

    def missing(self) -> list[Path]:
        absent = [self.zil(g) for g in GAME_ORDER if not self.zil(g).is_dir()]
        if not self.mdl.is_file():
            return [self.mdl] + absent
        # `dung.355` alone is not enough. Without its siblings every object the
        # game places at runtime reads as unreachable, which is a plausible-looking
        # wrong answer in a committed document — the same reason all four trees are
        # required rather than warned about.
        return ([] if self.mdl_code() else [self.mdl.parent]) + absent

    def complaint(self) -> str:
        wanted = "\n".join(
            f"    {p}" for p in [self.root / MDL_SUBPATH.parts[0], *map(self.zil, GAME_ORDER)]
        )
        return (
            "missing Zork sources:\n"
            + "\n".join(f"    {p}" for p in self.missing())
            + f"\n\nExpected all of:\n{wanted}\n\n"
            "The first is github.com/historicalsource/mdlzork; the rest are that\n"
            "org's zork1/zork2/zork3. Point --sources or GNUSTO_ZORK_SOURCES at\n"
            "them. They are not vendored — see this file's docstring and\n"
            "THIRD_PARTY_NOTICES for why."
        )

    def load_zil(self) -> list[ZilEntity]:
        return [
            entity
            for game in GAME_ORDER
            for f in sorted(self.zil(game).glob("*.zil"))
            for entity in parse_zil(read(f), game)
        ]


# ----------------------------------------------------------------- placement

# How MDL code reaches an object it did not declare in place: by id string.
# `<SFIND-OBJ "DIAMO">` is the machine conjuring the diamond. Matching the form
# rather than the bare id keeps `EGG` out of `EGG-SOLVE`.
_OBJECT_LOOKUP = re.compile(r'\b(?:S?FIND-OBJ|GET-OBJ)\s+"([A-Z0-9]+)"')

# Why a particular object is one nothing places. That is a fact about the source
# rather than about its structure, so it is read by hand, once, and recorded here;
# an object that turns up in that row without a note is one nobody has looked at.
UNPLACED_NOTES = {
    "BUTTO": "a placeholder with no name, no description and no value. The comment "
    "above it in `dung.355` says it is kept only so that restoring a save file "
    "written by an older build still works.",
}

PLACEMENT_LABELS = {
    "room": "In a room",
    "object": "Inside another object",
    "code": "Named only by the game code",
    "nowhere": "Named nowhere but its own declaration",
}


@dataclass(frozen=True)
class Placement:
    """Where one object starts, and what says so."""

    kind: str  # a key of PLACEMENT_LABELS
    where: str = ""  # the room or the containing object
    cites: tuple[str, ...] = ()  # file:line, for kind 'code'

    def cell(self) -> str:
        """How the atlas's `starts in` column says it, in one table cell."""
        if self.kind == "room":
            return f"`{self.where}`"
        if self.kind == "object":
            return f"in `{self.where}`"
        return "by code" if self.kind == "code" else "—"

    def detail(self, oid: str, placed: dict[str, Placement]) -> str:
        """The whole claim, for `--audit` to print.

        A nested object is only as reachable as what finally holds it, so its
        claim is the chain rather than the container next to it.
        """
        if self.kind == "object":
            return " in ".join(chain(oid, placed))
        return self.where or ", ".join(self.cites) or "—"


def object_placements(
    rooms: list, objects: list, code: list[Path]
) -> tuple[dict[str, Placement], dict[str, str]]:
    """Say where every object starts, and on what evidence.

    Four answers, because three do not fit the source. A room's contents list
    places most objects. An object's contents list places the rest of the ones
    the file places at all — the egg in the nest, the canary in the egg — and
    reading only rooms is what made those look unplaced. What neither list
    mentions is either something the running game knows about, or nothing at all.

    That last distinction is the one worth reporting and the one that cannot be
    inferred, so it is cited instead. The claim a citation supports is exactly
    "the game code names this object", not "this line is what puts it in play":
    the placement itself is often several MDL forms away from the lookup, and this
    generator reads structure, not semantics. So the file and line travel with the
    claim and `--audit` prints them. The discrimination that matters survives the
    weaker reading — an object no line of code names can never enter play.

    Also returns any contents entry naming no declared object, so a dangling
    reference is reported rather than silently dropped.
    """
    declared = {o.id for o in objects}
    holders: dict[str, Placement] = {}
    unresolved: dict[str, str] = {}
    for kind, group in (("room", rooms), ("object", objects)):
        for holder in group:
            for oid in holder.contents:
                if oid not in declared:
                    unresolved.setdefault(oid, holder.id)
                else:
                    holders.setdefault(oid, Placement(kind, holder.id))

    cites: dict[str, list[str]] = defaultdict(list)
    for path in code:
        for n, line in enumerate(read(path).splitlines(), 1):
            if "-OBJ" not in line:
                continue
            for m in _OBJECT_LOOKUP.finditer(line):
                if m.group(1) in declared:
                    cites[m.group(1)].append(f"{path.name}:{n}")

    def elsewhere(oid: str) -> Placement:
        """Neither list mentions it: the code either knows it or nothing does."""
        if oid in cites:
            return Placement("code", cites=tuple(cites[oid]))
        return Placement("nowhere")

    placed = {oid: holders.get(oid) or elsewhere(oid) for oid in sorted(declared)}
    return placed, unresolved


def chain(oid: str, placed: dict[str, Placement]) -> list[str]:
    """The containment chain out of `oid`, ending at whatever finally holds it."""
    out: list[str] = []
    while (p := placed[oid]).kind == "object" and p.where not in out:
        out.append(p.where)
        oid = p.where
    return out


def placement_tally(
    objects: list, placed: dict[str, Placement]
) -> dict[str, tuple[list[str], int]]:
    """Group the objects by where they start, with the points riding on each.

    One tally, so the section the atlas publishes and the listing `--audit`
    prints cannot drift apart.
    """
    value = {o.id: o.find_value + o.case_value for o in objects}
    grouped: dict[str, list[str]] = {kind: [] for kind in PLACEMENT_LABELS}
    for oid in sorted(placed):
        grouped[placed[oid].kind].append(oid)
    return {kind: (g, sum(value[o] for o in g)) for kind, g in grouped.items()}


# ------------------------------------------------------------- cross-matching

# A destination the readers could not resolve to a room: a blocked or
# conditional exit, an indirection through a global, an unparsed form.
_REAL_ID = re.compile(r"[A-Z][A-Z0-9-]*")


def _is_room(dest: str, known: dict) -> bool:
    return bool(_REAL_ID.fullmatch(dest)) and dest in known


def _adjacency(
    nodes: dict, exits_of
) -> tuple[dict[str, dict[str, str]], dict[str, dict[str, list[str]]]]:
    """Index a map's edges by direction, forwards and backwards.

    The reverse index matters as much as the forward one: a maze passage is
    often reached from an already-identified room before it leads to one.
    """
    out: dict[str, dict[str, str]] = defaultdict(dict)
    into: dict[str, dict[str, list[str]]] = defaultdict(lambda: defaultdict(list))
    for nid, node in nodes.items():
        for way, dest in exits_of(node):
            if not _is_room(dest, nodes) or way in out[nid]:
                continue
            out[nid][way] = dest
            into[dest][way].append(nid)
    return out, into


# How many edges must agree before a graph-derived pairing is believed.
#
# One is not enough, and `--audit` says so plainly — it prints what this
# threshold threw out, so the claim is checkable rather than folklore. Every
# pair the propagation reached on a single agreeing edge was wrong by exactly
# one room: the Grail Room landing on Path Near Stream, the Ruby Room on the Ice
# Room next door. Every pair reached on two or more was right. One shared edge
# only says two rooms are both somewhere near a third.
#
# The price is the odd true pairing that has just one edge to stand on: the Land
# of the Living Dead, which Zork I renamed Land of the Dead. That is the class of
# match this document has always said it cannot make, so leaving it unmatched
# keeps the figure a floor rather than making it a guess.
MIN_CORROBORATION = 2


def pair_by_graph(
    mdl_rooms: dict, zil_rooms: dict, seeds: dict[str, str]
) -> tuple[dict[str, str], dict[str, tuple[str, int]]]:
    """Extend `seeds` (mdl id -> zil id) outward along matching exits.

    The mazes defeat name matching by design — fifteen mainframe rooms are
    called *Maze* and the trilogy has fifteen of its own — but both sources
    carry complete exit tables, so the rooms can be identified by where they sit
    in the graph instead of by what they are called.

    Two passes. **Grow**: from a pair already believed, an edge in the same
    direction proposes the pair at its far end, and a proposal is taken only when
    it is *mutually unique* — exactly one candidate each way, and neither end
    already spoken for. **Prune**: drop anything the finished match does not
    corroborate MIN_CORROBORATION times over, and keep dropping, since losing a
    pair can undercut the one it vouched for.

    So the match grows outward from ground truth and then has to survive being
    checked against itself. The seeds are name matches and are never pruned.

    Returns the surviving pairs, and separately what the prune rejected and on
    how many agreeing edges — the evidence for MIN_CORROBORATION, which `--audit`
    prints so the threshold can be re-checked rather than taken on trust.
    """
    m_out, m_in = _adjacency(mdl_rooms, lambda r: r.exits)
    z_out, z_in = _adjacency(zil_rooms, lambda z: z.exits)
    pairs = dict(seeds)

    def corroboration(mid: str, zid: str) -> int:
        """How many of a pair's exits land on another pair, the same way round."""
        agree = sum(
            1 for way in m_out[mid].keys() & z_out[zid].keys()
            if pairs.get(m_out[mid][way]) == z_out[zid][way]
        )
        for way in m_in[mid].keys() & z_in[zid].keys():
            agree += sum(1 for src in m_in[mid][way] if pairs.get(src) in z_in[zid][way])
        return agree

    while True:
        proposed: dict[str, set[str]] = defaultdict(set)
        for mid, zid in pairs.items():
            for way in m_out[mid].keys() & z_out[zid].keys():
                proposed[m_out[mid][way]].add(z_out[zid][way])
            for way in m_in[mid].keys() & z_in[zid].keys():
                # Several rooms can share a direction into this one; that says
                # nothing about which is which, so only a lone source counts.
                m_src, z_src = m_in[mid][way], z_in[zid][way]
                if len(m_src) == len(z_src) == 1:
                    proposed[m_src[0]].add(z_src[0])

        claimed: dict[str, set[str]] = defaultdict(set)
        for mid, zids in proposed.items():
            for zid in zids:
                claimed[zid].add(mid)

        taken = set(pairs.values())
        found: dict[str, str] = {}
        for mid, zids in sorted(proposed.items()):
            if mid in pairs or len(zids) != 1:
                continue
            (zid,) = zids
            if zid in taken or len(claimed[zid] - pairs.keys()) != 1:
                continue
            found[mid] = zid
        if not found:
            break
        pairs.update(found)

    rejected: dict[str, tuple[str, int]] = {}
    while True:
        weak = {
            mid: (pairs[mid], agree)
            for mid in sorted(pairs)
            if mid not in seeds
            and (agree := corroboration(mid, pairs[mid])) < MIN_CORROBORATION
        }
        if not weak:
            return pairs, rejected
        rejected.update(weak)
        for mid in weak:
            del pairs[mid]


def by_holder(zil_objects: list[ZilEntity]) -> dict[str, list[ZilEntity]]:
    """Index a game's objects by what holds them. ZIL states it as `(IN …)`,
    naming a room or another object indifferently."""
    index: dict[str, list[ZilEntity]] = defaultdict(list)
    for obj in zil_objects:
        if obj.location:
            index[obj.location].append(obj)
    return index


def pair_contents(
    contents: dict[str, list[str]],
    mdl_objects: dict,
    zil_by_holder: dict[str, list[ZilEntity]],
    holder_pairs: dict[str, str],
) -> dict[str, ZilEntity]:
    """Identify an object by what it starts inside, once the holders are paired.

    The second half of the same problem: two mirrors, two leaks, two red
    buttons. Where the things holding them are known to correspond, the name is
    unambiguous again — but only inside that pair of holders, so the same
    mutual-uniqueness rule applies.

    A holder is a room or another object, indifferently: MDL states both as a
    contents list, so the water in the bottle resolves exactly the way the hook in
    the Dome Room does.
    """
    pairs: dict[str, ZilEntity] = {}
    for mid, zid in sorted(holder_pairs.items()):
        mine = _by_name(mdl_objects[o] for o in contents.get(mid, ()) if o in mdl_objects)
        theirs = _by_name(zil_by_holder[zid], lambda o: o.desc)
        for name in mine.keys() & theirs.keys():
            if len(mine[name]) == len(theirs[name]) == 1:
                pairs.setdefault(mine[name][0].id, theirs[name][0])
    return pairs


def _by_name(entities, name_of=lambda e: e.name) -> dict[str, list]:
    """Group entities under their normalised display name."""
    grouped: dict[str, list] = defaultdict(list)
    for entity in entities:
        if key := norm(name_of(entity)):
            grouped[key].append(entity)
    return grouped


def pair_by_name(entities, zil_entities) -> dict[str, ZilEntity]:
    """Pair everything whose display name identifies exactly one entity on each side.

    A name shared by several rooms — *Maze*, *Dead End*, *Narrow Room* — names
    none of them, so matching on it would pair arbitrary members of the two sets.
    Those are left for `pair_by_graph` rather than silently resolved to whichever
    entity happened to be parsed last.

    Ambiguity is judged over the trilogy pooled, not per game, so a name two
    games share is excluded here too. That is deliberate: it keeps this the
    conservative half of the pair, and `pair_by_graph` can still reach those
    rooms with a game to attribute them to.
    """
    mine, theirs = _by_name(entities), _by_name(zil_entities, lambda z: z.desc)
    return {
        group[0].id: theirs[name][0]
        for name, group in mine.items()
        if len(group) == 1 and len(theirs.get(name, ())) == 1
    }


@dataclass
class Matching:
    """Which mainframe entity is which trilogy entity, and how we know.

    Two strategies, kept apart because they carry different weight and the atlas
    reports them as separate rows: the display name where it identifies one
    entity on each side, and position in the map where it does not.
    """

    rooms: dict[str, ZilEntity] = field(default_factory=dict)
    objects: dict[str, ZilEntity] = field(default_factory=dict)
    rooms_by_name: dict[str, ZilEntity] = field(default_factory=dict)
    objects_by_name: dict[str, ZilEntity] = field(default_factory=dict)
    rooms_by_graph: dict[str, ZilEntity] = field(default_factory=dict)
    objects_by_graph: dict[str, ZilEntity] = field(default_factory=dict)
    rejected: dict[str, tuple[ZilEntity, int]] = field(default_factory=dict)
    # What the containment pass said about pairs that were already settled.
    # A second, independent route to the same answer is worth as much as a new
    # pair; a second route to a different one would mean one of them is wrong.
    # The kept pair is `objects[id]` either way, so only the challenger is stored.
    confirmed: set[str] = field(default_factory=set)
    contradicted: dict[str, ZilEntity] = field(default_factory=dict)

    def of(self, eid: str, kind: str) -> ZilEntity | None:
        return (self.rooms if kind == "ROOM" else self.objects).get(eid)


def cross_reference(rooms: list, objects: list, zil: list[ZilEntity]) -> Matching:
    """Pair the mainframe's rooms and objects with the trilogy's.

    Name matching first, over the trilogy pooled. Then each game's map is walked
    separately, seeded with the pairs the name already settled, so what the name
    could not say the graph can. A room paired in more than one game — which only
    the graph can produce — resolves to the earliest, per GAME_ORDER.

    Then the same step once more, one level in: an object holds objects the way a
    room does, so a settled container settles what is inside it. That pass runs to
    a fixpoint, since pairing a container can settle a container it holds.
    """
    zil_rooms = [z for z in zil if z.kind == "ROOM"]
    zil_objects = [z for z in zil if z.kind == "OBJECT"]
    mdl_rooms = {r.id: r for r in rooms}
    mdl_objects = {o.id: o for o in objects}
    held_by = {g: by_holder([o for o in zil_objects if o.game == g]) for g in GAME_ORDER}
    room_contents = {r.id: r.contents for r in rooms}
    object_contents = {o.id: o.contents for o in objects if o.contents}

    m = Matching(
        rooms_by_name=pair_by_name(rooms, zil_rooms),
        objects_by_name=pair_by_name(objects, zil_objects),
    )

    for game in GAME_ORDER:
        here = {z.id: z for z in zil_rooms if z.game == game}
        seeds = {mid: z.id for mid, z in m.rooms_by_name.items() if z.id in here}
        placed, rejected = pair_by_graph(mdl_rooms, here, seeds)

        for mid, zid in placed.items():
            if mid not in m.rooms_by_name:
                m.rooms_by_graph.setdefault(mid, here[zid])
        for mid, (zid, agree) in rejected.items():
            m.rejected.setdefault(mid, (here[zid], agree))
        for mid, z in pair_contents(
            room_contents, mdl_objects, held_by[game], placed
        ).items():
            if mid not in m.objects_by_name:
                m.objects_by_graph.setdefault(mid, z)

    m.rooms = {**m.rooms_by_name, **m.rooms_by_graph}
    m.objects = {**m.objects_by_name, **m.objects_by_graph}

    def by_containment() -> dict[str, ZilEntity]:
        """Everything a settled container settles, over all three games."""
        out: dict[str, ZilEntity] = {}
        for game in GAME_ORDER:
            holders = {mid: z.id for mid, z in m.objects.items() if z.game == game}
            for mid, z in pair_contents(
                object_contents, mdl_objects, held_by[game], holders
            ).items():
                out.setdefault(mid, z)
        return out

    while new := {mid: z for mid, z in by_containment().items() if mid not in m.objects}:
        m.objects_by_graph.update(new)
        m.objects.update(new)

    # Run once more over the settled match, now purely as a check: every pair
    # containment reaches that something else had already settled is a second,
    # independent route to an answer — or, if the two differ, evidence that one
    # of them is wrong. The earlier pair stands either way; this only reports.
    for mid, z in by_containment().items():
        if (was := m.objects[mid]).id == z.id:
            m.confirmed.add(mid)
        elif was.game == z.game:
            m.contradicted[mid] = z
    return m


def zork1_swift_index() -> dict[str, str]:
    """Map a lowercased room/item name to the Sources/Zork1 file declaring it.

    Uses the repo's own prose constants: Zork1 declares one constant per entity,
    so a grep for the display name is a reliable locator.
    """
    index: dict[str, str] = {}
    src = ROOT / "Sources" / "Zork1"
    for f in sorted(src.rglob("*.swift")):
        text = read(f)
        for m in re.finditer(r'name\("([^"]+)"\)', text):
            index.setdefault(m.group(1).lower(), str(f.relative_to(ROOT)))
    return index


def region_of(room: MdlRoom) -> str:
    if "RENDGAME" in room.flags:
        return ENDGAME_REGION
    for label, prefix in REGION_PREFIXES:
        if room.id.startswith(prefix):
            return label
    return MAIN_REGION


def md_escape(text: str) -> str:
    return (text or "").replace("|", "\\|").replace("\n", " ").strip()


def para(text: str, indent: str = "") -> str:
    """Wrap a paragraph to the width the hand-written prose here is written at.

    Only for the paragraphs that interpolate a figure: a number that grows a
    digit would otherwise push a hand-wrapped line over on its own.
    """
    return textwrap.fill(text, 79, subsequent_indent=indent)


def truncate(text: str, n: int = 90) -> str:
    text = md_escape(text)
    return text if len(text) <= n else text[: n - 1] + "…"


def audit(
    rooms: list,
    objects: list,
    m: Matching,
    placed: dict[str, Placement],
    unresolved: dict[str, str],
) -> int:
    """Print every pairing and every placement so a human can check them. Writes
    nothing.

    A generated coverage figure is only worth what its worst pairing is worth,
    and the graph-derived ones are the pairings nobody wrote down by hand. The
    rejected section is the evidence for MIN_CORROBORATION: if a run ever shows
    a sound pairing in there, or a bad one above the line, the threshold is
    wrong and this is how you would find out.

    Placement is here for the same reason. Saying an object is reachable because
    the game code puts it somewhere is a claim about code this generator does not
    interpret, so the claim travels with its file and line.
    """
    def line(eid: str, name: str, z: ZilEntity, note: str = "") -> None:
        print(f"  {eid:8s} {name[:34]:36s} -> {z.id:24s} {z.desc[:30]:32s} "
              f"{z.game}{note}")

    for label, entities, by_name, by_graph in (
        ("ROOMS", rooms, m.rooms_by_name, m.rooms_by_graph),
        ("OBJECTS", objects, m.objects_by_name, m.objects_by_graph),
    ):
        named = {e.id: e.name for e in entities}
        for how, pairs in (("name", by_name), ("graph", by_graph)):
            print(f"\n=== {label} matched by {how} ({len(pairs)}) ===")
            for eid in sorted(pairs):
                line(eid, named[eid], pairs[eid])
        loose = sorted(set(named) - set(by_name) - set(by_graph))
        print(f"\n=== {label} still unmatched ({len(loose)}) ===")
        for eid in loose:
            print(f"  {eid:8s} {named[eid][:60]}")

    named = {r.id: r.name for r in rooms}
    print(f"\n=== ROOMS rejected below MIN_CORROBORATION={MIN_CORROBORATION} "
          f"({len(m.rejected)}) ===")
    for eid in sorted(m.rejected):
        z, agree = m.rejected[eid]
        # A room can be rejected in one game and still be right in another —
        # the trilogy reused rooms across the three. Only the rest are losses.
        note = f"  ({agree} agreeing edge{'' if agree == 1 else 's'})"
        if kept := m.rooms.get(eid):
            note += f"; matched anyway to {kept.id} ({kept.game})"
        line(eid, named[eid], z, note)

    print(f"\n=== OBJECT pairs confirmed a second time by containment "
          f"({len(m.confirmed)}) ===")
    for eid in sorted(m.confirmed):
        print(f"  {eid:8s} -> {m.objects[eid].id}")
    print(f"\n=== OBJECT pairs containment contradicts ({len(m.contradicted)}) ===")
    for eid in sorted(m.contradicted):
        was, now = m.objects[eid], m.contradicted[eid]
        print(f"  {eid:8s} kept {was.id} ({was.game}); containment said {now.id}")

    objs = {o.id: o for o in objects}
    print("\n=== OBJECT placement ===")
    for kind, (group, value) in placement_tally(objects, placed).items():
        print(f"\n--- {PLACEMENT_LABELS[kind]} ({len(group)}, {value} points) ---")
        for eid in group:
            o = objs[eid]
            print(f"  {eid:8s} {o.name[:34]:36s} {o.find_value + o.case_value:3d}  "
                  f"{placed[eid].detail(eid, placed)}")

    print(f"\n=== contents entries naming no declared object ({len(unresolved)}) ===")
    for oid in sorted(unresolved):
        print(f"  {oid:8s} named by {unresolved[oid]}")
    return 0


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--sources", type=Path,
        default=Path(os.environ.get("GNUSTO_ZORK_SOURCES") or DEFAULT_SOURCES),
        help="where the MDL and ZIL checkouts live (env: GNUSTO_ZORK_SOURCES)",
    )
    parser.add_argument(
        "--audit", action="store_true",
        help="list every pairing for checking by hand, and write nothing",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    sources = Sources(args.sources)
    if sources.missing():
        print(sources.complaint(), file=sys.stderr)
        return 1

    rooms, objects = parse_mdl_dungeon(read(sources.mdl))
    zil = sources.load_zil()
    matching = cross_reference(rooms, objects, zil)
    placed, unresolved = object_placements(rooms, objects, sources.mdl_code())
    if args.audit:
        return audit(rooms, objects, matching, placed, unresolved)

    zil_for = matching.of
    swift = zork1_swift_index()

    # ---- scoring, computed the way makstr.44 computes it at build time -----
    eg_rooms = [r for r in rooms if "RENDGAME" in r.flags]
    main_rooms = [r for r in rooms if "RENDGAME" not in r.flags]
    eg_max = sum(r.value for r in eg_rooms)
    LIGHT_SHAFT = 10  # act2.92 adds this to SCORE-MAX outside the dungeon file
    score_max = (
        sum(r.value for r in main_rooms)
        + sum(o.find_value + o.case_value for o in objects)
        + LIGHT_SHAFT
    )

    rev = subprocess.run(
        ["git", "rev-parse", "--short", "HEAD"],
        cwd=ROOT, capture_output=True, text=True,
    ).stdout.strip()

    header = f"""<!-- GENERATED by bin/atlas/build_atlas.py — do not edit by hand. -->

> **Provenance.** Mainframe figures are extracted from the 1981-07-22 MDL
> `dung.355`; trilogy figures from the Zork I/II/III ZIL sources. Both bodies of
> source are permissively licensed — see `THIRD_PARTY_NOTICES` at the repo root
> for the two separate grants and their limits.
>
> Generated against Gnusto `{rev}`.
"""

    # ======================================================== atlas ==========
    lines = [
        "# Dungeon — content atlas",
        "",
        "The machine-extracted inventory of mainframe Zork (MDL, 1981-07-22), the",
        "artifact `Sources/Dungeon/` reconstructs. Every figure here comes from the",
        "source, not from a walkthrough or a memory.",
        "",
        header,
        "## Scoring",
        "",
        "The mainframe keeps **two separate maxima**, and the `score` command reports",
        "whichever the player is currently inside (`rooms.394`, `SCORE-BLESS`). They are",
        "not summed anywhere in the source.",
        "",
        "| Maximum | Value | Composition |",
        "|---|---:|---|",
        f"| `SCORE-MAX` (main dungeon) | **{score_max}** | "
        f"{sum(r.value for r in main_rooms)} room `RVAL` + "
        f"{sum(o.find_value + o.case_value for o in objects)} object `OFVAL`+`OTVAL` + "
        f"{LIGHT_SHAFT} `LIGHT-SHAFT` |",
        f"| `EG-SCORE-MAX` (endgame) | **{eg_max}** | "
        f"room `RVAL` over the {len(eg_rooms)} `RENDGAME` rooms |",
        "",
        "Both are accumulated at build time by `makstr.44`: a room's `RVAL` goes to",
        "`EG-SCORE-MAX` if it carries `RENDGAME` and to `SCORE-MAX` otherwise, while",
        "every object's `OFVAL`+`OTVAL` goes to `SCORE-MAX` unconditionally.",
        "",
        "`LIGHT-SHAFT` is the one award that lives outside the dungeon file: `act2.92`",
        "pays 10 points, once, for reaching the Lower Shaft while it is lit — the basket",
        "and torch puzzle. In Gnusto terms it is an `awardOnce` register, not a room",
        "`VALUE`.",
        "",
        "### What `Sources/Dungeon/` uses",
        "",
        f"**`maxScore` = {score_max + eg_max}** — a single ceiling, the sum of both maxima.",
        "",
        "The commonly cited \"616 points\" appears nowhere in this source, so it is not a",
        f"candidate. The choice is between the original's two separate maxima"
        f" ({score_max} and {eg_max},",
        "reported one at a time by `SCORE-BLESS` in `rooms.394`) and one combined figure.",
        f"**Decision: one ceiling of {score_max + eg_max}.**",
        "",
        "The reasoning:",
        "",
        "- Gnusto models a single `maxScore`, and its bootstrap already totals the award",
        "  table against it and warns on a mismatch. One ceiling makes that invariant do",
        "  real work; two would need the check disabled or worked around.",
        f"- {score_max + eg_max} is genuinely everything a player can score, so the progress",
        "  reading is honest end to end.",
        "- The cost is small and cosmetic: a player who finishes the main dungeon perfectly",
        f"  sees {score_max}/{score_max + eg_max} where the original showed"
        f" {score_max}/{score_max},",
        "  and the endgame then carries them the rest of the way rather than restarting at",
        "  zero. That is a divergence, and belongs in `FIDELITY.md`.",
        "",
        "## Totals",
        "",
        "| | Count |",
        "|---|---:|",
        f"| Rooms | {len(rooms)} |",
        f"| — of them endgame (`RENDGAME`) | {len(eg_rooms)} |",
        f"| Objects | {len(objects)} |",
        f"| — of them valued (treasures) | "
        f"{len([o for o in objects if o.find_value or o.case_value])} |",
        "",
    ]

    # rooms grouped by region
    by_region: dict[str, list[MdlRoom]] = defaultdict(list)
    for r in rooms:
        by_region[region_of(r)].append(r)

    lines += ["## Rooms", ""]
    for region in REGION_ORDER:
        group = by_region.get(region, [])
        if not group:
            continue
        lines += [
            f"### {region} ({len(group)} rooms)",
            "",
            "| id | name | RVAL | exits | trilogy | in `Sources/Zork1/` |",
            "|---|---|---:|---:|---|---|",
        ]
        for r in sorted(group, key=lambda x: x.id):
            z = zil_for(r.id, "ROOM")
            here = swift.get(norm(r.name), "")
            lines.append(
                f"| `{r.id}` | {md_escape(r.name)} | {r.value or ''} | {len(r.exits)} "
                f"| {z.game if z else '—'} | {'`' + here + '`' if here else '—'} |"
            )
        lines.append("")

    tally = placement_tally(objects, placed)
    roomless = sum(pts for kind, (_, pts) in tally.items() if kind != "room")
    nested, _ = tally["object"]
    rooted = Counter(placed[chain(o, placed)[-1]].kind for o in nested)
    elsewhere = len(tally["code"][0]) + len(tally["nowhere"][0])

    lines += [
        "## Objects",
        "",
        "`OFVAL` is the score for first acquiring the object, `OTVAL` for depositing it",
        "in the trophy case. `OSIZE` is its weight against the carrying capacity.",
        "**starts in** is the room or the object it begins inside; see Placement below",
        f"for the {elsewhere} entries that are neither.",
        "",
        "| id | name | OSIZE | OFVAL | OTVAL | starts in | trilogy | in `Sources/Zork1/` |",
        "|---|---|---:|---:|---:|---|---|---|",
    ]
    for o in sorted(objects, key=lambda x: x.id):
        z = zil_for(o.id, "OBJECT")
        here = swift.get(norm(o.name), "")
        lines.append(
            f"| `{o.id}` | {md_escape(o.name)} | {o.size or ''} | {o.find_value or ''} "
            f"| {o.case_value or ''} | {placed[o.id].cell()} | {z.game if z else '—'} "
            f"| {'`' + here + '`' if here else '—'} |"
        )

    lines += [
        "",
        "## Placement",
        "",
        para(
            "Where each object starts, taken from the source's own contents lists. A"
            " room says what begins in it; an object says the same about what begins"
            " inside it. Reading only the first is what used to make a nested object"
            f" look unplaced, and it left {roomless} of the"
            f" {sum(pts for _, pts in tally.values())} points in object values sitting"
            " in entries that read as unreachable."
        ),
        "",
        "| Where an object starts | Objects | `OFVAL`+`OTVAL` |",
        "|---|---:|---:|",
        *(
            f"| {label} | {len(tally[kind][0])} | {tally[kind][1]} |"
            for kind, label in PLACEMENT_LABELS.items()
        ),
        "",
        para(
            f"Nesting accounts for {tally['object'][1]} of those {roomless} points."
            f" Followed to what finally holds it, {rooted['room']} of the {len(nested)}"
            " nested objects end in a room — the egg in the nest, the canary in the egg,"
            " the emerald in the buoy, the crown in the safe, the violin in the steel"
            f" box, the Flathead stamp in the purple book. The other {rooted['code']} end"
            " inside something the code brings in: the stiletto the thief carries, the"
            " label on the magic boat, the broken canary in the broken egg, the Don Woods"
            " stamp in the brochure."
        ),
        "",
        para(
            f"The other {tally['code'][1]} points are in objects `dung.355` declares and"
            " never places: the huge diamond, which does not exist until the machine"
            " makes it, and the brass bauble the songbird drops. Those are found by"
            " scanning the rest of the MDL for the lookup forms the code reaches an"
            ' object by — `<SFIND-OBJ "DIAMO">` — so the claim is exactly that the code'
            " names the object, not that the cited line is what puts it in play. In MDL"
            " the placement is usually several forms away from the lookup, and this"
            " generator reads structure, not semantics. `--audit` prints every citation"
            " with its file and line."
        ),
        "",
        para(
            "The weaker reading still settles the question worth asking, because an"
            " object no line of code names can never enter play at all. **On that test no"
            " valued object in mainframe Zork is unreachable** — which is the figure a"
            " scoring target has to rest on."
        ),
        "",
    ]
    if unplaced := tally["nowhere"][0]:
        lines += ["What is in that last row:", ""]
        for eid in unplaced:
            note = UNPLACED_NOTES.get(eid, "not looked into yet.")
            lines += [para(f"- `{eid}` — {note}", indent="  "), ""]

    in_swift = sum(1 for r in rooms if norm(r.name) in swift)
    loose_rooms = len(rooms) - len(matching.rooms)
    loose_objs = len(objects) - len(matching.objects)

    lines += [
        "## Coverage",
        "",
        "Every row counts **mainframe entities**. The two matched rows and the",
        "unmatched row account for the total; the last row measures something else and",
        "is not part of that sum.",
        "",
        "| | Rooms | Objects |",
        "|---|---:|---:|",
        f"| Total in the 1981 MDL | {len(rooms)} | {len(objects)} |",
        f"| Matched to a trilogy entity by display name "
        f"| {len(matching.rooms_by_name)} | {len(matching.objects_by_name)} |",
        f"| Matched by position — exit graph, or what it starts inside "
        f"| {len(matching.rooms_by_graph)} | {len(matching.objects_by_graph)} |",
        f"| **Matched, either way** | **{len(matching.rooms)}** "
        f"| **{len(matching.objects)}** |",
        f"| No trilogy counterpart found | {loose_rooms} | {loose_objs} |",
        f"| Already built in `Sources/Zork1/` | {in_swift} | — |",
        "",
        "**Position matching is what closes the mazes.** Fifteen mainframe passages are",
        "called *Maze* and five more *Dead End*, and the trilogy does the same, so the",
        "name identifies no single room and any pairing built on it would be arbitrary.",
        "But both sources carry complete exit tables, and a room can be identified by",
        "where it sits in the graph instead.",
        "",
        "It starts from the rooms the name does settle — Grating Room is the one that",
        "opens the maze — and each pairing proposes the pairings one move away from it,",
        "in the same direction. A proposal is taken only when exactly one candidate",
        "answers each way, and then only if the finished match corroborates it across at",
        "least two edges. That last rule is what keeps the figures honest: a single",
        "agreeing exit says two rooms are near the same third room, and every pairing",
        "reached on one edge alone turned out to be off by exactly one room. The",
        "mainframe maze and Zork I's, checked this way, correspond room for room.",
        "",
        "Objects go the same way once the rooms are known: two hooks, two metal lids and",
        "two walls with etchings stop being ambiguous when the room holding each one is.",
        "A container settles what is inside it for the same reason a room does, so the",
        "step repeats one level in — that is how the water is known to be Zork I's, from",
        "the bottle holding it, when the name alone is shared across the trilogy. That",
        "pass is also a check on the name matcher, since it reaches pairs the name had",
        f"already settled by an independent route: {len(matching.confirmed)} of them, of"
        f" which {len(matching.contradicted)} disagree.",
        "",
        "What is still unmatched is mostly content the trilogy never carried over — the",
        "Bank of Zork, the Royal Puzzle, the Endgame. The rest is rooms the trilogy",
        "renamed, which the name cannot catch and the graph reaches only where enough of",
        "the map around them survived. So these are still floors, but much higher ones.",
        "",
        "## Open questions",
        "",
        "1. **Objects declared `<GOBJECT …>` are not inventoried.** A mainframe global is",
        "   one object a bitmask makes present in many rooms at once, and it is declared",
        "   by a different form, which the reader skips. So the dungeon master, `MASTE`,",
        "   is missing from the Objects table even though `BDOOR` lists him in its",
        "   contents — the one contents entry naming no object this document knows,",
        "   which `--audit` reports. Inventorying the globals would move every figure",
        "   here and is its own piece of work.",
        "",
        "2. **`DEAD1` and `DEAD2` are named with their own description.** A mainframe",
        "   room is declared long description first, short name second: the maze rooms",
        "   give `,MAZEDESC ,SMAZEDESC`, in that order. These two give",
        "   `,DEADEND ,SDEADEND`, the other way round, so the atlas prints *\"You have",
        "   come to a dead end in the maze.\"* in the name column. The reading is faithful",
        "   to `dung.355`; the source is what is inconsistent. It is also why these two",
        "   are the only dead ends no display name could have paired, and the exit graph",
        "   could.",
        "",
    ]
    (DOCS / "dungeon-atlas.md").write_text(
        "\n".join(lines) + "\n", encoding="utf-8"
    )

    # ============================================== prose comparison ========
    # A room's own text is its LDESC; an object leads with the line it is first
    # seen by. Each falls back to the other where the trilogy declared only one.
    by_bucket: dict[str, list[Comparison]] = defaultdict(list)
    for kind, entities, zil_text in (
        ("room", rooms, lambda z: z.ldesc or z.fdesc),
        ("object", objects, lambda z: z.fdesc or z.ldesc),
    ):
        for e in entities:
            z = zil_for(e.id, kind.upper())
            theirs = zil_text(z) if z else ""
            if not (z and e.description and theirs):
                continue
            by_bucket[bucket(e.description, theirs)].append(
                Comparison(kind, e.id, e.name, e.description, theirs, z.game)
            )

    ident = by_bucket["identical"]
    minor = by_bucket["minor"]
    sub = by_bucket["substantial"]

    plines = [
        "# Dungeon — MDL vs ZIL prose comparison",
        "",
        "Every room and object the 1981-07-22 mainframe MDL and one of Zork I/II/III",
        "both have, with the two descriptions side by side. This document exists to",
        "settle one decision: **when the mainframe text and the trilogy text differ,",
        "which one does `Sources/Dungeon/` use?**",
        "",
        header,
        "## How to read this",
        "",
        f"- **Identical ({len(ident)})** — the trilogy carried the mainframe line",
        "  across unchanged. Listed as ids only; there is nothing to decide.",
        f"- **Minor ({len(minor)})** — same sentence, changed punctuation or a",
        "  reworded clause (≥85% similar). Skim.",
        f"- **Substantial ({len(sub)})** — genuinely different writing, or text",
        "  the trilogy rewrote because the puzzle around it changed. **This is the section",
        "  that decides the policy.**",
        "",
        "Comparison is on normalised whitespace and case. Only entities present in *both*",
        "sources appear here; mainframe-only content has nothing to compare against and is",
        "listed in `dungeon-atlas.md`. Which entities those are — how the two sources get",
        "paired up, by display name and, where the name says nothing, by position in the",
        "map — is also settled there, under Coverage.",
        "",
    ]

    plines += [f"## Substantial differences ({len(sub)})", ""]
    for e in sorted(sub, key=lambda e: (e.kind, e.id)):
        plines += [
            f"### `{e.id}` — {e.name} ({e.kind})",
            "",
            "**Mainframe (MDL 1981-07-22):**",
            "",
            "> " + md_escape(e.mainframe),
            "",
            f"**{e.game} (ZIL):**",
            "",
            "> " + md_escape(e.trilogy),
            "",
        ]

    plines += [
        f"## Minor differences ({len(minor)})",
        "",
        "| id | name | mainframe | trilogy |",
        "|---|---|---|---|",
    ]
    for e in sorted(minor, key=lambda e: (e.kind, e.id)):
        plines.append(
            f"| `{e.id}` | {md_escape(e.name)} | {truncate(e.mainframe)} "
            f"| {truncate(e.trilogy)} ({e.game}) |"
        )

    plines += [
        "",
        f"## Identical ({len(ident)})",
        "",
        "The trilogy kept these lines verbatim, so either source yields the same game.",
        "",
        "> " + ", ".join(f"`{e.id}`" for e in sorted(ident, key=lambda e: e.id)),
        "",
        "## The adopted policy — Infocom voice, mainframe world",
        "",
        "**Settled: the trilogy's voice, the mainframe's map and puzzles.** The MDL prose",
        "is terse where the trilogy's is characterful, and the characterful version is the",
        "one worth playing. But the world underneath is the mainframe's throughout.",
        "",
        "This is a real tension, and the `substantial` bucket above is exactly where it",
        "bites. Those differences are mostly not stylistic — they are places where the",
        "trilogy changed the *game* and the prose followed:",
        "",
        "- **The trilogy re-cut the map.** `PASS4` (Winding Passage) and `NHOUS` (North of",
        "  House) differ because the rooms' exits differ. Mainframe descriptions routinely",
        "  enumerate their exits in prose, so a trilogy line can name exits this game does",
        "  not have.",
        "- **The trilogy re-cut the puzzles.** `ALITR` (Pool Room) describes a different",
        "  substance leaking from the ceiling in each version, because what the leak *is*",
        "  changed between them.",
        "",
        "So the policy cannot be \"copy the trilogy line\". It is:",
        "",
        "1. **`identical` and `minor` — take the trilogy line.** Same sentence, better",
        "   typography (the MDL doubles spaces after full stops). Verbatim reproduction,",
        "   MIT-licensed, exactly as `Sources/Zork1/` already does.",
        "2. **`substantial` — take the trilogy line only after checking it against this",
        "   room's exit table in `dungeon-atlas.md`.** Where it contradicts the mainframe",
        "   map or a mainframe puzzle, adapt it: keep the voice, fix the facts.",
        "3. **Mainframe-only content — write it fresh in the Infocom register.** The Bank",
        "   of Zork, the Royal Puzzle, the Endgame and the rest have trilogy counterparts",
        "   to learn the voice from; where they have none, the prose is this project's own.",
        "",
        "### Two consequences worth stating plainly",
        "",
        "**`Sources/Dungeon/` is an adaptation, not a reproduction.** That is the sharpest",
        "difference from `Sources/Zork1/`, which reproduces its source verbatim and says so",
        "in `THIRD_PARTY_NOTICES`. Dungeon reproduces the trilogy where the trilogy fits,",
        "and is originally written everywhere else. `FIDELITY.md` should carry that",
        "distinction at the top of the Dungeon section, because a later contributor will",
        "otherwise assume the Zork1 rule applies.",
        "",
        "**It closes the 1981 provenance gap.** `THIRD_PARTY_NOTICES` records that the",
        "1981-07-22 MDL reached the public without a clear licence grant, unlike the 1977",
        "and 1978 versions. Under this policy nothing reproduces 1981 MDL *text* at all —",
        "the 1981 source is consulted for map, values and puzzle logic, and the words are",
        "either the MIT-licensed trilogy's or this project's own. The gap stops mattering.",
        "",
    ]
    (DOCS / "dungeon-prose-comparison.md").write_text(
        "\n".join(plines) + "\n", encoding="utf-8"
    )

    print(f"rooms={len(rooms)} objects={len(objects)}")
    print(f"SCORE-MAX={score_max}  EG-SCORE-MAX={eg_max}")
    print(f"matched rooms={len(matching.rooms)} objects={len(matching.objects)}"
          f"  (by name {len(matching.rooms_by_name)}/{len(matching.objects_by_name)},"
          f" by position {len(matching.rooms_by_graph)}/{len(matching.objects_by_graph)})")
    print("placement: " + "  ".join(
        f"{kind}={len(group)}/{pts}pts" for kind, (group, pts) in tally.items()
    ))
    print(f"prose comparison: identical={len(ident)} minor={len(minor)} "
          f"substantial={len(sub)}")
    print(f"wrote {DOCS/'dungeon-atlas.md'}")
    print(f"wrote {DOCS/'dungeon-prose-comparison.md'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
