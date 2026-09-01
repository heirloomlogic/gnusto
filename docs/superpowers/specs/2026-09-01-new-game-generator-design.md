# A Generator, Not a Folder: Scaffolding a New Game From the Live Repo

**Date:** 2026-09-01

**Status:** Approved in discussion; spec pending review

**Issue:** #368, scope item 2 (supersedes PR #381)

## Problem

`Templates/NewGame/` is a checked-in copy of a game package. An author starts a game by copying the directory and then hand-editing it: swap the path dependency for a git URL, and rename `MyGame` across the package name, two target names, two directory names, a filename, a struct, a test struct, and both halves of the `.mcp.json` entry. `Templates/NewGame/README.md:6-33` is that checklist, written out for a human to execute.

The tooling half is worse. `bin/gnusto-mcp` ships in the template as a byte copy; `bin/playtest-replay`, `bin/playtest-measure` and `bin/export-game` do not ship at all, which is the broken promise `README.md:142-143` and `SharingYourGame.md:7` make to an adopter. PR #381 answered that by copying all four into the template and adding a drift test to hold them byte-identical — four checked-in duplicates guarded by a test, which is the wrong shape. This spec replaces it.

Copying is also a one-way door. A copied script is pinned to the day it was copied and rots silently as the engine moves. The obvious repair — a `bin/new-game --update` — cannot work: an author who took Gnusto as a git dependency has no clone of this repository to run it *from*. Whatever fixes staleness has to work from inside the author's own package.

## Design

Three pieces: the template becomes a generator's input, the generator writes a named package, and the generated package reaches this repository's tooling through shims rather than copies.

### `bin/templates/` — the input is still a real package

`Templates/NewGame/` moves to `bin/templates/` with its contents unchanged. The files keep saying `MyGame` literally rather than adopting a `__GAME__` placeholder, and that is deliberate: the literal keeps the tree a buildable, formattable, testable Swift package. `../..` from `bin/templates/` is the repository root exactly as it was from `Templates/NewGame/`, so the path dependency at `Package.swift:15` keeps working and CI can go on building the template in place.

Substitution is therefore a rename of one known string across a small, curated tree rather than a template language. The sites, exhaustively:

| Site | Form |
|---|---|
| `Package.swift:6` | `name: "MyGame"` |
| `Package.swift:19` | `.executableTarget(name: "MyGame")` |
| `Package.swift:25,27` | `.testTarget(name: "MyGameTests")` and its dependency |
| `Sources/MyGame/` | directory |
| `Sources/MyGame/MyGame.swift` | filename, and `struct MyGame: Game` |
| `Sources/MyGame/Entry.swift` | `extension MyGame` and its doc comment |
| `Tests/MyGameTests/` | directory |
| `Tests/MyGameTests/MyGameTests.swift` | `@testable import`, `struct MyGameTests`, four `MyGame()` calls |
| `.mcp.json:3` | the lowercased server key **and** the product argument |
| `README.md` | prose at `:11,17,18,19,32,45` |

`.github/workflows/release.yml` needs no substitution at all: it discovers products from `swift package describe` (`:48,102`) and its only knob is `EXCLUDE_PRODUCTS`.

One file does *not* move across unchanged: `Templates/NewGame/bin/gnusto-mcp`. The implementation ships `bin/templates/bin/` — the five shim files themselves, `bin/new-game` copies rather than generates — which is better than the plan above: a shim is not a duplicate of anything, so keeping the five as real, reviewable, lintable files beats reconstructing them from heredocs at generation time. `bin/templates/Package.swift` path-depends on the repository root, so `bin/templates/` is itself playable and play-testable in place, same as any generated package.

### `bin/new-game` — bash, house style

```
bin/new-game <GameName> <destination-dir> [--dep-path <path>]
bin/new-game Zwank ~/dev/Zwank
```

Written to the conventions the rest of `bin/` follows: `#!/usr/bin/env bash`, `set -euo pipefail`, a `# Usage:` comment block, exit 2 on a usage error with the reason stated, and bash-3.2 compatibility.

It refuses a destination that exists and is non-empty, and refuses a `GameName` that is not a valid Swift identifier — both with the reason, not a stack trace. Then it copies `bin/templates/`, applies the renames above, rewrites the dependency, and writes `bin/` (next section).

**The dependency line.** By default the generated `Package.swift` takes a git URL pinned to this repository's latest tag, read at generation time via `git describe --tags --abbrev=0` — today `from: "0.4.0"`. The tags are real: 0.1.0 through 0.4.0 are published releases, so this resolves. `--dep-path <path>` overrides it with a path dependency instead, which is what CI uses to test the working tree.

### `bin/` in a generated game — shims, not copies

The generated package gets five committed files and no copy of any tool:

- `bin/lib/gnusto-tooling.sh` — locates Gnusto's `bin/` directory, preferring `.build/checkouts/Gnusto` and falling back to the resolved path dependency via `swift package show-dependencies`. When it finds neither, it exits with a sentence telling the author to run `swift build` first, rather than an ENOENT.
- `bin/gnusto-mcp`, `bin/playtest-replay`, `bin/playtest-measure`, `bin/export-game` — four lines each: source the library, exec the real tool.

Nothing here goes stale. `swift package update` moves the engine and its tooling together, and they cannot disagree, because there is only one copy of each script and it lives in the checkout. That is the whole benefit of symlinking into `.build/checkouts/` without either of its two failure modes: a shim does not dangle on a fresh clone before `swift package resolve` has run, and it works under a path dependency, which produces no checkout at all.

`.mcp.json` still names `bin/gnusto-mcp`, so nothing downstream of that path changes.

**One change in this repository, two files.** `bin/export-game:17` and `bin/gnusto-mcp` both derive the package root from `$0`:

```bash
cd "$(dirname "$0")/.."
```

Under a shim's `exec`, `$0` is the script inside the Gnusto checkout, so that line would land in the *engine's* root instead of the author's package. Each becomes:

```bash
cd "${GNUSTO_PACKAGE_PATH:-$(dirname "$0")/..}"
```

with the shim setting `GNUSTO_PACKAGE_PATH` to the author's package root. In this repository the variable is unset and behaviour is unchanged. `bin/playtest-replay` needs nothing — it already defaults `--package-path` to `$PWD`.

`bin/playtest-routes` is still not shipped, for the reason recorded on #368: it needs `bin/lib/playtest-focus.js`, which hardcodes `docs/games` and `Tests`. A generated package therefore cannot honour `bin/playtest-replay --start`, and that flag already refuses in a sentence rather than a node stack trace.

## Testing

`Tests/GnustoTests/NewGameTests.swift` generates into a temporary directory and asserts the properties a human would otherwise check by eye:

- no occurrence of `MyGame`, `mygame` or `MyGameTests` survives anywhere in the generated tree, including in filenames and directory names
- the four shims exist and carry the executable bit, and `bin/lib/gnusto-tooling.sh` exists (it is sourced, so it needs no executable bit)
- the `.mcp.json` key is the lowercased game name and its argument is the product name
- the dependency line is the pinned git URL by default, and a path dependency under `--dep-path`
- a non-empty destination and an invalid `GameName` each exit 2

Building the generated package is CI's job, not the unit suite's — the suite is sub-second and stays that way.

## CI

`.github/workflows/test.yml:127-130` builds `Templates/NewGame` as a standalone package. Two steps replace it:

1. `swift test --package-path bin/templates` — the same check as today, keeping the template from rotting, and cheap.
2. `bin/new-game Scratch <tmp> --dep-path <repo>` followed by `swift test --package-path <tmp>` — this is the step that tests the generator and the shims, which is what actually ships to an author.

Both keep the existing `--build-system swiftbuild --disable-experimental-prebuilts` flags, for the reason recorded in that workflow.

## Deletions

`Templates/NewGame/` is removed outright. Its references go with it: `README.md:38`, `GettingStarted.md:9,204`, `PlayTesting.md:54,64,82`, `SharingYourGame.md:31,103,134`, `.github/workflows/release.yml:9`, `bin/export-game:20`, `.gitignore:25`, and `.claude/workflows/playtest.js:169-175` — the last of which cites the template as the source of the lowercased `.mcp.json` key convention. That convention now lives in `bin/new-game`, and the comment should say so.

`SharingYourGame.md` and `PlayTesting.md` gain the positive claim the scripts now justify: an author has `export-game`, `playtest-replay` and `playtest-measure`, and gets them current rather than frozen.

PR #381 is closed rather than merged. It ships the duplication this design removes.

## Out of scope

Issue #368 items 1, 3, 4, 5 and 6 — the Claude Code plugin and its marketplace manifest, unbinding `playtest.js` and `bin/playtest-preflight`, the downstream skill, and the author-facing article. The delivery vehicle is settled (a Claude Code plugin with a marketplace manifest), but the rest is its own spec. #368 stays open.
