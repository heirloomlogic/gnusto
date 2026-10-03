# Yonk, Blorple and Lobal: a Period Front End for Gnusto Games

**Date:** 2026-10-03

**Status:** Original design approved; revised game packaging approved in conversation; revised written spec awaiting review; not started

## Goal

Play a Gnusto game in a Mac app that looks like an Apple ][ plus on a CRT, with a map that draws itself as you play and an optional voice interface. Each game is one library, deployable through either the standard terminal front end or Yonk. Terminal deployments produce executables; Yonk deployments produce `.app` bundles, one per game.

**Audience, now:** the author, playing the demo games. **Audience, later:** players receiving a game as an executable or app, and other Gnusto authors whose `bin/new-game` output can be deployed with either front end. Nothing in this design may close those later doors: front ends consume the same `PackagedGame` interface, and no API key is compiled into a binary. Nothing in this design builds for them either — no App Store, no sandboxing, no notarization.

**Done for the first version:** Zork 1 is playable as `Zork 1.app` in the Apple ][ plus theme.

## The five pieces

| Piece | Where | Depends on | Job |
|---|---|---|---|
| Engine changes | this repo | — | make games importable; report what each turn did; answer what the map may show |
| **GnustoTerminal** | new Swift package and repo | Gnusto | the standard terminal front end and reusable launcher |
| **Yonk** | new repo | Gnusto, Blorple, Lobal | the app front end: CRT screen, themes, sounds, layouts, settings |
| **Blorple** | new repo | nothing in Gnusto | the mapper: knowledge model, grid layout, three drawing styles |
| **Lobal** | new repo | nothing in Gnusto | voice: listening, speaking, interrupting, correcting misheard words |

The names are Infocom spells, like Gnusto ("write a magic spell into a spell book"). Yonk is "augment the power of certain spells" (*Sorcerer*), and Yonk augments Gnusto. Blorple is "explore an object's mystic connections" (*Spellbreaker*). Lobal is "sharpen hearing" (*Balances*). Source: [IFWiki, Spells](https://www.ifwiki.org/Spells). A GitHub search found no clash for Yonk or Lobal; `dfabulich/blorple` is a small tool that reads release numbers from IF story files, and was judged no obstacle.

Blorple and Lobal take plain types of their own rather than Gnusto's, and Yonk translates. That keeps both testable without a game and usable for another story format later.

The app drives `GameWorld` in-process. Two alternatives were rejected: running each game's executable as a child process over the MCP play-test server (that server is a testing tool, is compiled out of release builds by design, and would put two binaries in every app), and putting either behind a `GameHost` protocol (abstraction for one implementation).

Both front ends are reusable libraries. Deployment generates an executable entry point and a build package for the selected game and front end; those generated files are build artifacts, not maintained targets in either repo. Gnusto and the game libraries do not depend on either front end, so no dependency cycle is introduced. A deployment links only the selected game, rather than a registry of every demo. There is no runtime loading of arbitrary Swift game libraries.

## 1. Engine, terminal and game builds

### 1.1 Games become importable

Each of the seven demo games becomes a library target and library product, with no maintained executable target or executable product. `bin/new-game` and `bin/templates/` produce the same library-only structure. Each library exports one value:

```swift
import Gnusto

public let game = PackagedGame { Zork1() }
```

The game type stays internal, so authors do not have to make every `Game` protocol witness public. `PackagedGame` is a presentation-independent, `Sendable` game factory: it provides `init<G: Game>(_ make: @escaping @Sendable () -> G)`, `title`, and `makeGame() -> any Game`. Each factory call creates a fresh game. It has no terminal-specific `main()`; neither game libraries nor engine declarations contain executable entry points. `GameMain` is retired when the terminal launcher replaces it, with no compatibility alias or alternative legacy structure.

`swift run Zork1` is replaced by the script-based development flow in 1.6. Tests continue to import their game libraries. The MCP, replay, preflight, generated-game and release workflows are migrated to the generated build packages; preserving old executable products is no longer a constraint.

### 1.2 A per-turn report

`TurnResult` gains a public `report`, built from what the internal `TurnAudit` already records:

- `understood: Bool` and `unknownWords: [String]`;
- `movement`, present when the player's location changed during the turn:
  - `.walked(from:to:direction:)` — the turn was a move with a direction (including entering through a door by name);
  - `.teleported(from:to:)` — the location changed with no direction: `arrive(at:)`, death and respawn, a `pray`;
  - `.relocated(to:)` — UNDO, RESTORE or RESTART put the player somewhere. The map updates the current room and draws nothing.

Room identities are `EntityID`s, never display names, for the reason `StatusLine.locationID` gives.

### 1.3 Two read-only queries

Both are methods on `GameWorld` rather than fields of the report, so a front end that never asks pays nothing. Both evaluate in a throwaway frame and discard it, as `statusFields()` does.

- **`vocabulary()`** — every word the parser accepts right now, split by kind: verbs, nouns and adjectives in scope, directions, prepositions, articles and filler, and the engine-level words (`undo`, `again`, `save`, …). This is a superset of `CompletionCandidates`; Lobal needs the prepositions and articles that Tab completion leaves out.
- **`mapView()`** — what a map may show of the current room: its `EntityID`, its name, its `mapRegion` label if any, and its exits by direction, each one of:
  - `.open` — a plain exit, or a door that is not hidden;
  - `.blocked` — a `blocked:` exit;
  - `.unknownDestination` — a `dynamicExit`;
  - each carrying `isSecret` when declared `.secret`.

  Exits are left out when: the exit goes through a door that is `hidden` and not yet revealed; the exit is conditional and its condition is false right now. Destinations are never included — a map knows an exit exists, not where it goes, until the player walks it. In a dark room the answer has no exits and no name beyond what the status line shows.

### 1.4 Two author hints

Most games need neither. Hidden doors and conditional exits are already filtered by 1.3.

**`mapRegion(_:)`, a `Location` trait.** Rooms sharing a label draw as one shape with that label. Zork 1's fifteen maze rooms and four dead ends each gain `mapRegion("Maze")`:

```swift
let maze1 = Location {
    name("Maze")
    description(Prose.maze)
    dark
    mapRegion("Maze")
}
```

**`.secret`, a modifier on a map entry.** The exit is not drawn, not even as a stub, until the player has gone through it:

```swift
var map: WorldMap {
    behindFalls.west(hiddenCave).secret    // drawn only after the player has gone west here
    hiddenCave.east(behindFalls)           // ordinary: by now they have walked through to here
}
```

The engine keeps no record of which secret exits were used. It reports `isSecret`; Blorple, which owns map knowledge, decides when to draw.

### 1.5 The standard terminal front end

`GnustoTerminal` is one reusable Swift package, parallel to Yonk. Terminal presentation, interactive input handling and process launch behavior move out of the engine into this package. It accepts a `PackagedGame`, creates a `GameWorld`, and drives the terminal session. Shared engine and front-end contracts remain in Gnusto; Gnusto never imports GnustoTerminal. Yonk continues to drive `GameWorld` directly, without launching a terminal process.

The terminal front end preserves the existing interactive display, command history and completion, plain input/output for pipes or `GNUSTO_PLAIN`, status output, seeded runs, transcript recording, startup diagnostics and exit behavior. Development launchers also preserve the MCP mode. The terminal package provides the reusable launch function; only the generated executable calls it.

### 1.6 Generated builds, running and deployment

The scripts discover game library products through an explicit game export convention, rather than treating every library product as a game. The convention identifies the package, product, module and exported `PackagedGame` value, and applies to both the seven demos and independently generated author packages. Its manifest representation is defined in the implementation plan.

```sh
bin/run-game Zork1                         # build and run the terminal development executable
bin/run-game Zork1 --frontend yonk         # build and launch the development app
bin/export-game Zork1                      # deploy dist/Zork1
bin/export-game Zork1 --frontend yonk      # deploy dist/Zork 1.app
```

Terminal is the default front end. Each invocation generates or reuses an ignored build package containing one executable target, its small entry point, the selected game dependency and the selected front-end dependency. It builds against the current game sources during development. No permanent per-game executable targets are added to Gnusto, GnustoTerminal or Yonk. The entry point differs by front end, but the game library does not. Until Yonk is available, selecting it reports a clear unavailable-front-end error.

Development and MCP builds enable the `Playtest` trait; deployed terminal executables and apps disable it through every dependency that forwards it. Their caches and scratch paths are separate, so a deployment cannot replace an MCP-enabled development binary. MCP startup continues to write build diagnostics only to standard error, reuse current builds, and support preflight before clients connect. Replay, preflight, CI and release workflows use the same generated build flow instead of assuming root executable products.

The scripts report an unknown game, missing front-end dependency, failed build or failed packaging step with a nonzero exit status. A failed export preserves the previous successful deployment. Deployment stages any required SwiftPM resource bundles so the result works outside the build directory; the terminal distribution is a single executable when its dependencies require no external resources. Generated manifests, wrappers and dependency state are cached as ignored build artifacts, not committed source.

### 1.7 Migration validation

- Import and test every demo as a library; confirm the root manifest has no per-game executable products or targets.
- Build and run generated terminal launchers for all seven demos, checking startup and a short scripted session; verify interactive terminal input, history and completion separately in a live terminal.
- Generate an independent game with `bin/new-game`, then build, test, run, export and preflight it through the same scripts.
- Exercise MCP initialization and replay through generated development launchers; export the same game and confirm its development launcher still serves MCP while the deployed binary refuses MCP mode.
- Run exports from outside the package and build directories, including a resource-bearing fixture, and verify a failed export leaves the prior deployment usable.
- Run the engine tests, terminal-package tests, strict lint, play-test workflow dry run and DocC checks in their owning packages. Milestone 2 adds launch and play checks for generated Yonk apps, including packaged resources.

## 2. Yonk, the app

### 2.1 Repository and packaging

The Yonk repo contains `Yonk`, the reusable library: screen, themes, sounds, layouts, settings, and the session that drives a game. It contains no maintained `Apps/Zork1`, `Apps/Dungeon` or other per-game executable targets. The deployment script generates a wrapper for the selected game, equivalent to:

```swift
import SwiftUI
import Yonk
import Zork1

@main struct Zork1App: App {
    var body: some Scene { Yonk(Zork1.game) }
}
```

The scene type shares the module's name. The one cost is that `Yonk.Theme` cannot be written to disambiguate a name another import also declares; rename around it if that ever happens.

The generated package depends on Yonk and the selected game library. This is the only place those dependencies are combined; the engine and games remain independent of Yonk.

**`bin/export-game <Game> --frontend yonk`** builds the generated executable with SwiftPM and wraps it as `<Title>.app`: Info.plist (bundle identifier, display name, the microphone and speech-recognition usage strings macOS requires before an app may listen), icon, resources, and an ad-hoc signature for local use. The same packaging logic serves `bin/run-game <Game> --frontend yonk` for local development. No Xcode project or separate user-facing `bin/yonk-bundle` command. Metal shader source is compiled at launch with `makeLibrary(source:)`, because `swift build` does not compile `.metal` files.

### 2.2 How a turn flows

A main-actor `GameSession` owns the `GameWorld`. On Return, or when Lobal hands over a command:

1. `await world.perform(line)` returns the output and the report.
2. The output joins the transcript, is wrapped to the current column count, and is drawn at the theme's speed.
3. Yonk translates the report and `mapView()` into a Blorple arrival, and passes the output and `vocabulary()` to Lobal.

### 2.3 Screen behavior

- A status bar in inverse video on the top row: room, score, moves.
- Scrollback with the trackpad; new output returns the view to the bottom.
- A command line with history (↑/↓) and Tab completion from `vocabulary()`.
- At the end of the game the final text stays on screen with Restart and Quit.

### 2.4 Layouts

| Key | Layout |
|---|---|
| ⌘1 | One screen, two pages. Tab flips between the text page and a full-screen map page. |
| ⌘2 | Split. The map shares the screen with the text, behind a draggable divider. |
| ⌘3 | Second monitor. The map is its own window, drawn by the same pipeline. Leaving ⌘3 closes it. |

The last layout used is remembered per game.

### 2.5 Drawing

One Metal view per screen. Each frame:

1. **Text.** The screen is a grid of character cells. Glyphs come from a font atlas: a bitmap font scaled in whole-pixel steps so it stays crisp, or any monospace font rendered at the display's resolution. The status bar and cursor are inverse cells.
2. **Map.** In the 1979 style the map is characters on the same grid. In 1989 and 1999 it is an image Blorple draws with Core Graphics, redrawn only when the map changes.
3. **Glass.** One post-processing pass, in order: phosphor colour, glow, persistence (old frames fade slowly, so scrolling text leaves a brief trail), scanlines (barely perceptible by default), slight curvature at the corners, and a darkened edge. The warm-up when the window opens (a dot grows into the picture) and the collapse when it closes are the same pass with brightness and scale animated. Warm-up and collapse are always on; they are not a theme setting.

The glass runs to the window's edges, with no drawn monitor housing; the theme's margins keep text well clear of the curved corners.

The view redraws only while something changes — text drawing, the cursor blinking, a fade completing — and is idle otherwise.

SwiftUI's built-in shader effects over ordinary text views were considered and rejected: they cannot carry state between frames, so there is no persistence and no proper glow, which are most of the look.

### 2.6 Resizing

- The theme sets the default window size (`.defaultSize`; when the theme changes, the open window is resized through its `NSWindow`). macOS restores whatever size the user left, so the theme's size only applies to a first opening.
- The theme's column count is a target. **Widening the window grows the text** so the column count holds; a taller window gets more rows.
- **⌘+ and ⌘− change the text size**, and lines rewrap to the columns that now fit. ⌘0 returns to the theme's count. Text already on screen rewraps too.
- Bitmap fonts grow in whole-pixel steps; between steps the margins take the slack.
- The theme sets a minimum and maximum text size. Past either, extra space becomes margin.
- In ⌘2, the map sits above the text in a tall or square window and moves beside it once the window is wider than about 16:10. The divider drags in either arrangement.
- In ⌘1 and ⌘3 the map scales to fit until room names would be smaller than the text, then stops shrinking and scrolls, keeping the current room centred.

### 2.7 Themes

A theme is a JSON file. Built-in themes are read-only; Duplicate makes an editable copy. User themes live in `~/Library/Application Support/Yonk/Themes/`. Settings lists the themes and has an editor whose changes appear on the game screen as they are made.

A theme holds:

- name;
- font, column count, case rule (upper only, or as written), margins, minimum and maximum text size, default window size;
- colours: phosphor, background, status bar;
- glass: curvature, scanline strength, glow, persistence, noise;
- text drawing speed — by default almost instant, slow enough to see the screen draw for a split second; any key finishes it at once;
- sounds, each with on/off and volume: key clicks while typing, a disk drive at startup and on SAVE/RESTORE, the Apple ][ beep when the game does not understand a command;
- map style: `1979`, `1989` or `1999`;
- the speaking voice.

Built-in themes:

| Theme | Columns | Case | Colour | Map style |
|---|---|---|---|---|
| Apple ][ plus | 40 | upper only | green | 1979 |
| 80-Column Card | 80 | mixed | green | 1989 |
| Amber | 80 | mixed | amber | 1989 |
| Monitor /// | 80 | mixed | white | 1999 |

### 2.8 What is stored

In `~/Library/Application Support/<Game>/`: saved games (the engine's own SAVE/RESTORE, through `GameWorld`'s `saveDirectory`), the Blorple map, and the last layout and theme. Map knowledge is never rolled back: after UNDO or RESTORE the player still remembers the rooms they saw, and so does the map.

## 3. Blorple, the mapper

### 3.1 Input

```swift
Blorple.Arrival(
    room: .init(id: "kitchen", name: "Kitchen", region: nil,
                exits: [.north: .open, .west: .open, .up: .open, .east: .blocked]),
    from: "behindHouse", direction: .west)   // from and direction are nil for a teleport
```

Plus `Blorple.Relocation(to:)` for UNDO/RESTORE/RESTART. Directions are Blorple's own: the eight compass points, up, down, in, out.

### 3.2 Line rules

Walking from room 1 to room 2 going south:

| Situation | Drawn as |
|---|---|
| Room 2's only exit is north | one solid line; that exit has to be the way back |
| Room 2 has a north exit and others | a solid line, plus a **dotted** line from room 2's north exit back to room 1 |
| Later, north from room 2 arrives in room 1 | the dotted line becomes solid |
| Later, north from room 2 arrives somewhere else | the dotted line is removed; room 1 → room 2 gains an arrowhead (one way) |
| Room 2 has no north exit | an arrowhead from the start |
| An exit not yet taken | a short stub |
| A `blocked` exit | a stub ending in a bar |
| An `unknownDestination` exit | a stub marked `?`; once walked, a line to where it led |
| A secret exit | nothing, until walked; then as any other line |
| Up, down, in, out | the line is labelled ↑, ↓, in, out |

Inside a `mapRegion`, moves draw nothing and no stubs are drawn. A line leaving the region is drawn from the region's shape once walked.

### 3.3 Layout

Rooms sit on whole grid squares; each compass direction is one step (north is up, northeast is up and right). Layout is fully automatic: there is no dragging and no author layout hint.

- A placed room never moves, so the map does not jump during play.
- A room whose square is taken goes to the nearest free square, and its line bends to reach it.
- Up, down, in and out place the new room on any free neighbouring square.
- A teleport starts an island beside the main map.
- A `mapRegion` is one shape on one square.
- **Map ▸ Tidy** recomputes the whole layout from scratch, still automatically, for a map a long game has left untidy.

The layout's hard cases — collisions, loops that do not close, non-compass exits — are this project's highest risk, and are tested against the two most tangled maps in the repo, Zork 1 and Dungeon.

### 3.4 Output

A drawing model: rooms with grid positions and labels, lines with styles and labels, the current room marked. Blorple renders it in all three styles itself — 1979 as a character grid, 1989 (thin hard-edged lines, small capitals) and 1999 (smooth right-angled lines, names as written) with Core Graphics using a bundled font, never a system one. Yonk only places the result. The knowledge model is `Codable`, so Yonk can persist it.

### 3.5 Testing

- Feed recorded routes through Zork 1 and Dungeon — the walkthroughs and the committed deep-start routes — as arrival sequences.
- Snapshot every drawing style after each step:
  - the drawing model as structured text (exact, OS-independent; most regressions show here first);
  - 1979 as plain text (exact);
  - 1989 and 1999 as PNG with a small tolerance, using `swift-snapshot-testing`, because Core Graphics text can move a pixel between macOS versions.
- Check invariants on every frame: no two rooms on one square, no line through a room, every placed room where it was.

## 4. Lobal, voice

### 4.1 Interface

After each turn Yonk gives Lobal the text to speak and the vocabulary. Lobal gives back a command line, which Yonk submits exactly as if typed and shows on screen as a typed command (`>TAKE THE LANTERN`), so the player always sees what the game received.

### 4.2 Providers

Two protocols, `Listener` and `Speaker`, with two implementations each. The provider is a setting.

- **Apple, built first:** `SpeechAnalyzer` (macOS 26) with the vocabulary as context; `AVSpeechSynthesizer`. Free, offline, no key.
- **Google:** Cloud Speech-to-Text streaming with the vocabulary as a boosted phrase set; Cloud Text-to-Speech with Chirp voices. The API key is entered in Settings and kept in the Keychain.

### 4.3 Turn-taking

```
voice off → listening → heard (about 0.8 s of silence) → correcting → submitted → speaking → listening
                                                                                    ↑ the player starts talking: speech stops, back to listening
```

- A shortcut toggles voice mode.
- While the game speaks, the microphone stays open with macOS voice processing (`AVAudioEngine` input with voice processing enabled), so it hears the player and not the game.
- Speech longer than about 150 ms interrupts the game; a cough or click does not.
- The whole turn output is read, never the status bar, never the echoed command.
- Two phrases never reach the game: "say that again" repeats the last reply; "stop listening" turns voice mode off.

### 4.4 Correction

Every heard word the parser does not accept is compared against the vocabulary by sound (phonetic codes) and by spelling (edit distance). Adjacent unknown words are also tried as one word ("land turn" → `lantern`). The recognizer's alternative transcriptions add candidates.

- **One clear winner** (score above a threshold and well ahead of the second): the corrected command runs.
- **Unsure, or a tie:** Lobal asks, aloud and on screen in a dimmer style that is plainly not the game — "The lantern or the lamp?" — and accepts "lantern", "yes", or "no, never mind".

A wrong silent guess costs one turn, and UNDO is there.

### 4.5 Testing

- Correction is a pure function: a table of (heard text, vocabulary) → expected command or question.
- The table is filled from real mistakes: Apple's voice speaks every walkthrough command into Apple's recognizer, and every misrecognized word is logged.
- Turn-taking is tested with a fake `Listener` and `Speaker`.
- Echo cancellation and interrupting need a person at a microphone, and get a short manual checklist.

## 5. Build order

Each milestone ends in something usable, and each gets its own implementation plan.

1. **Gnusto and GnustoTerminal:** library-only games and the shared `PackagedGame` factory (1.1), the terminal package (1.5), generated terminal builds and deployment with migrated development/MCP/release workflows (1.6), the report (1.2), `vocabulary()` and `mapView()` (1.3), `mapRegion` and `.secret` (1.4), Zork 1's maze annotated. The terminal migration ends with playable exports and working play-test tools.
2. **Yonk, first light:** `Zork 1.app` in the Apple ][ plus theme — cell grid, glass, status bar, command line, scrollback, resizing, generated Yonk launchers and the Yonk front-end option in the shared run/export scripts.
3. **Yonk, themes:** JSON themes, the four built-ins, the editor, text drawing speed, sounds, warm-up and collapse.
4. **Blorple:** model, layout, three styles, snapshot tests; Yonk's ⌘1/⌘2/⌘3.
5. **Lobal, Apple:** providers, turn-taking, correction, interrupting; Yonk's voice mode.
6. **Lobal, Google.**

## Open before shipping

- **Fonts.** The closest Apple ][ lookalikes are Kreative Software's *Print Char 21* and *PR Number 3*. Their licence must be checked before they are bundled.
- **Sounds.** The beep is generated (a short square-wave tone). Key clicks and the disk drive need recordings with a licence that permits bundling.

## Not in this design

- S.A.M. (Software Automatic Mouth, 1982) as the faithful theme's voice. Open-source ports exist; their licensing is unclear.
- A "disk box" launcher app holding several games.
- Author layout hints for the map, and dragging rooms by hand.
- App Store distribution, sandboxing, notarization.
