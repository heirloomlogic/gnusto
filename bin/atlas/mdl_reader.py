"""Minimal readers for MDL (mainframe Zork) and ZIL (Zork I/II/III) source.

Parses the declaration forms far enough to inventory rooms and objects, and to
recover both maps as directed graphs. Not a general MDL/ZIL interpreter — it
reads structure, not semantics.

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


@dataclass
class MdlRoom:
    id: str
    description: str = ""
    name: str = ""
    exits: list[tuple[str, str]] = field(default_factory=list)
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


def _strings(node) -> list[str]:
    """Quoted string literals only — bare atoms are indirections, not text."""
    return [x for x in node if isinstance(x, Str)]


def _flags(node) -> list[str]:
    """<+ ,RLANDBIT ,RLIGHTBIT> or a bare ,RLANDBIT -> ['RLANDBIT', ...]."""
    if isinstance(node, str):
        return [node.lstrip(",")] if node.startswith(",") else []
    return [x.lstrip(",") for x in node if isinstance(x, str) and x.startswith(",")]


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


def _exits(node) -> list[tuple[str, str]]:
    """<EXIT "NORTH" "NHOUS" "EAST" #NEXIT "..."> -> [('NORTH','NHOUS'), ...].

    Conditional/blocked exits are recorded with a marker destination so the
    atlas can show that an edge exists without pretending it is a plain move.
    """
    if not isinstance(node, Form):
        return []
    items = list(node)
    if items and items[0] == "EXIT":
        items = items[1:]

    out: list[tuple[str, str]] = []
    i = 0
    while i < len(items):
        way = items[i]
        if not isinstance(way, str) or way.startswith("#"):
            i += 1
            continue
        dest = "?"
        if i + 1 < len(items):
            nxt = items[i + 1]
            if isinstance(nxt, Form):
                dest = f"<{nxt.head() or 'form'}>"
            elif nxt == "#NEXIT":
                dest = "#blocked"
                i += 1  # the refusal string follows
            elif nxt == "#CEXIT":
                dest = "#conditional"
            elif isinstance(nxt, str):
                dest = nxt
        out.append((direction(way), dest))
        i += 2
    return out


def _constants(forms) -> dict[str, str]:
    """Collect <PSETG NAME "text"> / <SETG NAME "text"> string bindings.

    The maze, mine and river rooms share one description between them via these
    constants, so without resolving them ~half the map reads as having no text.
    """
    out: dict[str, str] = {}
    for form in walk(forms):
        if form.kind == "<" and form.head() in ("PSETG", "SETG") and len(form) >= 3:
            name, value = form[1], form[2]
            if isinstance(name, str) and isinstance(value, Str):
                out[name] = value
    return out


def parse_mdl_dungeon(text: str) -> tuple[list[MdlRoom], list[MdlObject]]:
    rooms: list[MdlRoom] = []
    objects: list[MdlObject] = []

    forms = read_forms(text)
    consts = _constants(forms)

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
                        room.exits = _exits(part)
                    elif part.head() == "+":
                        room.flags = _flags(part)
                    elif part.kind == "(":
                        props = _props(part)
                        if "RVAL" in props:
                            try:
                                room.value = int(props["RVAL"])
                            except (TypeError, ValueError):
                                pass
                        for item in part:
                            if isinstance(item, Form) and item.head() == "GET-OBJ":
                                room.contents.extend(_strings(item))
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
    exits: list[tuple[str, str]] = field(default_factory=list)
    location: str = ""  # the (IN …) room, for an object


def _zil_exit(key: str, atoms: list[str]) -> tuple[str, str] | None:
    """(NORTH TO CELLAR IF …) -> ('NORTH', 'CELLAR').

    ZIL states a room's exits as one property per direction, so the direction is
    the property key rather than a member of the value list.

    `PER` hands the move to a routine, and `SORRY "…"` — or a bare string —
    refuses it outright. Neither names a destination, so both are recorded as an
    edge with a marker, the same convention `_exits` uses for MDL's #CEXIT and
    #NEXIT.
    """
    if key not in DIRECTIONS:
        return None
    if "TO" in atoms:
        rest = atoms[atoms.index("TO") + 1:]
        return (key, rest[0]) if rest else None
    return (key, "#conditional" if "PER" in atoms else "#blocked")


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
