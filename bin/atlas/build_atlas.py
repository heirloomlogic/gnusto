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
which is gitignored. The MDL is github.com/heasm66/mdlzork and the trilogy is
github.com/historicalsource's zork1, zork2 and zork3, checked out under those
names — `Sources.complaint` prints the layout in full when one is missing.
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

from mdl_reader import Exit, MdlRoom, ZilEntity, parse_mdl_dungeon, parse_zil

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs" / "games"
DEFAULT_SOURCES = ROOT / ".context" / "reference"

MDL_SUBPATH = Path("mdlzork/mdlzork_810722/original_source/dung.355")

# Each game's checkout, and the master file naming what that game is built from.
# The master matters: a checkout can hold more than one generation of the source,
# and only the master says which one shipped. See `Sources.zil_files`.
#
# One table rather than two keyed the same way, so a game cannot be added to the
# directories and forgotten in the masters.
ZIL_SOURCES = {
    "Zork I": (Path("historicalsource-zork1"), "zork1.zil"),
    "Zork II": (Path("historicalsource-zork2"), "zork2.zil"),
    "Zork III": (Path("historicalsource-zork3"), "zork3.zil"),
}

# How a master file names one of its own parts: `<INSERT-FILE "3DUNGEON" T>`.
# The name is the file's stem, upper-cased and without its extension.
_INSERT_FILE = re.compile(r'<INSERT-FILE\s+"([^"]+)"')

# Where a trilogy room can be paired in more than one game — which only graph
# matching can produce, since a name shared by two games is ambiguous by
# construction — the earliest game wins. Zork I first: it is the game
# `Sources/Zork1/` is built from, so its row is the one a reader can check.
GAME_ORDER = list(ZIL_SOURCES)

# Areas the mainframe map divides into, in the order the atlas lists them.
# Used only to group it readably; not a claim about the original's own
# structure, which has no region concept.
#
# `RENDGAME` is tested first and outranks every prefix here, because it is the
# source's own declaration where a prefix is only a naming convention read off
# the ids. So a prefix claims exactly the rooms the flag left, and `regions`
# refuses an entry that claims nothing.
MAIN_REGION = "Main dungeon"
REGION_PREFIXES = [
    ("Bank of Zork", "BK"),
    ("Royal Puzzle", "CP"),
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
        return self.root / ZIL_SOURCES[game][0]

    def master(self, game: str) -> Path:
        return self.zil(game) / ZIL_SOURCES[game][1]

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
        absent: list[Path] = []
        for game in GAME_ORDER:
            if not self.zil(game).is_dir():
                absent.append(self.zil(game))
            elif not self.master(game).is_file():
                absent.append(self.master(game))
            else:
                # The master is the only thing that knows the rest of the list,
                # so a part it names and the checkout lacks is missing source in
                # exactly the sense this method reports — same fault, same
                # remedy, one channel.
                absent += self._resolve(game)[1]
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
            "The first is github.com/heasm66/mdlzork; the rest are\n"
            "github.com/historicalsource's zork1/zork2/zork3. Point --sources or\n"
            "GNUSTO_ZORK_SOURCES at them. They are not vendored — see this file's\n"
            "docstring and THIRD_PARTY_NOTICES for why."
        )

    def zil_files(self, game: str) -> list[Path]:
        """The files a game is built from, in the order its own master names them.

        Reading the directory instead — every `*.zil` in it — is wrong, and wrong
        in a way that hides. The `zork3` checkout carries two complete generations
        of the game: the one `zork3.zil` names, and an older `dungeon.zil` /
        `shadow.zil` / `tm.zil` set no master mentions. Globbing loads both, so
        every Zork III room and object is declared twice under the same `DESC`,
        `pair_by_name` throws out all of them as ambiguous, and the game pairs
        with nothing at all — see the guard in `unpaired_games`.

        So the master is the authority, exactly as the source is everywhere else
        in this generator. `<INSERT-FILE "3DUNGEON" T>` names `3dungeon.zil`; the
        case is the master's convention, not the filesystem's, so it is matched
        case-insensitively.
        """
        files, unresolved = self._resolve(game)
        if unresolved:
            # `missing` reports these first and `main` stops there, so this is a
            # backstop for a caller that skipped the precondition rather than a
            # path a run takes. It raises rather than returning short because a
            # short read is the whole failure this function exists to prevent.
            raise SystemExit(
                f"{self.master(game)} names files the checkout lacks: "
                f"{', '.join(str(p) for p in unresolved)}"
            )
        return files

    def _resolve(self, game: str) -> tuple[list[Path], list[Path]]:
        """Split what the master names into what is there and what is not."""
        tree = self.zil(game)
        on_disk = {f.name.lower(): f for f in tree.glob("*.zil")}
        files: list[Path] = []
        unresolved: list[Path] = []
        for name in _INSERT_FILE.findall(read(self.master(game))):
            stem = f"{name.lower()}.zil"
            if found := on_disk.get(stem):
                files.append(found)
            else:
                unresolved.append(tree / stem)
        return files, unresolved

    def load_zil(self) -> list[ZilEntity]:
        return [
            entity
            for game in GAME_ORDER
            for f in self.zil_files(game)
            for entity in parse_zil(read(f), game)
        ]


# ----------------------------------------------------------------- placement

# How MDL code reaches an object it did not declare in place: by id string.
# `<SFIND-OBJ "DIAMO">` is the machine conjuring the diamond. Matching the form
# rather than the bare id keeps `EGG` out of `EGG-SOLVE`. The id can be any
# string `GET-OBJ` interns, punctuation included — `<SFIND-OBJ "#####">` is five
# files' way of reaching the player's own body.
_OBJECT_LOOKUP = re.compile(r'\b(?:S?FIND-OBJ|GET-OBJ)\s+"([^"]+)"')

# Why a particular object is one nothing places. That is a fact about the source
# rather than about its structure, so it is read by hand, once, and recorded here;
# an object that turns up in that row without a note is one nobody has looked at.
UNPLACED_NOTES = {
    "BUTTO": "a placeholder with no name, no description and no value. The comment "
    "above it in `dung.355` says it is kept only so that restoring a save file "
    "written by an older build still works.",
    "!!!!!": "the same shape as `BUTTO` — no name, no description, no flag word, no "
    "value — and declared immediately after it, under the same comment. Nothing "
    "else in the source names it.",
}

PLACEMENT_LABELS = {
    "room": "In a room",
    "object": "Inside another object",
    "global": "In every room whose `RGLOBAL` mask carries its bit",
    "code": "Named only by the game code",
    "nowhere": "Named nowhere but its own declaration",
}


@dataclass(frozen=True)
class Placement:
    """Where one object starts, and what says so."""

    kind: str  # a key of PLACEMENT_LABELS
    where: str = ""  # the room, the containing object, or the `RGLOBAL` bit
    cites: tuple[str, ...] = ()  # file:line, for kind 'code'

    def cell(self) -> str:
        """How the atlas's `starts in` column says it, in one table cell."""
        if self.kind == "room":
            return f"`{self.where}`"
        if self.kind == "object":
            return f"in `{self.where}`"
        if self.kind == "global":
            return f"by `{self.where}`" if self.where else "every room"
        return "by code" if self.kind == "code" else "—"

    def detail(self, oid: str, placed: dict[str, Placement]) -> str:
        """The whole claim, for `--audit` to print.

        A nested object is only as reachable as what finally holds it, so its
        claim is the chain rather than the container next to it.
        """
        if self.kind == "object":
            return " in ".join(chain(oid, placed))
        if self.kind == "global":
            return self.where or "(star bits — every room)"
        return self.where or ", ".join(self.cites) or "—"


def object_placements(
    rooms: list, objects: list, code: list[Path]
) -> tuple[dict[str, Placement], dict[str, str]]:
    """Say where every object starts, and on what evidence.

    Five answers, because fewer do not fit the source. A room's contents list
    places most objects. An object's contents list places the rest of the ones
    the file places at all — the egg in the nest, the canary in the egg — and
    reading only rooms is what made those look unplaced. A global starts in no
    one place at all: a bit in its declaration and a mask on the room put it in
    every room that asks for it. What none of those mentions is either something
    the running game knows about, or nothing at all.

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
    for obj in objects:
        # A contents list is the more specific claim, so the mask only answers
        # for a global no list mentions. The dungeon master is both: `BDOOR`
        # lists him, and `FDOOR`'s mask shows him from next door.
        if obj.is_global:
            holders.setdefault(obj.id, Placement("global", obj.bit))

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


# --------------------------------------------------------------------- globals


@dataclass(frozen=True)
class Globals:
    """Which rooms each `<GOBJECT …>` object is present in.

    One reading of the shared scenery, for the document and for `--audit`, the
    same reason `Exits` and `placement_tally` exist: two views of one walk, and
    computing them separately is how they drift apart.

    A mainframe global is one object many rooms share, and the sharing is a
    bitmask and nothing more: `makstr.44:270` gives the object a bit, a room
    carries `(RGLOBAL <sum of bits>)`, and `defs.171:38` tests one against the
    other. Several objects can hold the same bit — the Royal Puzzle's four walls
    do — so the bit, not the object, is what a room names.

    `stars` are the globals declared `<GOBJECT <> …>`. `makstr.44:279` allocates
    them a bit and adds it to `STAR-BITS`, which `defs.171:88` makes the default
    value of the slot, so they are in every room whether it declares a mask or
    not. They are held apart rather than given a room list of all 196.
    """

    by_bit: dict[str, list[str]]  # named bit -> the object ids sharing it
    rooms: dict[str, list[str]]  # named bit -> the rooms whose mask carries it
    stars: list[str]  # object ids present in every room
    total_rooms: int
    masked_rooms: int  # rooms that declare an `RGLOBAL` of their own

    @property
    def named(self) -> int:
        """Globals reached by a named bit rather than by the star bits."""
        return sum(len(g) for g in self.by_bit.values())

    @property
    def total(self) -> int:
        return self.named + len(self.stars)


def global_presence(rooms: list, objects: list) -> Globals:
    """Read the globals and the room masks into one index.

    A mask naming a bit nothing declares is a hard stop, the same rule
    `exit_tally` applies to an unclassified edge: the Globals section would
    otherwise publish a room list quietly short of the rooms whose bit went
    unread, in a committed document.
    """
    by_bit: dict[str, list[str]] = defaultdict(list)
    stars: list[str] = []
    for o in sorted(objects, key=lambda x: x.id):
        if not o.is_global:
            continue
        (by_bit[o.bit] if o.bit else stars).append(o.id)

    where: dict[str, list[str]] = defaultdict(list)
    for r in sorted(rooms, key=lambda x: x.id):
        for bit in r.globals:
            where[bit].append(r.id)
    if stray := sorted(set(where) - set(by_bit)):
        raise SystemExit(
            f"`RGLOBAL` bits no <GOBJECT …> declares: {', '.join(stray)}\n"
            "Every bit a room's mask names has to come from a global's "
            "declaration. Publishing the mask without it would understate where "
            "the globals carrying that bit are present."
        )
    return Globals(
        dict(by_bit),
        {b: where[b] for b in by_bit},
        stars,
        len(rooms),
        sum(1 for r in rooms if r.globals),
    )


# ------------------------------------------------------------- cross-matching

def _is_room(dest: str, known: dict) -> bool:
    """Does this edge land somewhere the map declares?

    An exit that names no destination — a blocked one, or a form neither reader
    could classify — carries `""`, which no map declares, so the one lookup
    answers both questions.
    """
    return dest in known


def _adjacency(
    nodes: dict,
) -> tuple[dict[str, dict[str, str]], dict[str, dict[str, list[str]]]]:
    """Index a map's edges by direction, forwards and backwards.

    The reverse index matters as much as the forward one: a maze passage is
    often reached from an already-identified room before it leads to one.

    A gated edge still counts, because it still says where the passage goes: the
    ZIL reader has always taken the destination out of `(NORTH TO CELLAR IF …)`,
    and now the MDL reader resolves `<CEXIT …>` and `<DOOR …>` to the same thing.
    Reading one side's conditional exits and not the other's was undercounting
    corroboration for exactly the rooms that have them.
    """
    out: dict[str, dict[str, str]] = defaultdict(dict)
    into: dict[str, dict[str, list[str]]] = defaultdict(lambda: defaultdict(list))
    for nid, node in nodes.items():
        for e in node.exits:
            if not _is_room(e.dest, nodes) or e.direction in out[nid]:
                continue
            out[nid][e.direction] = e.dest
            into[e.dest][e.direction].append(nid)
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
    m_out, m_in = _adjacency(mdl_rooms)
    z_out, z_in = _adjacency(zil_rooms)
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


def unpaired_games(matching: Matching) -> list[str]:
    """Games the generator loaded and then matched against nothing whatsoever.

    A source that contributes not one pair is never a fact about the trilogy; it
    is a fact about this program. Zork III read as *"no counterpart exists"* for
    196 rooms and 253 objects for as long as nobody grepped for it (#184), and
    that answer reached `FIDELITY.md` as though it had been established. A
    document that says nothing would have been read as broken; a document that
    quietly said the wrong thing was not.

    So a zero here is fatal, on the same reasoning as `Sources.missing` — a
    degraded run is worse than none. It is a floor, not a proof: a game can pair
    badly and still pass this. It only catches the failure that is total, which
    is the failure that hides.
    """
    paired = {z.game for z in (*matching.rooms.values(), *matching.objects.values())}
    return [game for game in GAME_ORDER if game not in paired]


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
    """Which shelf a room is listed under. The flag beats the prefix."""
    if "RENDGAME" in room.flags:
        return ENDGAME_REGION
    for label, prefix in REGION_PREFIXES:
        if room.id.startswith(prefix):
            return label
    return MAIN_REGION


def prefix_claim(label: str, prefix: str, rooms: list[MdlRoom]) -> tuple[list[str], list[str]]:
    """Room ids this prefix matches, and the subset an earlier rule claimed first.

    Both, because either alone reads as an assertion: the shadowed list says
    what a prefix lost, and it only means anything against what it matched.
    """
    matched = sorted((r for r in rooms if r.id.startswith(prefix)), key=lambda r: r.id)
    return [r.id for r in matched], [r.id for r in matched if region_of(r) != label]


def regions(rooms: list[MdlRoom]) -> dict[str, list[MdlRoom]]:
    """Rooms grouped by region, in id order — one grouping, read by the Rooms
    tables, the Exits tables under them, and `--audit`.

    A prefix that claims no room is a hard stop, for the reason `EXIT_KINDS` is
    one: `REGION_PREFIXES` reads as a statement about the map, so an entry that
    can never fire is a heading the document silently does not have. #164 was
    exactly that — a *Mirror box / Royal Puzzle* entry on the `MR` prefix,
    tested after `RENDGAME`, which all seventeen `MR…` rooms carry. It looked
    like configuration and was decoration.
    """
    by_region: dict[str, list[MdlRoom]] = defaultdict(list)
    for r in sorted(rooms, key=lambda x: x.id):
        by_region[region_of(r)].append(r)

    dead = []
    for label, prefix in REGION_PREFIXES:
        if by_region.get(label):
            continue
        _, taken = prefix_claim(label, prefix, rooms)
        why = (f"{len(taken)} room(s) an earlier rule claimed first ({', '.join(taken)})"
               if taken else "no room id at all")
        dead.append(f"region `{label}` claims no room: prefix `{prefix}` matches {why}")
    if dead:
        raise SystemExit(
            "\n".join(dead)
            + "\nDrop the entry or key it on a prefix the earlier rules leave "
            "alone. Publishing it would put a heading in REGION_ORDER that no "
            "room can ever be listed under."
        )
    return dict(by_region)


# ---------------------------------------------------------------------- exits

# How each kind reads in `dung.355` — the forms `mdl_reader._exit` classifies —
# and what it means. `exit_tally` refuses to publish a kind this table has no row
# for, so the four counts always sum to the total the section claims.
EXIT_KINDS = {
    "plain": ('`"NORTH" "NHOUS"`', "always open"),
    "conditional": ("`<CEXIT flag dest …>`", "open while the named flag is set"),
    "door": ("`<DOOR obj here there …>`", "through the named object, while it is open"),
    "blocked": ('`#NEXIT "…"`', "never open; the source's refusal text is not reproduced"),
}


def one_way(e: Exit, home: str, rooms: dict) -> bool:
    """Does the destination declare no way back to `home`?

    Any returning edge counts, not only the reverse bearing. The mainframe maze
    is full of passages that come back by some other direction than the one you
    left by, so "is there a way back at all" is the question a map is actually
    read for — and it is a fact about the graph rather than about the
    declaration, which is why it is derived here and not stored on `Exit`.

    The answer is only as good as the destination's own table: an unresolved edge
    out of `there` cannot match `home` and so reads as no way back. `--audit`
    reports every unresolved destination for that reason.
    """
    there = rooms.get(e.dest)
    return there is not None and all(back.dest != home for back in there.exits)


@dataclass(frozen=True)
class Exits:
    """One reading of the map's edges, for the document and for `--audit`.

    The same reason `placement_tally` exists: the published section and the
    listing `--audit` prints are two views of one walk, and computing them
    separately is how they drift apart.
    """

    rooms: dict  # room id -> MdlRoom
    kinds: Counter
    one_ways: int

    @property
    def total(self) -> int:
        return sum(self.kinds.values())

    def cells(self, e: Exit, home: str) -> tuple[str, str]:
        """The destination and kind cells for one edge, in markdown."""
        dest = "—" if not e.dest else f"`{e.dest}`"
        if e.dest and not _is_room(e.dest, self.rooms):
            dest += " *(no such room)*"
        kind = f"{e.kind} (`{e.via}`)" if e.via else e.kind
        return dest, f"{kind}, one-way" if one_way(e, home, self.rooms) else kind

    def detail(self, e: Exit, home: str) -> str:
        """The same claim as plain text, for `--audit`."""
        parts = [e.kind]
        if e.via:
            parts.append(f"via {e.via}")
        if one_way(e, home, self.rooms):
            parts.append("one-way")
        if e.dest and not _is_room(e.dest, self.rooms):
            parts.append("NO SUCH ROOM")
        return ", ".join(parts)

    def unresolved(self, ordered: list) -> list[tuple[str, Exit]]:
        """Every edge that should name a room and does not."""
        return [
            (r.id, e)
            for r in ordered
            for e in r.exits
            if e.kind != "blocked" and not _is_room(e.dest, self.rooms)
        ]


def exit_tally(rooms: list) -> Exits:
    """Read every edge once.

    A kind `EXIT_KINDS` has no row for is a hard stop rather than a missing row:
    an unclassified edge would otherwise be published as `plain` — "always open"
    — which is the most permissive claim the vocabulary can make about a form
    nobody understood, and the counts would quietly stop summing to the total.
    """
    known = {r.id: r for r in rooms}
    kinds = Counter(e.kind for r in rooms for e in r.exits)
    if stray := sorted(set(kinds) - set(EXIT_KINDS)):
        raise SystemExit(
            f"exit kinds with no row in EXIT_KINDS: {', '.join(stray)}\n"
            "Classify them in mdl_reader._exit, or give them a row. Publishing "
            "an edge nobody classified would assert it is always open."
        )
    loops = sum(1 for r in rooms for e in r.exits if one_way(e, r.id, known))
    return Exits(known, kinds, loops)


def md_escape(text: str) -> str:
    return (text or "").replace("|", "\\|").replace("\n", " ").strip()


def prose_list(items) -> str:
    """`a`, `a and b`, `a, b and c` — for a sentence naming a config list.

    A sentence that types out what a table already holds is the same defect as
    a table entry no rule reaches: it reads as a claim and drifts out of step
    silently. Cheaper to derive it.
    """
    names = list(items)
    return " and ".join(filter(None, [", ".join(names[:-1]), *names[-1:]]))


def para(text: str, indent: str = "") -> str:
    """Wrap a paragraph to the width the hand-written prose here is written at.

    Only for the paragraphs that interpolate a figure: a number that grows a
    digit would otherwise push a hand-wrapped line over on its own.

    Hyphens are not break points here. Almost every hyphen in this document is
    inside an identifier — `LOCAL-GLOBALS`, `EG-SCORE-MAX`, `WALL-ESWBIT` — and
    breaking one splits the code span across two lines, where markdown renders it
    with a space in the middle and the identifier stops being greppable.
    """
    return textwrap.fill(text, 79, subsequent_indent=indent, break_on_hyphens=False)


def truncate(text: str, n: int = 90) -> str:
    text = md_escape(text)
    return text if len(text) <= n else text[: n - 1] + "…"


@dataclass(frozen=True)
class SharedScenery:
    """Each matched global set against how the trilogy states the same thing.

    Both maps have the mechanism and state it from opposite ends. MDL gives the
    object a bit and the room a mask; ZIL puts the object on one of two shelves —
    `GLOBAL-OBJECTS` for everywhere, `LOCAL-GLOBALS` for somewhere — and names
    the local ones in each room's `(GLOBAL …)` list. So a mainframe star global
    should answer a trilogy `GLOBAL-OBJECTS` one, and a bit global a
    `LOCAL-GLOBALS` one.

    Two readings, computed together because they are one walk: the *shelf*, over
    every matched global, and the *room*, over every place a matched global sits
    in a room that is itself matched. The second is the thinner list and the
    better check — it reaches presences the first knows nothing about, by an
    independent route, exactly as the containment pass checks the name matcher.
    """

    shelves: list[tuple[str, ZilEntity, str, bool]]  # global, pair, reading, agrees
    places: list[tuple[str, str, ZilEntity, bool]]  # room, global, pair, agrees

    @staticmethod
    def _tally(rows) -> Counter:
        return Counter("agree" if r[-1] else "differ" for r in rows)

    @property
    def by_shelf(self) -> Counter:
        return self._tally(self.shelves)

    @property
    def by_room(self) -> Counter:
        return self._tally(self.places)


def shared_scenery(
    rooms: list, m: Matching, shared: Globals, zil: list[ZilEntity]
) -> SharedScenery:
    """Read both comparisons in one pass. See `SharedScenery`."""
    shelf_of = {"GLOBAL-OBJECTS": "everywhere", "LOCAL-GLOBALS": "per-room"}
    everywhere = set(shared.stars)

    shelves = []
    for oid in sorted(shared.stars + [o for g in shared.by_bit.values() for o in g]):
        if not (z := m.objects.get(oid)):
            continue
        mine = "everywhere" if oid in everywhere else "per-room"
        theirs = shelf_of.get(z.location, "an ordinary object")
        shelves.append((oid, z, f"{mine} here, {theirs} there", mine == theirs))

    zil_rooms = {z.id: z for z in zil if z.kind == "ROOM"}
    places = []
    for r in sorted(rooms, key=lambda x: x.id):
        if not (zr := m.rooms.get(r.id)):
            continue
        listed = zil_rooms[zr.id].globals
        # Only the globals a bit puts here. A star global is in this room by
        # definition and in every other one too, so asking whether the trilogy
        # also has it here answers nothing the shelf reading has not.
        for oid in sorted(o for b in r.globals for o in shared.by_bit[b]):
            z = m.objects.get(oid)
            # Only a pair in the same game can be asked the question at all: a
            # Zork II object is not absent from a Zork I room, it is elsewhere.
            if not z or z.game != zr.game:
                continue
            here = z.id in listed or z.location == "GLOBAL-OBJECTS"
            places.append((r.id, oid, z, here))
    return SharedScenery(shelves, places)


def audit(
    rooms: list,
    objects: list,
    m: Matching,
    placed: dict[str, Placement],
    unresolved: dict[str, str],
    exits: Exits,
    shared: Globals,
    scenery: SharedScenery,
    by_region: dict[str, list],
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

    # Which shelf every room is listed under, and — for a prefix — how many of
    # the ids it matches an earlier rule claimed first. A prefix whose whole
    # match is shadowed is a region that can never be published; `regions`
    # refuses to get this far with one.
    rules = {MAIN_REGION: "everything no other rule claims",
             ENDGAME_REGION: "flag `RENDGAME`, tested first"}
    for label, prefix in REGION_PREFIXES:
        matched, taken = prefix_claim(label, prefix, rooms)
        tail = f": {', '.join(taken)}" if taken else ""
        rules[label] = (f"id prefix `{prefix}`; {len(taken)} of the {len(matched)} "
                        f"ids it matches claimed first{tail}")
    print(f"\n=== REGIONS ({len(rooms)} rooms over {len(REGION_ORDER)} shelves) ===")
    for label in REGION_ORDER:
        group = by_region.get(label, [])
        print(f"\n--- {label} ({len(group)} rooms) — {rules[label]} ---")
        for r in group:
            print(f"  {r.id:8s} {r.name[:60]}")

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

    by_id = sorted(rooms, key=lambda r: r.id)
    print(f"\n=== EXITS ({exits.total} over {len(rooms)} rooms: "
          + ", ".join(f"{k}={v}" for k, v in sorted(exits.kinds.items()))
          + f", one-way={exits.one_ways}) ===")
    for r in by_id:
        for e in r.exits:
            print(f"  {r.id:8s} {e.direction:8s} -> {e.dest or '—':24s} "
                  f"{exits.detail(e, r.id)}")

    # A destination this document cannot resolve is the one way an exit table can
    # be quietly wrong, so it is reported rather than left to be noticed. The
    # rooms declared `<GOBJECT …>` are the expected source of these — the same
    # gap the Objects table has.
    stranded = exits.unresolved(by_id)
    print(f"\n=== exits naming no declared room ({len(stranded)}) ===")
    for rid, e in stranded:
        print(f"  {rid:8s} {e.direction:8s} -> {e.dest or '(none)':24s} {e.kind}")

    print(f"\n=== GLOBALS present in every room ({len(shared.stars)}) ===")
    for oid in shared.stars:
        print(f"  {oid:8s} {objs[oid].name}")
    print(f"\n=== GLOBALS present by a named bit ({shared.named} over "
          f"{len(shared.by_bit)} bits) ===")
    for bit in sorted(shared.by_bit):
        where = shared.rooms[bit]
        print(f"  {bit:14s} {', '.join(shared.by_bit[bit])}")
        print(f"  {'':14s} {len(where)} room(s): {', '.join(where) or '(none)'}")

    shelf = scenery.by_shelf
    print(f"\n=== GLOBALS on the same shelf as the trilogy's "
          f"({len(scenery.shelves)} matched: {shelf['agree']} agree, "
          f"{shelf['differ']} differ) ===")
    for oid, z, reading, agrees in scenery.shelves:
        print(f"  {'ok' if agrees else '!!':3s}{oid:8s} -> {z.id:24s} {z.game:9s}"
              f" {reading}")

    room = scenery.by_room
    print(f"\n=== GLOBALS present in the same room as the trilogy's "
          f"({len(scenery.places)} presences: {room['agree']} agree, "
          f"{room['differ']} differ) ===")
    for rid, oid, z, agrees in scenery.places:
        print(f"  {'ok' if agrees else '!!':3s}{rid:8s} {oid:8s} -> {z.id:24s}"
              f" {z.game}")
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
    exits = exit_tally(rooms)
    shared = global_presence(rooms, objects)
    scenery = shared_scenery(rooms, matching, shared, zil)
    by_region = regions(rooms)

    # Loud, and ahead of the writes. Under --audit the listing still prints
    # first: that is the tool you reach for to find out *why* a game paired with
    # nothing, so refusing to show it would be the wrong kind of strict.
    barren = unpaired_games(matching)
    if args.audit:
        listed = audit(
            rooms, objects, matching, placed, unresolved, exits, shared, scenery, by_region
        )
        if not barren:
            return listed

    if barren:
        print(
            f"\n{', '.join(barren)} loaded but matched nothing — not one room and "
            "not one object.\nThat is a fault in this generator or in the checkout, "
            "never a fact about the\ntrilogy, and writing it into a committed "
            "document says the counterpart does not\nexist. Nothing written. See "
            "`unpaired_games`.",
            file=sys.stderr,
        )
        return 1

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
        para(
            f"`SCORE-MAX` comes to {score_max} — the figure mainframe Zork is usually"
            " quoted at. 25 of those points are the Royal Puzzle's gold card, which"
            ' `dung.355` declares inside `<PUT <OBJECT …> ,OROOM <GET-ROOM "CP">>`'
            " rather than at top level, where a reader looking only at top-level forms"
            " misses it. `makstr.44:315` totals every `<OBJECT …>` call wherever it"
            " sits, so it counts."
        ),
        "",
        f"The choice is between the original's two separate maxima ({score_max} and"
        f" {eg_max},",
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
        f"| — of them global (`GOBJECT`) | {shared.total} |",
        "",
    ]

    # Named from REGION_PREFIXES rather than typed out: a sentence that repeats
    # what the table holds is the same defect as a table entry no rule reaches.
    flagless = prose_list(f"the {label}" for label, _ in REGION_PREFIXES)
    lines += [
        "## Rooms",
        "",
        para(
            "Shelved for reading, not because the source has regions. The endgame is"
            f" the {len(by_region[ENDGAME_REGION])} rooms flagged `RENDGAME` — the"
            " mirror box among them, corridors and all, since it is part of the"
            " endgame and not a shelf of its own. "
            + flagless[0].upper() + flagless[1:]
            + " have no flag, so they are the "
            + prose_list(f"`{prefix}…`" for _, prefix in REGION_PREFIXES)
            + " ids, which name their rooms and nothing else. Everything the source"
            " left unmarked is the main dungeon."
        ),
        "",
    ]
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
        for r in group:
            z = zil_for(r.id, "ROOM")
            here = swift.get(norm(r.name), "")
            lines.append(
                f"| `{r.id}` | {md_escape(r.name)} | {r.value or ''} | {len(r.exits)} "
                f"| {z.game if z else '—'} | {'`' + here + '`' if here else '—'} |"
            )
        lines.append("")

    # ---- the exit tables the `exits` column above is a checksum on ----------
    lines += [
        "## Exits",
        "",
        para(
            f"Every one of the {exits.total} edges `dung.355` declares, in the order"
            " it declares them, so a row can be read straight against the source. The"
            " **exits** column in the Rooms tables above counts the rows here for"
            " that room, and is the checksum on them."
        ),
        "",
        "| kind | in the source | meaning | count |",
        "|---|---|---|---:|",
        *(
            f"| {kind} | {form} | {means} | {exits.kinds[kind]} |"
            for kind, (form, means) in EXIT_KINDS.items()
        ),
        "",
        para(
            "**one-way** is not a fifth kind but an observation about the graph:"
            f" {exits.one_ways} of those edges arrive in a room that declares no edge"
            " back. Any returning edge counts, not only the reverse bearing — the"
            " maze is full of passages that return by some other direction than the"
            " one you left by."
        ),
        "",
        "Where the source names the mechanism, the kind carries it: the door object",
        "for a door, the flag a conditional exit tests. A blocked exit carries",
        "neither a destination nor a message. `#NEXIT`'s second argument is 1981 MDL",
        "prose and `THIRD_PARTY_NOTICES` records that source as the one body that",
        "reached the public without a located licence grant, so this generator steps",
        "over those strings without reading them and records only that the way is",
        "shut.",
        "",
    ]
    for region in REGION_ORDER:
        rows = []
        for r in by_region.get(region, []):
            for e in r.exits:
                dest, kind = exits.cells(e, r.id)
                rows.append(f"| `{r.id}` | {e.direction} | {dest} | {kind} |")
        if not rows:
            continue
        lines += [
            f"### {region} ({len(rows)} exits)",
            "",
            "| room | direction | destination | kind |",
            "|---|---|---|---|",
            *rows,
            "",
        ]

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
        "",
        para(
            "**starts in** is the room or the object it begins inside. A global begins"
            " in no one place, so its cell names the `RGLOBAL` bit that carries it —"
            " or says *every room*, for the ones the mask always has. See Globals"
            f" below for which rooms those are, and Placement for the {elsewhere}"
            " entries that are neither a place nor a bit."
        ),
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
        para(
            f"The {len(tally['global'][0])} globals are the row that is not a place at"
            " all: a bit in the declaration and a mask on the room put one object in"
            f" many rooms at once. They carry {tally['global'][1]} points between"
            " them, so the figures above are unmoved by them — the section they do"
            " move is Coverage. A contents list is the more specific claim and wins"
            " where both apply, which is why the dungeon master counts as starting in"
            " `BDOOR` rather than here."
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

    obj_name = {o.id: o.name for o in objects}
    lines += [
        "## Globals",
        "",
        para(
            "One object many rooms share. `makstr.44:270` declares it"
            " `<GOBJECT bit names adjectives description flags …>` — an ordinary"
            " `<OBJECT …>` with one extra leading argument — and a room carries"
            " `(RGLOBAL <sum of bits>)`. Presence is that and nothing more:"
            " `defs.171:38` is `<ANDB bit <RGLOBAL room>>`. So the wall, the water"
            " and the white house are each declared once and appear wherever their"
            " bit is set."
        ),
        "",
        para(
            "This is the mechanism to reach for in place of a near-duplicate scenery"
            " item per room. Several objects may share one bit — the Royal Puzzle's"
            " four walls do — so what a room names is the bit, not the object."
        ),
        "",
        para(
            f"{len(shared.stars)} of the {shared.total}"
            f" name no bit at all. `makstr.44:279` allocates one anyway and adds it to"
            " `STAR-BITS`, which `defs.171:88` makes the *default* value of every"
            f" room's mask — so those are present in all {shared.total_rooms} rooms"
            " whether the room declares a mask or not. The rest share"
            f" {len(shared.by_bit)} named bits between them, and"
            f" {shared.masked_rooms} rooms declare one."
        ),
        "",
        f"### Present in every room ({len(shared.stars)})",
        "",
        "| id | name |",
        "|---|---|",
        *(f"| `{oid}` | {md_escape(obj_name[oid])} |" for oid in shared.stars),
        "",
        f"### Present by a named bit ({shared.named} over {len(shared.by_bit)} bits)",
        "",
        "| bit | globals | rooms |",
        "|---|---|---|",
        *(
            f"| `{bit}` | "
            + ", ".join(f"`{o}` {md_escape(obj_name[o])}" for o in shared.by_bit[bit])
            + " | "
            + (", ".join(f"`{r}`" for r in shared.rooms[bit]) or "*none*")
            + " |"
            for bit in sorted(shared.by_bit)
        ),
        "",
        para(
            "The trilogy keeps the same mechanism and states it from the other end:"
            " an object goes on the `GLOBAL-OBJECTS` shelf to be everywhere or the"
            " `LOCAL-GLOBALS` shelf to be somewhere, and a ZIL room lists the local"
            f" ones it wants as `(GLOBAL …)`. {len(scenery.shelves)} of the mainframe"
            " globals pair with a trilogy object, and on which shelf they sit the two"
            f" sources agree {scenery.by_shelf['agree']} times and differ"
            f" {scenery.by_shelf['differ']}."
        ),
        "",
        para(
            "Room by room is the thinner list and the better check, because it reaches"
            " presences the shelf reading knows nothing about, by an independent route."
            " Where a mainframe room and a global carried into it are *both* paired,"
            f" the trilogy carries the same global into the same room"
            f" {scenery.by_room['agree']} times out of"
            f" {len(scenery.places)} — the white house seen from all four sides of it"
            " and from the forest, the well from top and bottom, the chute in the"
            f" Slide Room. It contradicts {scenery.by_room['differ']}. `--audit`"
            " prints both listings."
        ),
        "",
    ]

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
        "Bank of Zork above all. It is a shorter list than it looks, and it was longer",
        "still until #184: the Royal Puzzle and the Endgame went into Zork III, and this",
        "generator was loading that game's sources and pairing nothing against them, so",
        "both regions read here as having no counterpart at all. The rest is rooms the",
        "trilogy renamed, which the name cannot catch and the graph reaches only where",
        "enough of the map around them survived. So these are still floors, but much",
        "higher ones.",
        "",
        para(
            f"The object rows include the {shared.total} globals, since a"
            " `<GOBJECT …>` is an `<OBJECT …>` with a bit and the trilogy shelves its"
            " own globals as ordinary objects too. They pair badly on purpose: a"
            " global tends to be called *wall* or *water*, which names several things"
            " in each source, and the container pass cannot reach one because nothing"
            " contains it."
        ),
        "",
        "## Open questions",
        "",
        "1. **`DEAD1` and `DEAD2` are named with their own description.** A mainframe",
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
