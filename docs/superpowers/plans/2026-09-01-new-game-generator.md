# New Game Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the copy-and-hand-edit `Templates/NewGame/` with `bin/new-game`, a generator that writes a named game package from `bin/templates/`, whose `bin/` holds shims that exec Gnusto's real tools out of the resolved checkout rather than copies that go stale.

**Architecture:** `Templates/NewGame/` moves to `bin/templates/` and stays a real, buildable Swift package (its files keep saying `MyGame` literally, so CI can build it in place). `bin/new-game <GameName> <dir>` copies that tree, renames `MyGame` throughout, and rewrites one marked dependency line. The generated `bin/` is four four-line shims over one sourced library, `bin/lib/gnusto-tooling.sh`, which locates the Gnusto checkout by filesystem probe and `exec`s the real tool with the author's package as the working directory.

**Tech Stack:** bash 3.2 (macOS ships `/bin/bash` 3.2 — no `mapfile`, no associative arrays), Swift 6.2 / SwiftPM, Swift Testing (`@Test`, `#expect`), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-01-new-game-generator-design.md`

## Global Constraints

Every task's requirements implicitly include this section.

- **Bash scripts:** `#!/usr/bin/env bash`, then a comment block opening with a one-line purpose and a `# Usage:` block showing each invocation form, then `set -euo pipefail`. This is the shape of every existing script in `bin/`.
- **Bash 3.2 compatibility.** macOS ships `/bin/bash` 3.2. No `mapfile`, no `declare -A`, no `${var^^}`. Read into an array the way `bin/export-game:25-29` does: `while IFS= read -r line; do arr+=("$line"); done < <(…)`.
- **Usage errors exit 2**, printing the reason and the valid values, following `bin/export-game:37-48`.
- **Comments explain *why*, including the incident that motivated the code.** This is the distinctive house convention — see `bin/gnusto-mcp:19-27` and `bin/export-game:56-61`. A comment restating what the next line does is not wanted; a comment saying what broke when it was absent is.
- **Markdown in this repo must not be hard-wrapped.** Each paragraph and each list item is ONE unbroken line, however long. Newlines belong only between blocks. A pre-commit hook rejects hard-wrapped markdown. (Older files under `docs/superpowers/` are wrapped at 80; do not imitate them, and do not reflow them either.)
- **Swift tests:** `import Foundation` / `import Testing`, a bare `struct XTests { @Test func … }` with no `@Suite` (the dominant idiom — `@Suite` appears in only 7 of 169 files), `#expect` for assertions.
- **Finding the package root from a test** uses the `#filePath` walk, the established idiom at `Tests/GnustoTests/PlaytestRouteTests.swift:22-27` and `Tests/GnustoTests/ProseConventionTests.swift:411-417`. Do not add a shared `PackageDirectory.swift` helper; that was PR #381's approach and PR #381 is closed.
- **The suite is sub-second and stays that way.** No task may add a test that builds a Swift package.
- **CI Swift commands keep** `--build-system swiftbuild --disable-experimental-prebuilts`, for the reasons recorded in `.github/workflows/test.yml:110-114` and in `CLAUDE.md`.
- **The dependency version pinned by default is read at generation time** via `git describe --tags --abbrev=0`. Today that is `0.4.0`. Never hardcode a version in the generator.
- **Verification before any completion claim:** `swift build`, `swift test`, and the strict lint (`xcrun swift-format lint --strict --parallel --recursive --configuration .swift-format Sources Tests`, after `.build/checkouts/Persnicket/bin/ci-lint-setup` has run once in this checkout).

---

### Task 1: Move the template to `bin/templates/`

Pure relocation, so the repository stays green at every point. Nothing is generated yet; this task only stops the tree calling the template a folder to copy.

**Files:**
- Move: `Templates/NewGame/` → `bin/templates/` (8 tracked files)
- Delete: `bin/templates/bin/gnusto-mcp` (the one file that does not come across — it is a byte copy of `bin/gnusto-mcp`, which is exactly the duplication this work removes)
- Modify: `.gitignore:25`
- Modify: `.github/workflows/test.yml:127-130`
- Modify: `bin/export-game:19-20`

**Interfaces:**
- Consumes: nothing.
- Produces: the path `bin/templates/` as a buildable Swift package with a `path: "../.."` dependency on this repository. Tasks 3, 4 and 5 all depend on that path.

- [ ] **Step 1: Move the directory and drop the duplicated launcher**

```bash
git mv Templates/NewGame bin/templates
git rm bin/templates/bin/gnusto-mcp
rmdir bin/templates/bin 2>/dev/null || true
rm -rf Templates
```

- [ ] **Step 2: Verify the moved package still builds and tests**

Run: `swift test --package-path bin/templates`

Expected: PASS, 4 tests. `../..` from `bin/templates` is the repository root, exactly as it was from `Templates/NewGame`, so the path dependency at `bin/templates/Package.swift:15` resolves unchanged.

- [ ] **Step 3: Repoint the gitignore entry**

In `.gitignore`, replace line 25:

```
Templates/NewGame/Package.resolved
```

with:

```
bin/templates/Package.resolved
```

Leave the comment at `:21-24` alone; its last sentence ("The template resolves its own too.") is still true.

- [ ] **Step 4: Repoint the CI step**

In `.github/workflows/test.yml`, replace lines 127-130:

```yaml
      # The starter template is a standalone package with a path dependency on
      # this repo; building it here keeps the template from rotting.
      - name: Template (Debug)
        run: swift test --package-path Templates/NewGame --build-system swiftbuild --disable-experimental-prebuilts
```

with:

```yaml
      # The template is a standalone package with a path dependency on this repo;
      # building it here keeps it from rotting. It is also the generator's input,
      # so a green run here is the precondition for the generated-package step
      # below it.
      - name: Template (Debug)
        run: swift test --package-path bin/templates --build-system swiftbuild --disable-experimental-prebuilts
```

Task 5 adds the generated-package step this comment forward-references.

- [ ] **Step 5: Fix the stale comment in `bin/export-game`**

In `bin/export-game`, replace lines 19-20:

```bash
# Discover this package's executable products from the live manifest, so an
# author who copied Templates/NewGame can export their own game with no edits to
```

with:

```bash
# Discover this package's executable products from the live manifest, so a game
# written by bin/new-game can export itself with no edits to
```

- [ ] **Step 6: Confirm no reference to the old path survives in code or config**

Run: `grep -rn "Templates/NewGame" --exclude-dir=.git --exclude-dir=.build --exclude-dir=superpowers .`

Expected: hits ONLY in `README.md:38`, `.claude/workflows/playtest.js:174`, `.github/workflows/release.yml:9`, `Sources/Gnusto/Documentation.docc/GettingStarted.md:9,204`, `Sources/Gnusto/Documentation.docc/PlayTesting.md:54,64,82`, `Sources/Gnusto/Documentation.docc/SharingYourGame.md:31,103,134`. Those are prose and are Task 5's business — the docs are rewritten once the generator they should describe exists, not twice.

- [ ] **Step 7: Run the full suite and the lint**

Run: `swift build && swift test`
Expected: PASS.

Run: `xcrun swift-format lint --strict --parallel --recursive --configuration .swift-format Sources Tests`
Expected: no output.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "$(printf 'The starter template moves under bin, where the generator will read it (#368)\n\nTemplates/NewGame becomes bin/templates, and its copy of bin/gnusto-mcp\ngoes: a byte-identical duplicate of a script this repo already ships is\nthe thing the generator exists to stop shipping. The package is otherwise\nunchanged and still builds in place, because ../.. from bin/templates is\nstill the repository root.\n\nDocs still point at the old path on purpose; they are rewritten once the\ngenerator they should describe exists.\n\nCo-Authored-By: Claude <noreply@anthropic.com>')"
```

---

### Task 2: Let Gnusto's tools be run from outside their own checkout

Three scripts derive a path from `$0` or from the working directory in a way that is correct in this repository and wrong when a shim `exec`s them from an author's package. This task fixes all three, with no behaviour change here.

**Files:**
- Modify: `bin/export-game:16-17`
- Modify: `bin/gnusto-mcp:60-63`
- Modify: `bin/playtest-replay:259`

**Interfaces:**
- Consumes: nothing.
- Produces: the environment variable **`GNUSTO_PACKAGE_PATH`** — when set, it is the absolute path of the package `bin/export-game` and `bin/gnusto-mcp` should stand in. Unset, both behave exactly as before. Task 3's `gnusto_exec` sets it.

- [ ] **Step 1: Write the failing test**

There is no Swift test here — this is observable behaviour of two shell scripts, and the cheapest true test is to run them. `bin/export-game` with no arguments prints the executable products of whatever package it is standing in, which makes the change directly visible.

Run this now, before any edit, to record the current (broken) behaviour:

```bash
GNUSTO_PACKAGE_PATH="$PWD/bin/templates" bin/export-game
```

Expected: it lists this repository's demo games (`CloakOfDarkness`, `Dungeon`, `Fulminate`, `Gramarye`, `KindlyDeep`, `Lighthouse`, `Zork1`) and **not** `MyGame` — the variable is ignored today.

- [ ] **Step 2: Honour the variable in `bin/export-game`**

Replace lines 16-17:

```bash
# Run from the package root regardless of where the script is invoked.
cd "$(dirname "$0")/.."
```

with:

```bash
# Run from the package root regardless of where the script is invoked. That root
# is normally this script's own package — but a game written by bin/new-game runs
# this script through a shim that execs it out of Gnusto's checkout, and then $0
# points at the engine rather than at the game. GNUSTO_PACKAGE_PATH is how the
# shim says which package it meant; unset, nothing changes.
cd "${GNUSTO_PACKAGE_PATH:-$(dirname "$0")/..}"
```

- [ ] **Step 3: Run the test to verify it passes**

```bash
GNUSTO_PACKAGE_PATH="$PWD/bin/templates" bin/export-game
```

Expected: lists exactly `MyGame`.

```bash
bin/export-game
```

Expected: lists this repository's seven demo games, unchanged.

- [ ] **Step 4: Honour the variable in `bin/gnusto-mcp`**

Replace lines 60-63:

```bash
# Run from the package root regardless of where the client invoked us from: an
# MCP client chooses its own working directory, and `swift build` has to be
# standing in the package.
cd "$(dirname "$0")/.."
```

with:

```bash
# Run from the package root regardless of where the client invoked us from: an
# MCP client chooses its own working directory, and `swift build` has to be
# standing in the package. GNUSTO_PACKAGE_PATH names that package when a game
# written by bin/new-game reaches this script through a shim, because then $0 is
# in Gnusto's checkout and the game is somewhere else entirely. Unset, nothing
# changes — and the binpath cache below stays relative to the root either way,
# so a shimmed game records its binary under its own .context/.
cd "${GNUSTO_PACKAGE_PATH:-$(dirname "$0")/..}"
```

- [ ] **Step 5: Fix the module path in `bin/playtest-replay`**

Line 259 currently reads:

```bash
  if ! route_read="$( node bin/lib/playtest-route-prefix.js "$pkg" "$game" "$start_route" )"; then
```

`bin/lib/…` is relative to the working directory. Under a shim that directory is the author's package, which has no `bin/lib/`, so `--start` would die with a node "Cannot find module" stack trace instead of the sentence it is written to refuse with. Replace it with:

```bash
  # Resolved against this script rather than the working directory: a shimmed
  # game execs this script from Gnusto's checkout while standing in its own
  # package, and only the engine's checkout has bin/lib. Identical to `bin/lib/…`
  # when run from this repository.
  if ! route_read="$( node "$(dirname "$0")/lib/playtest-route-prefix.js" "$pkg" "$game" "$start_route" )"; then
```

- [ ] **Step 6: Verify `--start` still works in this repository**

Run: `bin/playtest-replay Dungeon --start c-1 --commands /dev/null --label plan-task2 --tail 5`

Expected: it replays the committed route and reports landing in the Shaft Room. (If `bin/playtest-replay --build Dungeon` has never run in this checkout, run that first; a cold build is slow but not a failure.)

- [ ] **Step 7: Run the full suite**

Run: `swift build && swift test`
Expected: PASS. No Swift source changed, so this is a regression check on the scripts the harness tests reference, not on new code.

- [ ] **Step 8: Commit**

```bash
git add bin/export-game bin/gnusto-mcp bin/playtest-replay
git commit -m "$(printf 'A tool run from outside its own checkout is told which package it means (#368)\n\nexport-game and gnusto-mcp derive the package root from $0, and\nplaytest-replay reads bin/lib relative to the working directory. All three\nare right in this repository and wrong the moment a generated game execs\nthem out of a resolved Gnusto checkout while standing somewhere else.\n\nGNUSTO_PACKAGE_PATH names the package the caller meant, and the node module\nresolves against the script instead of the cwd. Unset and un-shimmed, every\none of them behaves exactly as before.\n\nCo-Authored-By: Claude <noreply@anthropic.com>')"
```

---

### Task 3: The shims and their library

The five files a generated game gets in place of any copy of a tool. They live in `bin/templates/bin/`, so they are real reviewable files rather than heredocs inside the generator — and so they can be exercised in place, which Step 7 does.

**Files:**
- Create: `bin/templates/bin/lib/gnusto-tooling.sh`
- Create: `bin/templates/bin/gnusto-mcp`
- Create: `bin/templates/bin/playtest-replay`
- Create: `bin/templates/bin/playtest-measure`
- Create: `bin/templates/bin/export-game`

**Interfaces:**
- Consumes: `GNUSTO_PACKAGE_PATH` from Task 2.
- Produces: shell functions `gnusto_die`, `gnusto_is_checkout`, `gnusto_find_repo` and `gnusto_exec`, all defined in `bin/lib/gnusto-tooling.sh` and used only by the four shims beside it. `gnusto_exec <tool-name> "$@"` never returns. Task 4's generator copies all five files verbatim; Task 4's tests assert their presence and permission bits.

- [ ] **Step 1: Write the library**

Create `bin/templates/bin/lib/gnusto-tooling.sh`:

```bash
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
```

- [ ] **Step 2: Write the four shims**

Each is the same four lines over a different tool name. Create `bin/templates/bin/export-game`:

```bash
#!/usr/bin/env bash
#
# Build this game as a standalone executable under ./dist.
#
# Usage:  bin/export-game <Product>     (bin/export-game with no argument lists them)
#
# A shim. The real script lives in the Gnusto checkout this package depends on,
# so it is never out of step with the engine — see bin/lib/gnusto-tooling.sh.

set -euo pipefail
. "$(dirname "$0")/lib/gnusto-tooling.sh"
gnusto_exec export-game "$@"
```

Create `bin/templates/bin/gnusto-mcp`:

```bash
#!/usr/bin/env bash
#
# Serve this game to an MCP client over stdio. Registered in .mcp.json; not
# something you normally run by hand.
#
# Usage:  bin/gnusto-mcp <Game>
#
# A shim. The real script lives in the Gnusto checkout this package depends on,
# so it is never out of step with the engine — see bin/lib/gnusto-tooling.sh.
#
# Stdout is the protocol, so this file prints nothing on the way to the exec.

set -euo pipefail
. "$(dirname "$0")/lib/gnusto-tooling.sh"
gnusto_exec gnusto-mcp "$@"
```

Create `bin/templates/bin/playtest-replay`:

```bash
#!/usr/bin/env bash
#
# Replay a list of commands against this game with the random seed pinned, so a
# hand-played session reproduces exactly.
#
# Usage:  bin/playtest-replay <Game> --commands probe.txt --seed 0 --label mine
#         bin/playtest-replay --build <Game>
#
# A shim. The real script lives in the Gnusto checkout this package depends on,
# so it is never out of step with the engine — see bin/lib/gnusto-tooling.sh.
#
# Its --start flag needs bin/playtest-routes, which this package does not ship;
# the flag refuses in a sentence rather than failing obscurely.

set -euo pipefail
. "$(dirname "$0")/lib/gnusto-tooling.sh"
gnusto_exec playtest-replay "$@"
```

Create `bin/templates/bin/playtest-measure`:

```bash
#!/usr/bin/env bash
#
# Measure how much of the game a play-test round actually reached — rooms, verbs
# and objects — read off the artifacts a probe leaves behind.
#
# Usage:  bin/playtest-measure .context/playtest/mine/probe-*
#
# A shim. The real script lives in the Gnusto checkout this package depends on,
# so it is never out of step with the engine — see bin/lib/gnusto-tooling.sh.

set -euo pipefail
. "$(dirname "$0")/lib/gnusto-tooling.sh"
gnusto_exec playtest-measure "$@"
```

- [ ] **Step 3: Set the permission bits**

```bash
chmod +x bin/templates/bin/export-game bin/templates/bin/gnusto-mcp \
         bin/templates/bin/playtest-replay bin/templates/bin/playtest-measure
chmod 644 bin/templates/bin/lib/gnusto-tooling.sh
```

The library is sourced, not run, so it deliberately does not carry the executable bit. Task 4 asserts both halves of that.

- [ ] **Step 4: Verify git recorded the modes**

```bash
git add bin/templates/bin
git diff --cached --summary
```

Expected: `mode 100755` for the four shims and `mode 100644` for `lib/gnusto-tooling.sh`.

- [ ] **Step 5: Verify resolution through the path-dependency branch**

`bin/templates` depends on `../..` by path, so there is no `.build/checkouts` entry for Gnusto and resolution must fall through to reading the manifest. That makes this the strictest of the three branches to exercise.

Run: `bin/templates/bin/export-game`

Expected: lists exactly `MyGame`. This proves the whole mechanism end to end — the shim found the engine by reading its own `Package.swift`, `cd`'d into `bin/templates`, exec'd this repository's `bin/export-game`, and that script honoured `GNUSTO_PACKAGE_PATH` (Task 2) rather than standing in the engine.

- [ ] **Step 6: Verify the failure message**

```bash
( cd /tmp && mkdir -p gnusto-shim-probe/bin/lib && \
  cp "$OLDPWD"/bin/templates/bin/export-game gnusto-shim-probe/bin/ && \
  cp "$OLDPWD"/bin/templates/bin/lib/gnusto-tooling.sh gnusto-shim-probe/bin/lib/ && \
  gnusto-shim-probe/bin/export-game; echo "exit=$?" )
rm -rf /tmp/gnusto-shim-probe
```

Expected: `gnusto: no Gnusto checkout found. Run \`swift build\` first …` on stderr, and `exit=2`. Not a stack trace, not an ENOENT.

- [ ] **Step 7: Verify the override branch**

```bash
GNUSTO_REPO="$PWD" bin/templates/bin/export-game
```

Expected: lists exactly `MyGame` again — same result by a different route.

- [ ] **Step 8: Confirm the template package still builds**

Run: `swift test --package-path bin/templates`
Expected: PASS, 4 tests. Adding a `bin/` directory does not change what SwiftPM compiles.

- [ ] **Step 9: Commit**

```bash
git add bin/templates/bin
git commit -m "$(printf 'A generated game holds shims over Gnusto own tools, not copies of them (#368)\n\nFour four-line shims over one sourced library. The library finds the Gnusto\ncheckout by three filesystem probes -- an explicit override, .build/checkouts,\nand the path: in the package own manifest -- then cds into the game and execs\nthe real tool. It never asks SwiftPM, because show-dependencies takes the\nexclusive .build lock that seven MCP servers starting at once already contend\nfor.\n\nNothing is copied, so nothing goes stale: swift package update moves the\nengine and its tools together.\n\nCo-Authored-By: Claude <noreply@anthropic.com>')"
```

---

### Task 4: `bin/new-game` and its tests

**Files:**
- Create: `bin/new-game`
- Create: `Tests/GnustoTests/NewGameTests.swift`
- Modify: `bin/templates/Package.swift:10-16`
- Modify: `bin/templates/README.md` (rewritten — it currently tells an author how to copy the template, which is the job this task deletes)

**Interfaces:**
- Consumes: `bin/templates/` (Task 1), the shims in `bin/templates/bin/` (Task 3).
- Produces: the command `bin/new-game <GameName> <destination-dir> [--dep-path <path>]`, exit 0 on success and exit 2 on any usage error. Task 5's CI step calls it with `--dep-path`.

- [ ] **Step 1: Make the dependency a single marked line**

The generator has to rewrite exactly one thing in `Package.swift`, so give it exactly one line to rewrite. Replace `bin/templates/Package.swift:10-16`:

```swift
    dependencies: [
        // In your own copy, depend on Gnusto by URL instead:
        // .package(url: "https://github.com/HeirloomLogic/Gnusto", from: "0.1.0"),
        // (The explicit name is only needed by the path form, because the
        // repo's checkout directory doesn't have to be called "Gnusto".)
        .package(name: "Gnusto", path: "../..")
    ],
```

with:

```swift
    // bin/new-game rewrites the single line carrying the marker below, to a
    // version-pinned URL by default or to another path under --dep-path. It is
    // one line so that rewriting it is one substitution rather than a parse.
    // The explicit `name:` is needed only by the path form, because a checkout
    // directory does not have to be called "Gnusto".
    dependencies: [
        .package(name: "Gnusto", path: "../..")  // gnusto-dependency
    ],
```

Run: `swift test --package-path bin/templates`
Expected: PASS, 4 tests — the manifest is unchanged in meaning.

- [ ] **Step 2: Write the failing test**

Create `Tests/GnustoTests/NewGameTests.swift`:

```swift
import Foundation
import Testing

/// `bin/new-game`, exercised by running it.
///
/// This is the only suite in the package that shells out. It earns that: the
/// generator's whole job is to leave a directory in a particular state, and the
/// nearest thing to a unit test — reimplementing the substitution in Swift and
/// asserting the two agree — would assert that a copy of the code matches the
/// code. Running it costs a file copy and a `sed`, so the suite stays sub-second;
/// nothing here builds a package, which is CI's job.
struct NewGameTests {
    /// The package root, found relative to this file rather than to the working
    /// directory, which a test process does not control.
    private static let packageRoot =
        URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // GnustoTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // the package

    /// Run `bin/new-game` with the given arguments, returning its exit status and
    /// the two streams. Never throws on a non-zero exit — a refusal is a result
    /// this suite asserts against, not an error.
    @discardableResult
    private static func newGame(_ arguments: [String]) throws -> (
        status: Int32, stdout: String, stderr: String
    ) {
        let process = Process()
        process.executableURL = packageRoot.appendingPathComponent("bin/new-game")
        process.arguments = arguments
        process.currentDirectoryURL = packageRoot
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (
            process.terminationStatus,
            String(decoding: outData, as: UTF8.self),
            String(decoding: errData, as: UTF8.self)
        )
    }

    /// A fresh empty directory that does not exist yet, so the generator is the
    /// thing that creates it.
    private static func scratch() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Zwank")
    }

    private static func generate(_ extra: [String] = []) throws -> URL {
        let destination = scratch()
        let result = try newGame(["Zwank", destination.path] + extra)
        #expect(result.status == 0, "bin/new-game failed: \(result.stderr)")
        return destination
    }

    /// Every path under a directory, relative to it, files and directories alike.
    private static func entries(under root: URL) -> [String] {
        let enumerator = FileManager.default.enumerator(atPath: root.path)
        return (enumerator?.allObjects as? [String] ?? []).sorted()
    }

    @Test func generatedPackageKeepsNoTraceOfTheTemplateName() throws {
        let game = try Self.generate()
        defer { try? FileManager.default.removeItem(at: game) }

        for entry in Self.entries(under: game) {
            #expect(!entry.contains("MyGame"), "\(entry) still carries the template name")
            let url = game.appendingPathComponent(entry)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                !isDirectory.boolValue,
                let text = try? String(contentsOf: url, encoding: .utf8)
            else { continue }
            #expect(!text.contains("MyGame"), "\(entry) still mentions MyGame")
            #expect(!text.contains("mygame"), "\(entry) still mentions mygame")
        }
    }

    @Test func generatedPackageIsNamedForTheGame() throws {
        let game = try Self.generate()
        defer { try? FileManager.default.removeItem(at: game) }

        let manifest = try String(
            contentsOf: game.appendingPathComponent("Package.swift"), encoding: .utf8)
        #expect(manifest.contains(#"name: "Zwank""#))
        #expect(manifest.contains(#".executableTarget("#))
        #expect(manifest.contains(#"name: "ZwankTests""#))

        let paths = Self.entries(under: game)
        #expect(paths.contains("Sources/Zwank/Zwank.swift"))
        #expect(paths.contains("Sources/Zwank/Entry.swift"))
        #expect(paths.contains("Tests/ZwankTests/ZwankTests.swift"))
    }

    @Test func mcpEntryIsKeyedLowercaseAndArgumentIsTheProduct() throws {
        let game = try Self.generate()
        defer { try? FileManager.default.removeItem(at: game) }

        let json = try String(
            contentsOf: game.appendingPathComponent(".mcp.json"), encoding: .utf8)
        #expect(json.contains(#""zwank""#))
        #expect(json.contains(#"["Zwank"]"#))
    }

    @Test func toolsAreShimsAndTheLibraryIsNotExecutable() throws {
        let game = try Self.generate()
        defer { try? FileManager.default.removeItem(at: game) }

        for tool in ["export-game", "gnusto-mcp", "playtest-replay", "playtest-measure"] {
            let path = game.appendingPathComponent("bin/\(tool)").path
            #expect(
                FileManager.default.isExecutableFile(atPath: path),
                "bin/\(tool) is missing or not executable")
        }
        let library = game.appendingPathComponent("bin/lib/gnusto-tooling.sh").path
        #expect(FileManager.default.fileExists(atPath: library))
        #expect(
            !FileManager.default.isExecutableFile(atPath: library),
            "the library is sourced, not run, so it should carry no executable bit")
    }

    @Test func dependencyIsAPinnedURLByDefault() throws {
        let game = try Self.generate()
        defer { try? FileManager.default.removeItem(at: game) }

        let manifest = try String(
            contentsOf: game.appendingPathComponent("Package.swift"), encoding: .utf8)
        #expect(manifest.contains(#"url: "https://github.com/HeirloomLogic/Gnusto""#))
        #expect(manifest.contains("from: \""))
        #expect(!manifest.contains("path: \"../..\""))
    }

    @Test func depPathOverridesTheURL() throws {
        let game = try Self.generate(["--dep-path", Self.packageRoot.path])
        defer { try? FileManager.default.removeItem(at: game) }

        let manifest = try String(
            contentsOf: game.appendingPathComponent("Package.swift"), encoding: .utf8)
        #expect(manifest.contains(#"name: "Gnusto", path: ""#))
        #expect(manifest.contains(Self.packageRoot.path))
        #expect(!manifest.contains("url: \"https://github.com"))
    }

    @Test func aNonEmptyDestinationIsRefused() throws {
        let destination = Self.scratch()
        try FileManager.default.createDirectory(
            at: destination, withIntermediateDirectories: true)
        try "occupied".write(
            to: destination.appendingPathComponent("something"), atomically: true,
            encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: destination) }

        let result = try Self.newGame(["Zwank", destination.path])
        #expect(result.status == 2)
        #expect(result.stderr.contains("not empty"))
    }

    @Test func anInvalidGameNameIsRefused() throws {
        let result = try Self.newGame(["my game", Self.scratch().path])
        #expect(result.status == 2)
        #expect(result.stderr.contains("Swift identifier"))
    }

    @Test func missingArgumentsPrintUsage() throws {
        let result = try Self.newGame([])
        #expect(result.status == 2)
        #expect(result.stderr.contains("usage"))
    }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `swift test --filter NewGameTests`

Expected: FAIL. Every test fails at `try process.run()` with a "launch path not accessible" / `NSPOSIXErrorDomain` error, because `bin/new-game` does not exist yet.

- [ ] **Step 4: Write the generator**

Create `bin/new-game`:

```bash
#!/usr/bin/env bash
#
# Write a new Gnusto game package, named for your game, from bin/templates.
#
# Usage:  bin/new-game <GameName> <destination-dir>
#         bin/new-game Zwank ~/dev/Zwank
#         bin/new-game Zwank /tmp/scratch --dep-path /path/to/gnusto
#
# There used to be a Templates/NewGame directory and a README telling you to copy
# it and then rename MyGame in ten places by hand. This does that, and does the
# part the README could not: the generated bin/ holds shims over Gnusto's own
# tools rather than copies of them, so an author's tooling cannot drift from the
# engine it is driving.
#
# --dep-path makes the generated package depend on a Gnusto checkout by path
# instead of by version. CI uses it to test the working tree; an author does not
# need it.

set -euo pipefail

cd "$(dirname "$0")/.."

die() { echo "new-game: $*" >&2; exit 2; }

usage() {
  echo "usage: bin/new-game <GameName> <destination-dir> [--dep-path <path>]" >&2
  exit 2
}

game=""
destination=""
dep_path=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dep-path) dep_path="${2:-}"; [ -n "$dep_path" ] || usage; shift 2 ;;
    -h|--help) usage ;;
    -*) die "unknown option '$1'" ;;
    *)
      if [ -z "$game" ]; then game="$1"
      elif [ -z "$destination" ]; then destination="$1"
      else die "unexpected argument '$1'"
      fi
      shift
      ;;
  esac
done

[ -n "$game" ] && [ -n "$destination" ] || usage

# The name becomes a struct, two target names and two directory names, so it has
# to be something Swift will accept in all five places. Checked here rather than
# left to the compiler, because the compiler's complaint arrives after the files
# are already on disk under the bad name.
case "$game" in
  [A-Za-z_]*) ;;
  *) die "'$game' is not a valid Swift identifier: it must start with a letter or underscore" ;;
esac
case "$game" in
  *[!A-Za-z0-9_]*) die "'$game' is not a valid Swift identifier: only letters, digits and underscores" ;;
esac

if [ -e "$destination" ]; then
  [ -d "$destination" ] || die "'$destination' exists and is not a directory"
  if [ -n "$(ls -A "$destination" 2>/dev/null)" ]; then
    die "'$destination' is not empty"
  fi
fi

if [ -n "$dep_path" ]; then
  [ -d "$dep_path" ] || die "--dep-path '$dep_path' is not a directory"
  dep_path="$(cd "$dep_path" && pwd)"
  dependency=".package(name: \"Gnusto\", path: \"$dep_path\")"
else
  # Pin to whatever this checkout's newest release is, read now rather than
  # hardcoded, so the generator cannot fall behind the tags.
  version="$(git describe --tags --abbrev=0 2>/dev/null || true)"
  [ -n "$version" ] || die "no git tag found to pin against; pass --dep-path instead"
  dependency=".package(url: \"https://github.com/HeirloomLogic/Gnusto\", from: \"$version\")"
fi

mkdir -p "$destination"
destination="$(cd "$destination" && pwd)"

# -a to keep the executable bits on the shims; the trailing /. copies the
# contents including dotfiles (.mcp.json, .github) without nesting a directory.
cp -a bin/templates/. "$destination/"
rm -rf "$destination/.build" "$destination/Package.resolved"

lower="$(echo "$game" | tr '[:upper:]' '[:lower:]')"

# Rename the directories and the one file that carry the name, before rewriting
# contents, so nothing is edited twice.
mv "$destination/Sources/MyGame" "$destination/Sources/$game"
mv "$destination/Sources/$game/MyGame.swift" "$destination/Sources/$game/$game.swift"
mv "$destination/Tests/MyGameTests" "$destination/Tests/${game}Tests"
mv "$destination/Tests/${game}Tests/MyGameTests.swift" \
   "$destination/Tests/${game}Tests/${game}Tests.swift"

# MyGameTests is MyGame + Tests, so one substitution covers both. The lowercase
# pass is for the .mcp.json server key, which is keyed lowercase by convention —
# .claude/workflows/playtest.js reads it that way.
while IFS= read -r file; do
  sed -e "s/MyGame/$game/g" -e "s/mygame/$lower/g" "$file" > "$file.new"
  # Preserve the mode: sed writing to a new file would otherwise strip the
  # executable bit off every shim.
  chmod --reference="$file" "$file.new" 2>/dev/null \
    || chmod "$(stat -f '%OLp' "$file")" "$file.new"
  mv "$file.new" "$file"
done < <(find "$destination" -type f ! -path "*/.git/*")

# The dependency is one marked line, by construction, so this is a substitution
# rather than a parse. See the comment above it in bin/templates/Package.swift.
manifest="$destination/Package.swift"
sed -e "s|^ *\.package(name: \"Gnusto\", path: \"\.\./\.\.\") *// gnusto-dependency\$|        $dependency|" \
  "$manifest" > "$manifest.new"
mv "$manifest.new" "$manifest"
grep -q "gnusto-dependency" "$manifest" \
  && die "internal error: the dependency marker survived rewriting"

echo "Wrote $game to $destination"
echo
echo "  cd $destination"
echo "  swift test        # run the transcript tests"
echo "  swift build && \"\$(swift build --show-bin-path)/$game\"   # play it"
```

- [ ] **Step 5: Make it executable and run the tests**

```bash
chmod +x bin/new-game
swift test --filter NewGameTests
```

Expected: PASS, 9 tests.

- [ ] **Step 6: Rewrite the template's README as the generated game's README**

`bin/templates/README.md` currently opens "A complete, ready-to-copy game package" and its first section is a three-step copy-and-rename checklist. That checklist is what `bin/new-game` replaces, and this file ships *into* the author's package, so it should address them as the owner of a game rather than as somebody about to copy one. Replace the whole file with:

```markdown
# MyGame

A Gnusto game: one game struct, an executable entry point, and transcript tests. Written by `bin/new-game`, so the name above and everything below already say your game's name.

```sh
swift test        # run the transcript tests
swift build       # build the game
```

Run the built binary directly to play — piping input through `swift run` swallows stdin during the build:

```sh
"$(swift build --show-bin-path)/MyGame"
```

## Let an agent play-test it

`.mcp.json` and `bin/gnusto-mcp` are already wired up: your game is an MCP play-test server, and an agent can open a session, take turns, and read back what the prose actually printed. Nothing in your game has to know about it — `GameMain` answers `--mcp` for every Gnusto game, yours included.

An MCP client asks once to approve a project-scoped server, then runs `bin/gnusto-mcp MyGame` itself; stdout is the protocol. The first run builds, which can outlast a client's startup timeout — run `swift build` once first, or raise the client's timeout (`MCP_TIMEOUT`, in milliseconds).

## The tools in `bin/`

`bin/export-game`, `bin/playtest-replay` and `bin/playtest-measure` are shims. The real scripts live in the Gnusto checkout this package depends on, so they are never out of step with the engine — `swift package update` moves both together. They need Gnusto resolved, so run `swift build` once before the first one.

- `bin/export-game MyGame` builds a standalone binary under `dist/` you can hand to a friend.
- `bin/playtest-replay MyGame --commands probe.txt --seed 0 --label mine` replays a command list with the random seed pinned, so a hand-played session reproduces exactly.
- `bin/playtest-measure .context/playtest/mine/probe-*` reports how much of the game a round actually reached.

## What this game already demonstrates

- A `Game` struct with rooms, items, a blocked exit, and scored victory
- A custom player-typeable verb (`ring`) and the rule that answers it
- A live `describe` description that reacts to game state
- The `@main` entry point via `GameMain`
- Transcript tests with `GnustoTestSupport` (`play` + `expectInOrder`)

## Publish binaries on a tag

`.github/workflows/release.yml` is already here. Once this package is at a repo root on GitHub, pushing a version tag builds the game for macOS and Linux and attaches the binaries to the release:

```sh
git tag 1.0.0
git push origin 1.0.0
```

It discovers your executable products from the manifest, so it needs no edits as they change.

The full authoring guides live in Gnusto's DocC catalog — start with "Getting Started with Gnusto".
```

- [ ] **Step 7: Re-run the suite, since the README is substituted like every other file**

Run: `swift test --filter NewGameTests`

Expected: PASS, 9 tests. In particular `generatedPackageKeepsNoTraceOfTheTemplateName` now covers the rewritten README — every `MyGame` in it becomes `Zwank`.

- [ ] **Step 8: Generate a package by hand and build it, once**

The suite deliberately does not build a generated package. Do it once here, by hand, because this is the first moment the whole chain can be checked.

```bash
rm -rf /tmp/Zwank && bin/new-game Zwank /tmp/Zwank --dep-path "$PWD"
swift test --package-path /tmp/Zwank
( cd /tmp/Zwank && bin/export-game )
```

Expected: 4 tests pass, and `bin/export-game` lists exactly `Zwank`. That last line is the proof that the shims resolve from a generated package, not just from `bin/templates` in place.

```bash
rm -rf /tmp/Zwank
```

- [ ] **Step 9: Run the full suite and the lint**

Run: `swift build && swift test`
Expected: PASS.

Run: `xcrun swift-format lint --strict --parallel --recursive --configuration .swift-format Sources Tests`
Expected: no output. (`NewGameTests.swift` is under `Tests/`, so it is linted.)

- [ ] **Step 10: Commit**

```bash
git add bin/new-game bin/templates/Package.swift bin/templates/README.md Tests/GnustoTests/NewGameTests.swift
git commit -m "$(printf 'A game is generated with its own name, not copied and renamed by hand (#368)\n\nbin/new-game <GameName> <dir> copies bin/templates, renames MyGame across\nthe ten sites the old README asked an author to edit by hand, and rewrites\none marked dependency line -- pinned to this checkout newest tag by\ndefault, or to a path under --dep-path.\n\nThe template README stops being instructions for copying a template and\nbecomes the generated game own README, because that is where it ships.\n\nNewGameTests is the only suite here that shells out. It earns it: the\ngenerator job is to leave a directory in a particular state, and the\nalternative is asserting that a Swift copy of the substitution matches the\nsubstitution. Nothing in it builds a package, so the suite stays sub-second.\n\nCo-Authored-By: Claude <noreply@anthropic.com>')"
```

---

### Task 5: CI, and the prose that still describes a folder

**Files:**
- Modify: `.github/workflows/test.yml` (add a step after the template step)
- Modify: `README.md:38`
- Modify: `Sources/Gnusto/Documentation.docc/GettingStarted.md:9,204`
- Modify: `Sources/Gnusto/Documentation.docc/PlayTesting.md:54,64,82`
- Modify: `Sources/Gnusto/Documentation.docc/SharingYourGame.md:31,103,134`
- Modify: `.github/workflows/release.yml:9`
- Modify: `.claude/workflows/playtest.js:174`
- Modify: `CLAUDE.md` (the layout table and the commands block)

**Interfaces:**
- Consumes: `bin/new-game` (Task 4).
- Produces: nothing later tasks read. This is the last task.

- [ ] **Step 1: Add the generated-package CI step**

In `.github/workflows/test.yml`, immediately after the `Template (Debug)` step from Task 1, add:

```yaml
      # The step above proves the generator's *input* builds. This one proves its
      # output does — which is what an author actually receives, shims and all.
      # --dep-path points the generated package at this working tree rather than
      # at the last published tag, so a change to the engine is tested by the
      # thing that will ship with it.
      - name: Generated package (Debug)
        run: |
          bin/new-game Scratch "$RUNNER_TEMP/Scratch" --dep-path "$PWD"
          swift test --package-path "$RUNNER_TEMP/Scratch" --build-system swiftbuild --disable-experimental-prebuilts
          cd "$RUNNER_TEMP/Scratch" && bin/export-game | grep -qx Scratch
```

The final `grep -qx` is the assertion that the shims resolve: `bin/export-game` in a generated package must list that package's product, which it can only do by finding the engine and standing in the game.

- [ ] **Step 2: Verify the CI step's commands locally**

```bash
rm -rf /tmp/Scratch
bin/new-game Scratch /tmp/Scratch --dep-path "$PWD"
swift test --package-path /tmp/Scratch
( cd /tmp/Scratch && bin/export-game | grep -qx Scratch ) && echo "shims resolve"
rm -rf /tmp/Scratch
```

Expected: 4 tests pass, then `shims resolve`.

- [ ] **Step 3: Fix `README.md:38`**

The sentence currently ends `to skip the setup, copy the ready-to-run package in [\`Templates/NewGame\`](Templates/NewGame).` Replace that clause with:

```
to skip the setup, run `bin/new-game Zwank ~/dev/Zwank` and start writing rooms.
```

- [ ] **Step 4: Fix `GettingStarted.md:9` and `:204`**

Line 9 currently reads: `Prefer to start from something that already runs? The repo ships a complete starter package at \`Templates/NewGame\` — copy it out, rename it, and skim this guide for the *why* behind each piece.` Replace with:

```
Prefer to start from something that already runs? `bin/new-game Zwank ~/dev/Zwank` writes a complete starter package named for your game — then skim this guide for the *why* behind each piece.
```

Line 204 currently reads: `- \`Templates/NewGame\` in the repo — the complete starter package this guide builds up to`. Replace with:

```
- `bin/new-game` in the repo — writes the complete starter package this guide builds up to
```

- [ ] **Step 5: Fix `PlayTesting.md:54`, `:64` and `:82`**

Line 54 says the two scripts live only in the Gnusto repository and that the template ships only `bin/gnusto-mcp`. That is now false in the author's favour. Replace it with:

```
A package written by `bin/new-game` has all three: `bin/playtest-replay`, `bin/playtest-measure` and `bin/export-game` are shims over the copies in the Gnusto checkout it depends on, so they are never a version behind the engine they are driving. Run `swift build` once before the first one, since the tools live in a checkout SwiftPM has to have resolved.
```

Line 64 currently reads `\`bin/gnusto-mcp\` is the launcher, and a copy ships in \`Templates/NewGame/bin/\`:`. Replace with:

```
`bin/gnusto-mcp` is the launcher, and a generated package gets a shim over it:
```

Line 82 currently ends `If you copied \`Templates/NewGame\`, both files are already there and renaming the product in \`.mcp.json\` is the only edit.` Replace that sentence with:

```
If you started with `bin/new-game`, both files are already there and already carry your game's name — there is no edit.
```

- [ ] **Step 6: Fix `SharingYourGame.md:31`, `:103` and `:134`**

Line 31 contains `If you started from \`Templates/NewGame\`, this is already wired up.` Replace that sentence with:

```
If you started with `bin/new-game`, this is already wired up.
```

Line 103 contains `— the seven demo games here, or the \`MyGame\` in a fresh \`Templates/NewGame\` copy, with no edits to the script.` Replace that clause with:

```
— the seven demo games here, or the one game in a package `bin/new-game` wrote, with no edits to the script.
```

Line 134 contains `A copy ships with the starter template at \`Templates/NewGame/.github/workflows/release.yml\`: drop the NewGame folder at your repo root and tagging publishes your game unchanged.` Replace that sentence with:

```
A generated package already has it at `.github/workflows/release.yml`, so tagging publishes your game unchanged.
```

- [ ] **Step 7: Fix `.github/workflows/release.yml:9`**

The comment currently reads `# \`Templates/NewGame/.github/workflows/release.yml\` — drop the NewGame folder at`. Point it at the template's new home:

```
# `bin/templates/.github/workflows/release.yml` — bin/new-game copies it into
```

Read the surrounding lines and make the sentence read correctly; do not leave a dangling clause.

- [ ] **Step 8: Fix `.claude/workflows/playtest.js:174`**

The comment currently reads `// \`Templates/NewGame\` ships, but nothing enforces it, and a repo that spells its key`. The lowercase-key convention now has an enforcer. Replace it with:

```
// `bin/new-game` writes, and now enforces — it lowercases the key itself. A repo that spells its key
```

Read the surrounding comment and adjust so the sentence still parses; do not change any code.

- [ ] **Step 9: Update `CLAUDE.md`**

In the layout table, the `Sources/CloakOfDarkness, …` row and its neighbours are unchanged, but the file has no row for the template. Add one, and add the generator to the commands block:

In the Commands section, after the `bin/export-game`-adjacent entries, add:

```sh
bin/new-game Zwank ~/dev/Zwank                 # a new game package, named for itself,
                                               # written from bin/templates. Its bin/ holds
                                               # shims over this repo's tools rather than
                                               # copies, so an author's tooling cannot drift
                                               # from the engine. --dep-path pins the
                                               # dependency to a checkout instead of a tag,
                                               # which is what CI uses
```

In the layout table, add a row:

```
| `bin/templates/` | the starter game the generator reads — a real package, built in CI so it can't rot. Its `bin/` is shims, not copies |
```

- [ ] **Step 10: Confirm nothing still points at the old path**

Run: `grep -rn "Templates/NewGame\|Templates" --exclude-dir=.git --exclude-dir=.build --exclude-dir=superpowers .`

Expected: no hits at all. (`docs/superpowers/` is excluded because the spec and this plan both discuss the old path by name, correctly.)

- [ ] **Step 11: Run everything**

```bash
swift build && swift test
xcrun swift-format lint --strict --parallel --recursive --configuration .swift-format Sources Tests
node .claude/workflows/playtest.dryrun.mjs
```

Expected: suite PASS; lint silent; dry run all assertions passed. The dry run matters because Step 8 edits `playtest.js`.

- [ ] **Step 12: Commit**

```bash
git add -A
git commit -m "$(printf 'CI builds what an author receives, and the prose stops describing a folder (#368)\n\nA second CI step generates a package against the working tree and tests it,\nthen asserts its bin/export-game lists that package own product -- which it\ncan only do by resolving the engine and standing in the game. The step above\nit proves the generator input builds; this one proves its output does.\n\nEight files still told an author to copy Templates/NewGame and rename\nMyGame ten times. They now tell them to run bin/new-game. PlayTesting.md\nregains the positive claim it lost in #367: a generated package has all\nthree tools, and gets them current rather than frozen.\n\nCo-Authored-By: Claude <noreply@anthropic.com>')"
```

---

## Self-Review

**Spec coverage.** Every section of the spec maps to a task: `bin/templates/` as a real package → Task 1; the substitution table → Task 4 Step 4 (one `sed` over `MyGame`/`mygame`, plus four `mv`s, because `MyGameTests` is `MyGame` + `Tests`); `bin/new-game` CLI, refusals and the pinned dependency → Task 4; shims and `gnusto-tooling.sh` → Task 3; the `GNUSTO_PACKAGE_PATH` change → Task 2; the testing list → Task 4 Step 2, one `@Test` per bullet; the CI pair → Tasks 1 and 5; the deletion list → Tasks 1 and 5.

**Two deliberate departures from the spec, both noted to the user before this plan was written.** The spec says `bin/templates/` holds no `bin/` at all; Task 3 puts the five shim files there instead, because a shim is not a duplicate of anything and keeping them as files rather than heredocs makes them reviewable and testable in place. And the spec names two scripts needing the `$0` fix; Task 2 fixes three, because `bin/playtest-replay:259` resolves `bin/lib/playtest-route-prefix.js` against the working directory and would fail obscurely under a shim.

**One spec claim this plan does not implement.** The spec's resolution order ends with `swift package show-dependencies` for the path-dependency case. Task 3 reads the `path:` out of the package's own manifest instead. The manifest line is written by `bin/new-game` and has a known one-line shape, so reading it is exact — and it avoids taking SwiftPM's exclusive `.build` lock, which is the contention `bin/gnusto-mcp:19-27` records as having cost two play-test rounds. Resolution now never calls SwiftPM at all.

**Placeholder scan.** No TBDs. Every code step carries the actual content. The three prose steps that say "read the surrounding lines and make the sentence read correctly" (Task 5 Steps 7 and 8) quote the exact line to replace and its replacement; the instruction is about the neighbouring clause, not about inventing content.

**Type consistency.** `gnusto_die`, `gnusto_is_checkout`, `gnusto_find_repo` and `gnusto_exec` are defined in Task 3 Step 1 and used under those names in Task 3 Step 2. `GNUSTO_PACKAGE_PATH` is produced in Task 2 and consumed in Task 3. `GNUSTO_REPO` is defined and consumed within Task 3, and used by Task 3 Step 7. The marker comment `// gnusto-dependency` is written in Task 4 Step 1 and matched in Task 4 Step 4. `bin/templates/` is created in Task 1 and read in Tasks 3, 4 and 5.

**Three defects found after this plan was written, corrected during execution.** Task 4 Step 4's `grep -q "gnusto-dependency" "$manifest" && die …` inverts under `set -euo pipefail`: when grep finds nothing — the success path — the statement's exit status is 1 and the script dies every time it worked. It must be an `if`. Task 4 Step 4's `cp -a bin/templates/. "$destination/"` copies `bin/templates/.build`, which Task 1 Step 2 creates, before deleting it again; nine generations per test run makes that a serious violation of the sub-second constraint, so the copy excludes `.build` and `Package.resolved` rather than removing them afterwards. And Task 2 Step 5's `node "$(dirname "$0")/lib/…"` is stale by the time it runs, because `bin/playtest-replay:149` has already `cd`'d — a relative `$0` then resolves one directory above the repo. The anchor is captured as an absolute path before that `cd` instead.

**One portability note for the implementer.** Task 4 Step 4 preserves file modes with `chmod --reference` and falls back to `chmod "$(stat -f '%OLp' …)"`. The first is GNU coreutils (Linux, CI); the second is BSD `stat` (macOS). Both are present in the `||` pair deliberately — verify on whichever platform you are on, and check the other in CI rather than assuming.
