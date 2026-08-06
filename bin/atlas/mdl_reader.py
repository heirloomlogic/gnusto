"""Minimal readers for MDL (mainframe Zork) and ZIL (Zork I/II/III) source.

Parses the declaration forms far enough to inventory rooms and objects, and to
recover both maps as directed graphs. Not a general MDL/ZIL interpreter — it
reads structure, not semantics.

Two things bend that rule as far as it bends, and both are dereference rather
than evaluation. A name bound to a literal resolves to the literal, so
`,SMAZEDESC` reads as the text it stands for. And an exit constant resolves to
the binding *in force where the room is declared*, because `dung.355` binds `CD`
to two different doors and uses both. Nothing here tests a flag or runs a
routine: a conditional exit's flag is recorded by name and never consulted.

Used by `build_atlas.py`; see that file for how to run it.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

# ---------------------------------------------------------------- MDL reader

# An MDL form is delimited by <>, () or []; strings are "..." with \ escapes;
# ;"..." and ;<...> are commented-out forms. Everything else is an atom.
_MDL_TOKEN = re.compile(
    r"""
      (?P<comment>;)                 # comment prefix — the NEXT form is a comment
    | (?P<string>"(?:[^"\\]|\\.)*")
    | (?P<open>[<(\[])
    | (?P<close>[>)\]])
    | (?P<atom>[^\s<>()\[\];"]+)
    """,
    re.VERBOSE,
)


class Str(str):
    """A quoted string literal, as opposed to a bare atom.

    Both arrive as `str`, but only a literal carries prose — an atom like
    `,SMAZEDESC` is an indirection to a shared constant, and treating it as text
    silently fills the atlas with variable names.
    """


class Form(list):
    """A parsed MDL/ZIL form. `kind` is the opening bracket."""

    def __init__(self, kind: str, items=()):
        super().__init__(items)
        self.kind = kind

    def head(self) -> str | None:
        """The first atom, e.g. 'ROOM' for <ROOM "WHOUS" ...>."""
        return self[0] if self and isinstance(self[0], str) else None


def _tokenize(text: str):
    for m in _MDL_TOKEN.finditer(text):
        yield m.lastgroup, m.group()


def read_forms(text: str) -> list:
    """Read every top-level form. Commented forms (;"..." / ;<...>) are dropped."""
    stack: list[Form] = [Form("root")]
    pending_comment = False
    for kind, tok in _tokenize(text):
        if kind == "comment":
            pending_comment = True
            continue

        if kind == "open":
            node = Form(tok)
            node._comment = pending_comment
            pending_comment = False
            stack.append(node)
            continue

        if kind == "close":
            if len(stack) > 1:
                node = stack.pop()
                if not getattr(node, "_comment", False):
                    stack[-1].append(node)
            continue

        value = Str(tok[1:-1]) if kind == "string" else tok
        if pending_comment:
            pending_comment = False  # ;"..." — a comment string, drop it
            continue
        stack[-1].append(value)

    return list(stack[0])


def walk(forms):
    """Yield every nested form, depth first."""
    for f in forms:
        if isinstance(f, Form):
            yield f
            yield from walk(f)


# ------------------------------------------------------------ MDL structures


@dataclass(frozen=True)
class Exit:
    """One edge out of a room.

    `kind` says how the move is gated and never why it is refused. A blocked
    exit's refusal message is 1981 MDL prose, and `THIRD_PARTY_NOTICES` records
    that source as the one body that reached the public without a located licence
    grant — so there is deliberately no field here to put one in. The readers
    step over those strings without reading them, and `kind == "blocked"` is the
    whole of the claim the atlas makes.

    `dest` is mostly what the source declares, with one exception: a door names
    both the rooms it joins rather than a destination, so `_exit` picks the end
    that is not the room asking.

    `via` names the mechanism where the source names one: the door object, or the
    flag a conditional exit tests. Both are identifiers, not text. Only the MDL
    reader fills it — ZIL states a gate as a condition on the exit rather than as
    a named thing — so an empty `via` means "not said", not "no mechanism".
    """

    direction: str
    dest: str = ""  # a room id, or "" where the move names no destination
    # 'plain' | 'conditional' | 'door' | 'blocked', and 'unknown' for a form
    # neither reader could classify. Nothing may publish an unknown edge as a
    # plain one: "always open" is the most permissive thing this vocabulary can
    # say, and it is the wrong thing to say about a form nobody understood.
    kind: str = "plain"
    via: str = ""


@dataclass
class MdlRoom:
    id: str
    description: str = ""
    name: str = ""
    exits: list[Exit] = field(default_factory=list)
    contents: list[str] = field(default_factory=list)
    flags: list[str] = field(default_factory=list)
    value: int = 0


@dataclass
class MdlObject:
    id: str
    name: str = ""
    flags: list[str] = field(default_factory=list)
    description: str = ""
    size: int = 0
    find_value: int = 0
    case_value: int = 0
    # What starts inside this object. A room says where its objects begin and an
    # object says the same thing about the objects inside it — the egg in the
    # nest, the canary in the egg — so an object with no room is not therefore
    # unplaced. The declaration is positional: <OBJECT names adjs desc flags
    # action contents props>, and `makstr.44` turns that sixth argument into the
    # runtime `OCONTENTS`, filling each member's `OCAN` back-pointer.
    contents: list[str] = field(default_factory=list)


def _strings(node) -> list[str]:
    """Quoted string literals only — bare atoms are indirections, not text."""
    return [x for x in node if isinstance(x, Str)]


def _flags(node) -> list[str]:
    """<+ ,RLANDBIT ,RLIGHTBIT> or a bare ,RLANDBIT -> ['RLANDBIT', ...]."""
    if isinstance(node, str):
        return [node.lstrip(",")] if node.startswith(",") else []
    return [x.lstrip(",") for x in node if isinstance(x, str) and x.startswith(",")]


def _contained(node) -> list[str]:
    """(<GET-OBJ "EGG"> <GET-OBJ "GCANA">) -> ['EGG', 'GCANA'].

    The one form both a room and an object use to say what starts inside it.
    """
    return [
        oid
        for item in node
        if isinstance(item, Form) and item.head() == "GET-OBJ"
        for oid in _strings(item)
    ]


def _props(node) -> dict:
    """(ODESC1 "..." OSIZE 55 OFVAL 3 OTVAL 7) -> dict."""
    out: dict = {}
    if not isinstance(node, Form):
        return out
    items = list(node)
    i = 0
    while i < len(items) - 1:
        key = items[i]
        if isinstance(key, str) and key.isupper() and not key.startswith(","):
            out[key] = items[i + 1]
            i += 2
        else:
            i += 1
    return out


# The compass both maps are read into. Matching one against the other means
# comparing edge labels, so the two sources are folded to a single vocabulary
# here, in the reader, rather than at every call site downstream.
DIRECTIONS = {
    "NORTH", "SOUTH", "EAST", "WEST", "NE", "NW", "SE", "SW",
    "UP", "DOWN", "IN", "OUT", "LAND",
}

# MDL's own words for two of them. ZIL uses the canonical set as-is.
_DIRECTION_ALIASES = {"ENTER": "IN", "EXIT": "OUT", "LEAVE": "OUT"}


def direction(word: str) -> str:
    return _DIRECTION_ALIASES.get(word, word)


_SETG_FORMS = ("SETG", "PSETG")

# The forms an exit constant can be bound to. A `<SETG …>` holding anything else
# is a description or a message, and no exit slot names one — filtering keeps the
# constant table to the one job it has, and keeps resolution to a single lookup.
_EXIT_FORMS = ("CEXIT", "DOOR")


def _is_exit_value(value) -> bool:
    return value == "#NEXIT" or (
        isinstance(value, Form) and value.head() in _EXIT_FORMS
    )


def _resolve_exit(value, consts: dict):
    """A `,NAME` exit value resolved to whatever it is bound to.

    `,NOTREE`, `,CD`, `,MIREX`. `_is_exit_value` admits only bindings that are
    already an exit value, so this is one lookup and cannot chain.
    """
    if isinstance(value, str) and not isinstance(value, Str) and value.startswith(","):
        value = consts.get(value.lstrip(","))
    while isinstance(value, Form) and value.head() in _SETG_FORMS and len(value) > 2:
        value = value[2]  # <SETG DARK-ROOM <CEXIT …>> both binds and yields
    return value


def _exit(way: str, value, room: str) -> Exit:
    """Classify one resolved direction value."""
    if value == "#NEXIT":  # only via a constant; a literal one never gets here
        return Exit(way, kind="blocked")
    if isinstance(value, Str):
        return Exit(way, dest=str(value))
    if isinstance(value, Form):
        args = _strings(value[1:])
        if value.head() == "CEXIT":
            # <CEXIT flag dest refusal …> — the first two are ids, and the third
            # is the message this reader does not carry.
            return Exit(
                way,
                dest=args[1] if len(args) > 1 else "",
                kind="conditional",
                via=args[0] if args else "",
            )
        if value.head() == "DOOR":
            # <DOOR obj roomA roomB …> names both ends: `CLEAR`'s DOWN and
            # `MGRAT`'s UP are one grating read from opposite sides. So the
            # destination is the end that is not the room asking. Where neither
            # is, the constant resolved to the wrong door and the exit is left
            # without a destination for `--audit` to report.
            far = [r for r in args[1:3] if r != room]
            return Exit(
                way,
                dest=far[0] if len(far) == 1 else "",
                kind="door",
                via=args[0] if args else "",
            )
    return Exit(way, kind="unknown")


def _exits(node, room: str, consts: dict) -> list[Exit]:
    """<EXIT "NORTH" "NHOUS" "EAST" #NEXIT "…"> -> [Exit('NORTH', 'NHOUS'), …].

    Only a quoted word names a direction — `"#!#!#"`, the null direction the
    palantir window is reached by, included. Everything else in that slot is a
    stray typed prefix and is skipped.
    """
    if not isinstance(node, Form):
        return []
    items = list(node)
    if items and items[0] == "EXIT":
        items = items[1:]

    out: list[Exit] = []
    i = 0
    while i < len(items):
        way, i = items[i], i + 1
        if not isinstance(way, Str):
            continue

        # `#NEXIT` is a typed literal whose second half is the refusal message,
        # and `BKBOX` writes the prefix twice over one message. Stepping the
        # cursor past the whole literal — rather than assuming a blocked exit is
        # the last pair in the form, which four rooms disprove — is what keeps
        # the remaining directions paired with their own values. The message is
        # stepped over unread and never reaches an `Exit`.
        blocked = i
        while i < len(items) and items[i] == "#NEXIT":
            i += 1
        if i > blocked:
            if i < len(items) and isinstance(items[i], Str):
                i += 1
            out.append(Exit(direction(way), kind="blocked"))
            continue

        value = _resolve_exit(items[i], consts) if i < len(items) else None
        i += 1
        out.append(_exit(direction(way), value, room))
    return out


def _constants(forms) -> dict[str, str]:
    """Collect <PSETG NAME "text"> / <SETG NAME "text"> string bindings.

    The maze, mine and river rooms share one description between them via these
    constants, so without resolving them ~half the map reads as having no text.
    """
    out: dict[str, str] = {}
    for form in walk(forms):
        if form.kind == "<" and form.head() in _SETG_FORMS and len(form) > 2:
            name, value = form[1], form[2]
            if isinstance(name, str) and isinstance(value, Str):
                out[name] = value
    return out


def parse_mdl_dungeon(text: str) -> tuple[list[MdlRoom], list[MdlObject]]:
    rooms: list[MdlRoom] = []
    objects: list[MdlObject] = []

    forms = read_forms(text)
    consts = _constants(forms)
    # Exit constants are read *positionally*, unlike the description ones above.
    # MDL evaluates a file top to bottom, and `dung.355` binds `CD` twice — to
    # the Tomb/Crypt door, then to the cell door — with rooms using it on both
    # sides of the rebinding. Only the binding in force where a room is declared
    # gives TOMB→CRYPT and NCORR→CELL both correctly, and this loop already walks
    # the top-level forms in file order. The price of reading it here rather than
    # in a `walk()` pass like `_constants` is that a binding nested inside another
    # form is not seen; `dung.355` has none, and `--audit` reports any exit whose
    # destination went missing.
    exit_consts: dict = {}

    def resolve(node) -> str | None:
        """A quoted literal, or an atom naming one."""
        if isinstance(node, Str):
            return str(node)
        if isinstance(node, str) and node.startswith(","):
            return consts.get(node.lstrip(","))
        return None

    for form in forms:
        if not isinstance(form, Form) or form.kind != "<":
            continue
        head = form.head()

        if head in _SETG_FORMS and len(form) > 2 and isinstance(form[1], str):
            if _is_exit_value(form[2]):
                exit_consts[form[1]] = form[2]

        if head == "ROOM":
            body = list(form[1:])
            if not body:
                continue
            ids = body[0]
            names = _strings(ids) if isinstance(ids, Form) else [ids]
            if not names:
                continue
            room = MdlRoom(id=names[0])
            texts = [t for t in (resolve(x) for x in body[1:]) if t is not None]
            if texts:
                room.description = texts[0]
            if len(texts) > 1:
                room.name = texts[1]
            for part in body[1:]:
                if isinstance(part, Form):
                    if part.head() == "EXIT":
                        room.exits = _exits(part, room.id, exit_consts)
                    elif part.head() == "+":
                        room.flags = _flags(part)
                    elif part.kind == "(":
                        props = _props(part)
                        if "RVAL" in props:
                            try:
                                room.value = int(props["RVAL"])
                            except (TypeError, ValueError):
                                pass
                        room.contents.extend(_contained(part))
                elif isinstance(part, str) and part.startswith(","):
                    room.flags.extend(_flags(part))
            rooms.append(room)

        elif head == "OBJECT":
            body = list(form[1:])
            if not body:
                continue
            ids = body[0]
            names = _strings(ids) if isinstance(ids, Form) else [ids]
            # MDL's ! splice syntax leaves a pseudo-id behind; not a real object.
            names = [n for n in names if re.fullmatch(r"[A-Z0-9]+", n)]
            if not names:
                continue
            obj = MdlObject(id=names[0])
            texts = [t for t in (resolve(x) for x in body[2:]) if t is not None]
            if texts:
                obj.name = texts[0]
            for part in body[2:]:
                if isinstance(part, Form):
                    if part.head() == "+":
                        obj.flags = _flags(part)
                    elif part.kind == "(":
                        props = _props(part)
                        desc = resolve(props.get("ODESC1"))
                        if desc:
                            obj.description = desc
                        obj.contents.extend(_contained(part))
                        for key, attr in (
                            ("OSIZE", "size"),
                            ("OFVAL", "find_value"),
                            ("OTVAL", "case_value"),
                        ):
                            if key in props:
                                try:
                                    setattr(obj, attr, int(props[key]))
                                except (TypeError, ValueError):
                                    pass
                elif isinstance(part, str) and part.startswith(","):
                    obj.flags.extend(_flags(part))
            objects.append(obj)

    return rooms, objects


# ------------------------------------------------------------------ ZIL side


@dataclass
class ZilEntity:
    id: str
    kind: str  # 'ROOM' | 'OBJECT'
    game: str  # 'Zork I' | 'Zork II' | 'Zork III'
    desc: str = ""  # short name
    ldesc: str = ""  # room / long description
    fdesc: str = ""  # first-sight description
    exits: list[Exit] = field(default_factory=list)
    location: str = ""  # the (IN …) room, for an object


def _zil_exit(key: str, atoms: list[str]) -> Exit | None:
    """(NORTH TO CELLAR IF …) -> Exit('NORTH', 'CELLAR').

    ZIL states a room's exits as one property per direction, so the direction is
    the property key rather than a member of the value list.

    `PER` hands the move to a routine, and `SORRY "…"` — or a bare string —
    refuses it outright. Neither names a destination, so both give an edge with
    no `dest`, the same convention `_exits` uses for a blocked MDL exit. Both
    readers put an edge into one `Exit`, so the graph matcher reads the two maps
    through a single code path.

    `kind` therefore has to mean the same thing on both sides. `IF` is ZIL's
    gate — including the one on a door, which it states as a condition on the
    exit rather than as a thing — so an `IF` reads as conditional, exactly as
    MDL's `<CEXIT …>` does. ZIL never names the mechanism, so `via` stays empty
    and the atlas's `door` kind is MDL-only.
    """
    if key not in DIRECTIONS:
        return None
    gated = "conditional" if "IF" in atoms or "PER" in atoms else "plain"
    if "TO" in atoms:
        rest = atoms[atoms.index("TO") + 1:]
        return Exit(key, rest[0], gated) if rest else None
    return Exit(key, kind="conditional" if "PER" in atoms else "blocked")


def parse_zil(text: str, game: str) -> list[ZilEntity]:
    out: list[ZilEntity] = []
    for form in read_forms(text):
        if not isinstance(form, Form) or form.kind != "<":
            continue
        head = form.head()
        if head not in ("ROOM", "OBJECT"):
            continue
        body = list(form[1:])
        if not body or not isinstance(body[0], str):
            continue
        ent = ZilEntity(id=body[0], kind=head, game=game)
        for part in body[1:]:
            if not isinstance(part, Form) or part.kind != "(":
                continue
            key = part.head()
            lits = _strings(part[1:])
            atoms = [x for x in part[1:] if isinstance(x, str) and not isinstance(x, Str)]
            if key == "DESC" and lits:
                ent.desc = lits[0]
            elif key == "LDESC" and lits:
                ent.ldesc = lits[0]
            elif key == "FDESC" and lits:
                ent.fdesc = lits[0]
            elif head == "OBJECT" and key == "IN" and atoms:
                # On an object, (IN KITCHEN) is where it starts.
                ent.location = atoms[0]
            elif head == "ROOM":
                # On a room, (IN TO CELLAR) is the "in" exit — but (IN ROOMS)
                # only files the room in the room table, and names no edge.
                if key == "IN" and atoms == ["ROOMS"]:
                    continue
                edge = _zil_exit(key, atoms)
                if edge:
                    ent.exits.append(edge)
        out.append(ent)
    return out
