# Find the Gnusto checkout this package depends on, and run one of its tools
# against *this* package. Sourced by the shims beside this file; not executable
# and not run directly.
#
# A game written by `bin/new-game` holds no copy of Gnusto's tooling — only these
# shims. That is the entire point. A copied script is pinned to the day it was
# copied and rots silently as the engine moves, and the obvious repair, an update
# command, cannot work: an author who took Gnusto as a git dependency has no
# clone of it to run one from. A shim has no version of its own, so
# `swift package update` moves the engine and its tools together and the two
# cannot disagree.
#
# **Nothing here asks SwiftPM anything.** Resolution is three filesystem probes,
# because `swift package show-dependencies` would take the exclusive .build lock
# — and an MCP client starts every server in .mcp.json at once. Seven of them
# queueing on that lock to perform seven no-ops is what cost the Gnusto repo two
# play-test rounds; `bin/gnusto-mcp` carries the long version of that story.

gnusto_die() { echo "gnusto: $*" >&2; exit 2; }

# Generated games can also be named Gnusto and carry an MCP shim. The focus
# module belongs only to the engine's tooling.
gnusto_is_checkout() {
  [ -d "$1/Sources/Gnusto" ] && [ -x "$1/bin/gnusto-mcp" ] \
    && [ -f "$1/bin/lib/playtest-focus.js" ]
}

# Decode the ordinary Swift string literal emitted by bin/new-game. No eval:
# backslashes in a filesystem name must never become shell or Swift code.
#
# The pattern stops at the literal's closing quote and says nothing about what
# follows it, because arguments do get added there: the generated manifest now
# passes `traits:` as well. Requiring `")` found nothing the day that argument
# arrived, and a shim that cannot locate the engine reports it as a missing
# tool rather than as a manifest it could not read.
gnusto_dependency_path() {
  local literal character decoded=""
  literal="$(sed -En 's/.*\.package\(name: "Gnusto", path: "(([^"\\]|\\.)*)".*/\1/p' "$1" 2>/dev/null | head -1)"
  while [ -n "$literal" ]; do
    character="${literal:0:1}"
    literal="${literal:1}"
    if [ "$character" = '\' ]; then
      character="${literal:0:1}"
      literal="${literal:1}"
      case "$character" in
        '\'|'"') ;;
        n) character=$'\n' ;;
        r) character=$'\r' ;;
        t) character=$'\t' ;;
        *) return 1 ;;
      esac
    fi
    decoded="$decoded$character"
  done
  printf '%s' "$decoded"
}

# $1 is this package's root. Prints the Gnusto checkout, or dies saying what to do.
gnusto_find_repo() {
  # local: this is sourced into each shim's top-level shell, not run as its own
  # process, so an unscoped assignment here would leak into and clobber the
  # caller's own variables of the same name (gnusto_exec below sets its own
  # "pkg" right after calling this).
  local pkg="$1"
  local candidate

  # An explicit override wins, so somebody working against a local clone of the
  # engine never has to argue with the search below.
  if [ -n "${GNUSTO_REPO:-}" ]; then
    gnusto_is_checkout "$GNUSTO_REPO" \
      || gnusto_die "GNUSTO_REPO=$GNUSTO_REPO is not a Gnusto checkout"
    (cd "$GNUSTO_REPO" && pwd -P)
    return
  fi

  # The ordinary case: a git dependency, which SwiftPM resolves into
  # .build/checkouts under the URL's last path component. The glob rather than a
  # literal "Gnusto" because that name is the URL's spelling, not a guarantee.
  for candidate in "$pkg"/.build/checkouts/*; do
    if gnusto_is_checkout "$candidate"; then
      (cd "$candidate" && pwd -P)
      return
    fi
  done

  # A path dependency is used in place and produces no checkout at all, so the
  # probe above finds nothing. Read the path out of the manifest instead: the
  # dependency is one line, written by bin/new-game, and reading it costs nothing.
  candidate="$(gnusto_dependency_path "$pkg/Package.swift")" || candidate=""
  if [ -n "$candidate" ]; then
    case "$candidate" in
      /*) ;;
      *) candidate="$pkg/$candidate" ;;
    esac
    if gnusto_is_checkout "$candidate"; then
      (cd "$candidate" && pwd -P)
      return
    fi
  fi

  gnusto_die "no Gnusto checkout found. Run \`swift build\` first — Gnusto's tools live in its own checkout, and this package only holds shims that call them. Set GNUSTO_REPO to override."
}

# Hand the process to one of Gnusto's tools, standing in this package.
gnusto_exec() {
  # local for the same reason as gnusto_find_repo above: sourced functions share
  # one shell with the shim that called them, so an unscoped "tool" or "repo"
  # here would be visible (and wrong) if the shim itself ever read a variable
  # by that name.
  local tool="$1"
  shift
  # $0 is this shim even though the function is sourced, so this is the game's
  # root and not the engine's.
  local pkg
  pkg="$(cd "$(dirname "$0")/.." && pwd -P)"
  local repo
  repo="$(gnusto_find_repo "$pkg")"
  [ ! "$repo" -ef "$pkg" ] \
    || gnusto_die "resolved Gnusto checkout is the same package as the invoking shim: $pkg"
  [ ! "$repo/bin/$tool" -ef "$0" ] \
    || gnusto_die "$repo/bin/$tool resolves to the invoking shim"
  [ -x "$repo/bin/$tool" ] \
    || gnusto_die "$repo/bin/$tool is missing or not executable"
  # Package identity and caller-relative paths are separate after this cd.
  export GNUSTO_INVOCATION_DIR="$PWD"
  if [ -n "${GNUSTO_REPO:-}" ]; then export GNUSTO_REPO="$repo"; fi
  cd "$pkg"
  GNUSTO_PACKAGE_PATH="$pkg" exec "$repo/bin/$tool" "$@"
}
