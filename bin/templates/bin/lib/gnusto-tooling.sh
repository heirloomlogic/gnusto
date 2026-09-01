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

# Does this directory hold the Gnusto engine? Both halves matter: Sources/Gnusto
# says it is the engine rather than some other dependency, and bin/gnusto-mcp
# says it is a git checkout rather than an unpacked release with no tools in it.
gnusto_is_checkout() { [ -d "$1/Sources/Gnusto" ] && [ -x "$1/bin/gnusto-mcp" ]; }

# $1 is this package's root. Prints the Gnusto checkout, or dies saying what to do.
gnusto_find_repo() {
  pkg="$1"

  # An explicit override wins, so somebody working against a local clone of the
  # engine never has to argue with the search below.
  if [ -n "${GNUSTO_REPO:-}" ]; then
    gnusto_is_checkout "$GNUSTO_REPO" \
      || gnusto_die "GNUSTO_REPO=$GNUSTO_REPO is not a Gnusto checkout"
    echo "$GNUSTO_REPO"
    return
  fi

  # The ordinary case: a git dependency, which SwiftPM resolves into
  # .build/checkouts under the URL's last path component. The glob rather than a
  # literal "Gnusto" because that name is the URL's spelling, not a guarantee.
  for candidate in "$pkg"/.build/checkouts/*; do
    if gnusto_is_checkout "$candidate"; then
      echo "$candidate"
      return
    fi
  done

  # A path dependency is used in place and produces no checkout at all, so the
  # probe above finds nothing. Read the path out of the manifest instead: the
  # dependency is one line, written by bin/new-game, and reading it costs nothing.
  candidate="$(
    sed -n 's/.*\.package(name: "Gnusto", path: "\([^"]*\)").*/\1/p' \
      "$pkg/Package.swift" 2>/dev/null | head -1
  )"
  if [ -n "$candidate" ]; then
    case "$candidate" in
      /*) ;;
      *) candidate="$pkg/$candidate" ;;
    esac
    if gnusto_is_checkout "$candidate"; then
      echo "$candidate"
      return
    fi
  fi

  gnusto_die "no Gnusto checkout found. Run \`swift build\` first — Gnusto's tools live in its own checkout, and this package only holds shims that call them. Set GNUSTO_REPO to override."
}

# Hand the process to one of Gnusto's tools, standing in this package.
gnusto_exec() {
  tool="$1"
  shift
  # $0 is this shim even though the function is sourced, so this is the game's
  # root and not the engine's.
  pkg="$(cd "$(dirname "$0")/.." && pwd)"
  repo="$(gnusto_find_repo "$pkg")"
  [ -x "$repo/bin/$tool" ] \
    || gnusto_die "$repo/bin/$tool is missing or not executable"
  # Both halves are needed: cd for the tools that read the working directory
  # (playtest-replay defaults --package-path to $PWD), and the variable for the
  # tools that derive their root from $0, which after this exec points into the
  # engine's checkout.
  cd "$pkg"
  GNUSTO_PACKAGE_PATH="$pkg" exec "$repo/bin/$tool" "$@"
}
