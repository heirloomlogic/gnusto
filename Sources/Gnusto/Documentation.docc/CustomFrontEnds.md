# Custom Front Ends

Putting the engine behind something that is not a terminal.

## Overview

![Interchangeable theater frames present one shared scene of a lantern-lit doorway.](custom-front-ends.png)

``GameWorld`` is an actor whose public play surface knows nothing about terminals. Everything a player sees comes back as a ``TurnResult``: a string, a ``StatusLine``, a flag saying whether the game is over, and a ``TurnReport`` describing what caused the result. The terminal front end is a client of that surface, not a privileged part of the engine, and an iOS app uses the same API.

Which way in to take depends on whether your front end can afford to block.

**Implement ``IOHandler`` and let ``REPL`` drive.** The REPL owns the loop — prompt, parse, perform, print — and calls your handler for each half. This is the shape for anything that reads a line at a time: a different terminal, a pipe, a serial console, a test harness.

**Or call the actor directly.** ``IOHandler/readLine(prompt:)`` is synchronous and blocking by design, which is fine for a console and wrong for a UI event loop. An event-driven front end skips the protocol and drives the world itself:

```swift
let world = try GameWorld(game: MyGame())

var turn = await world.begin()
show(turn.output, status: turn.status)

// Later, when the player submits a line from a text field:
turn = await world.perform(line)
show(turn.output, status: turn.status)
updateInput(for: await world.inputContext)
if turn.isFinished { showEnding(turn.output) }
```

Round-trip questions — "Which do you mean, the brass lantern or the brass hook?", a save filename, the RESTART / RESTORE / UNDO / QUIT prompt after a death — are pending state on the actor, so the next line you hand `perform` answers whichever one is open. A front end that only reads lines can ignore that state. One that changes completion, voice, or keyboard behavior reads ``GameWorld/inputContext``.

## Input context and cancellation

``InputContext`` says what the next submitted line means. ``InputContext/command`` is ordinary parser input; ``InputContext/clarification`` is an answer the parser will splice into an ambiguous command; the save filename, overwrite confirmation, restore filename, and post-death choice cases identify the engine's other prompts. The query is read-only: it does not walk a turn, mutate scratch or live state, or consume randomness.

Escape or Ctrl-C can cancel an open save or restore operation through ``GameWorld/cancelPendingInput()``. The method returns a free ``TurnResult`` when a save filename, overwrite confirmation, or restore filename is open, and `nil` for command input, parser clarification, or the post-death choice. Cancellation does not parse control input as a filename, read or write a file, spend a turn, tick a timer, change the random stream or undo snapshot, or end the session. Cancelling a restore selected after death returns to the post-death choice and includes that prompt in the output.

A front end owns its quit confirmation. Escape dismisses that confirmation in the front end; once the player confirms, call ``GameWorld/requestQuit()``. A confirmed quit reports an open SAVE or RESTORE operation as cancelled before ending the session. Do not route quit confirmation through `cancelPendingInput()` or submit the string `quit` on the front end's behalf.

## Starting an importable game

A game library can export a ``PackagedGame`` without exposing its concrete game type. The factory stores a `Sendable` closure, constructs a fresh game for each ``PackagedGame/makeGame()`` call, and offers ``PackagedGame/title`` for a chooser or window title. It does not launch a front end or retain a mutable world.

```swift
public let game = PackagedGame { MyGame() }

let prepared = try PreparedGame(game.makeGame())
let world = GameWorld(prepared: prepared)
```

``PreparedGame/title`` and ``PreparedGame/warningReport`` expose the display title and non-fatal bootstrap diagnostics without exposing the engine's definition or initial state. Prepare once to share the immutable bootstrap result across independent sessions. ``GameWorld/init(prepared:saveDirectory:)`` chooses a fresh random seed; ``GameWorld/init(prepared:seed:saveDirectory:)`` pins one for replay. Both accept an optional saves directory, and ``GameWorld/historyFileURL`` resolves its persistent command-history sidecar for a front end.

Launchers that support the engine's environment settings read ``SeedRequest``, ``StatusFooter`` and ``TranscriptRequest`` before constructing their handler. ``TranscriptRequest/init(gameTitled:environment:)`` takes the prepared game's title, resolves `GNUSTO_TRANSCRIPT`, and preflights the file by opening and closing it. Report its ``TranscriptRequest/complaint`` before an alternate-screen handler starts, then pass ``TranscriptRequest/url`` to the REPL. The request uses the same path rules and recorder as in-session `script` commands.

Gnusto can generate a development launcher for the [Yonk](https://github.com/HeirloomLogic/Yonk) SwiftUI front end on macOS. Set `GNUSTO_YONK_PATH` to the coordinated Yonk checkout, then run `bin/run-game MyGame --frontend yonk`. The ignored package imports the selected game library and constructs `Yonk(MyGame.game)`; the game and engine libraries do not depend on Yonk. `bin/build-game MyGame --frontend yonk` prints the generated executable path without launching it.

The generator records the exact Yonk path, its declared Gnusto revision and a source fingerprint. Its generated dependency overlay points at that source tree while binding Yonk to the same selected engine as the game, including an independent author package that declares Gnusto by path or URL. Terminal and Yonk use separate caches under `.build-launchers/<Game>/<Frontend>/<Mode>/`; edits and deletions in the game, engine or selected front end invalidate the corresponding warm launcher.

Development and export use the same app assembler. `bin/export-game <Game> --frontend yonk` stages an ad-hoc-signed `.app` with linked resource bundles, stable bundle metadata and microphone/speech usage descriptions. See <doc:SharingYourGame> for the supported resource layout, optional ICNS icon, atomic replacement and remaining frontend qualification gates.

An MCP launcher calls ``PlaytestLaunch/serve(_:environment:)`` with the factory and environment. The facade serves the real play-test server when the `Playtest` package trait is enabled, and throws ``PlaytestLaunchError/unavailable`` when it is disabled. Call it before creating a playing world or IO handler: MCP stdout belongs exclusively to the protocol.

## What a handler has to implement

Every ``IOHandler`` requirement except `write(_:)` and `readLine(prompt:)` has a default implementation, so the smallest conformance is those two methods:

```swift
struct PipeHandler: IOHandler {
    func write(_ text: String) {
        print(text, terminator: "")
    }

    func readLine(prompt: String) -> Input? {
        print(prompt, terminator: "")
        return Swift.readLine().map(Input.line)
    }
}
```

That is `ConsoleIOHandler` in full, minus the `<br>` translation below. The other three — ``IOHandler/showStatus(_:)``, ``IOHandler/updateCompletions(_:)`` and ``IOHandler/finish(_:)`` — default to doing nothing, which is the right answer for a handler whose output is a stream rather than a screen. ``IOHandler/wantsCompletions`` defaults to `false` beside them: the candidates cost a scope walk and a read of the save directory after every turn, so the REPL computes them only for a handler that says it will use them, and only `TerminalIOHandler` does.

The protocol is `Sendable`, so a handler that keeps state keeps it behind a lock. ``ScriptedIOHandler`` and `TerminalIOHandler` both box theirs in a `Mutex`.

### Rendering the text you are handed

Game prose is written as multi-line string literals wrapped for source readability. The newlines in them are the author's typing, not the author's layout: a single newline is a soft break that folds to a space, a blank line is a paragraph break, `<br>` is a hard break *inside* a paragraph (a banner's title over its tagline), and an indented line is a form — a sign, an inscription, a scrap of verse — that keeps its own shape.

So `write(_:)` is handed prose, not layout. A handler that does not lay text out itself renders it with `TextWrap.plain(_:)`, which applies all four rules:

```swift
func write(_ text: String) {
    print(TextWrap.plain(text), terminator: "")
}
```

Do not print `text` raw. A raw handler shows `<br>` to the player and breaks every paragraph at whatever column the game's source happened to be typed at.

A handler that *does* reflow — a `UITextView`, a DOM node — wants the paragraph structure rather than the rendered string, and should fold and split on the same four rules before handing text to its own layout. Character-cell renderers can use ``DisplayWidth`` to measure characters and sequences in terminal columns and clip a prefix without splitting a wide glyph. A front end with a real layout engine uses that engine's measurements instead.

``TextWrap/wrap(_:width:)`` renders the same paragraph rules into visual lines at a terminal-column width. ``TesterInput/isComment(_:)`` identifies tester notes before parsing; a line editor can use it to apply the same comment policy as the REPL. Transcript commands remain part of the REPL's internal recording implementation.

For editable input, ``TextWrap/hardSplit(_:width:)`` preserves every character while dividing a line into terminal-width chunks, and ``TextWrap/caretPosition(in:charOffset:width:)`` maps its logical character offset to the corresponding visual caret position.

## `.quit` is not a command

``IOHandler/readLine(prompt:)`` returns an ``Input``, not a `String`. Most of the time it is ``Input/line(_:)``. The other case exists for one reason, stated where it is declared:

> a front-end quit request (e.g. Ctrl-C) that ends the game *without* being parsed as a command — so it can't be swallowed by an open save/restore prompt or clash with a game that has redefined the `quit` verb. The REPL maps `.quit` to `GameWorld.requestQuit()`, which is keyed to `Intent.quit` rather than the editable verb word.

Handing the string `"quit"` back instead would work in most games most of the time, and fail in the two places a player reaches for Ctrl-C: mid-way through a save prompt, where the line becomes the filename, and in a game whose author spelled the verb something else. ``GameWorld/requestQuit()`` abandons any open prompt and ends the game through the same path the verb takes, so the score epilogue prints — unless the game has already ended, in which case that turn already printed it and this exits silently instead.

A front end with no quit gesture — a pipe, a socket — never returns `.quit`, and `nil` (end of input) stops the loop instead.

## The status line

``StatusLine`` is the location name, the score and the move count, handed over after every turn. It also carries the location's ``EntityID``, which is not for display: a display name is prose and two rooms may share one, so anything *recording* where the player has been needs the key the room roster is in. `TerminalIOHandler` paints it as a reverse-video bar; everything else ignores it.

``StatusLine/init(locationID:locationName:score:moves:)`` also lets an external renderer construct an immutable status value without importing engine internals.

``TurnResult/isFinished`` is the flag that stops the loop, and it is *not* the same as "the player is alive". ``GameStatus`` has five cases and only three of them are final:

- `won`, `lost` and `quit` end the session.
- `playing` continues it.
- `dead` is over but not final. The world's time has stopped and the program keeps reading, because the death prompt offers RESTART / RESTORE / UNDO / QUIT and the player has not answered yet.

A front end that dismisses its input field on death loses the game it was about to let the player restore. Read `isFinished`, not the status.

## What a turn did

``TurnResult/report`` says what caused a result and what happened besides printing. ``TurnReport/input`` distinguishes initialization, parsed commands, parser rejection, clarification requests and answers, engine-prompt answers, cancellation, and a confirmed front-end quit. ``TurnReport/understood`` and ``TurnReport/unknownWords`` remain the parser facts: `understood` is false for every result that did not produce a command, including prompt answers and cancellation, so it is too broad to select an unknown-command sound by itself. Use ``TurnReport/InputEvent/parserRejection`` for that decision.

``TurnReport/operation`` is present only when SAVE or RESTORE changes stage. Its kind is save or restore, and its outcome has exact semantics:

| Outcome | Meaning |
|---|---|
| ``TurnReport/OperationEvent/Outcome/requested`` | The engine opened that operation's filename prompt. Choosing RESTORE from the post-death prompt also produces this event. |
| ``TurnReport/OperationEvent/Outcome/completed`` | SAVE wrote the file, or RESTORE validated the file and installed its state. |
| ``TurnReport/OperationEvent/Outcome/failed`` | A name, path, file read, file write, format, game identity, or state validation failed. |
| ``TurnReport/OperationEvent/Outcome/cancelled`` | The operation ended without reading, writing, or replacing state. This includes a blank filename, a declined overwrite, `cancelPendingInput()`, and a confirmed front-end quit that abandons an open operation. |

The filename answer that opens an overwrite confirmation has no second `requested` event: the SAVE command already reported the request, and the later confirmation reports only completion or cancellation. A front end can therefore react once to each stage without matching prose or reporting a successful disk operation from the verb alone.

``TurnReport/movement`` says whether the player moved, and how: ``TurnReport/Movement/walked(from:to:direction:)`` through an exit, ``TurnReport/Movement/teleported(from:to:)`` when the game put them somewhere, and ``TurnReport/Movement/relocated(to:)`` when UNDO, RESTART or RESTORE replaced the world. Rooms are named by their ``EntityID``, never by display name, for the reason ``StatusLine/locationID`` gives.

A map also needs to know what to draw around the room the player is in. ``GameWorld/mapView()`` returns a ``RoomMapView``: the room's ID and name, its ``mapRegion(_:)`` label, and the exits a map may show, each a ``MapExit``. It never says where an exit leads; a map learns that from ``TurnReport/movement`` when the player walks it. ``RoomMapView/exitObservation`` is ``RoomMapView/ExitObservation/complete`` when the exit dictionary is authoritative for what the player can currently observe. An empty complete dictionary removes unwalked stubs, but it does not claim the game's authored topology has no hidden or currently unavailable exits. ``RoomMapView/ExitObservation/unobserved`` means the exits could not be observed, as in darkness, so a map keeps what it learned on earlier visits. The dictionary is empty in that case. A hidden door remains omitted until it is revealed, and a conditional exit remains omitted while its condition is false. An exit declared ``MapEntry/secret`` is flagged so a map can leave it undrawn until the player has walked it.

A tool that lays out the whole map ahead of play needs every room at once, which `mapView()` will not give. ``PreparedGame/declaredMap`` returns a ``DeclaredMap``: every declared room with its ID, name and region, and every exit with its direction, kind, declared destination, door and ``MapEntry/secret`` flag. It is read from the declarations and calls no exit condition or dynamic destination, so a dynamic exit has no destination in it. It lists exits as declared, whatever the world's state: a hidden door is a `door` exit before it is revealed, and a dark room's exits are listed too. Its room IDs are the ones `mapView()` and ``TurnReport/movement`` report. It exists only when Gnusto is compiled with its `Playtest` package trait, which is on by default. `--disable-default-traits` turns that trait off only in the package it is passed to, so a package that depends on Gnusto turns it off through its dependency's `traits:`, as a package made by `bin/new-game` does.

## Completion candidates

``CompletionCandidates`` is a snapshot of what Tab can offer for the *next* input line: every verb word, the nouns and adjectives of the items currently in scope, the movement words, and the save slots on disk.

The engine pushes it after each turn rather than the handler pulling it when Tab is pressed. That is not a convenience — the line editor is synchronous and `GameWorld` is an actor, so a handler cannot reach into the world for scope mid-read without an `await` it has nowhere to put. Pushing moves the `await` back to the REPL, which has one.

``CompletionCandidates/Context`` decides which pool a word completes against. Under `.command`, the first word of a line completes against verbs and directions and every later word against in-scope nouns and directions. When the engine is holding a save or restore prompt open the context becomes `.filename` and the whole line completes against the save names already on disk, so Tab finds the slot the player wrote last week instead of offering them `take`.

Scope is recomputed each turn, so the noun pool follows the player from room to room. It reads the visible set only: an actor the player has met and who has since wandered off is nameable by FOLLOW but is deliberately kept out of Tab completion, since offering their nouns would be a spoiler.

A front end that corrects what a speech recognizer heard needs more than that. ``GameWorld/vocabulary()`` returns ``WordsInScope``: the verbs, nouns, adjectives, directions, prepositions, and filler words the parser accepts, sorted and split by kind. The lists stay populated during a save or restore prompt, and ``WordsInScope/expectsFilename`` tells a front end to ignore them while the player enters a filename.

The candidate assembly runs on the `GameWorld` actor and ``REPL`` is what calls it. A front end driving the world directly gets no completions and does not usually want them — a text field with its own autocomplete has better material than a word list.

## Ending the session

``IOHandler/finish(_:)`` is called once, after the last turn's output has already been written, and only when the game actually reached an ending. A bare end of input stops the loop without it.

The argument is the ending text — the game's last words, not the last line the handler printed. A stream-backed handler ignores it, because its output already persists. `TerminalIOHandler` uses it for the one thing an alternate screen buffer makes hard: it holds the final frame until the player presses a key, restores the primary screen, and reprints the ending there, so the last paragraph of the game survives into the shell's scrollback instead of vanishing with the buffer.

## Shared and terminal handlers

| Handler | Output | Chosen when |
|---|---|---|
| `TerminalIOHandler` | Full-screen: status bar, reflow-on-resize, line editor with history, PageUp/PageDown scrollback | stdin **and** stdout are both an interactive terminal |
| `ConsoleIOHandler` | `print` to stdout, `readLine` from stdin | anything else — piped input, redirected output, CI |
| ``ScriptedIOHandler`` | An in-memory transcript | constructed by hand; never chosen automatically |

`TerminalLaunch` in [GnustoTerminal](https://github.com/HeirloomLogic/GnustoTerminal) picks between the first two with an `isatty` check on both descriptors, and `GNUSTO_PLAIN` forces the plain one. `GNUSTO_PLAIN` is a flag rather than a setting, so any value at all turns it on, including an empty one. The TTY check is what keeps a transcript test, a `bin/playtest-replay` run and a CI job on the plain path without any of them having to ask.

The terminal handler is around 980 lines of hand-rolled `termios` and ANSI with no dependencies. The console handler is 25. Both satisfy the same protocol, which is the argument for the protocol.

### `ScriptedIOHandler` is the test-facing one

It feeds a fixed list of lines and accumulates everything into ``ScriptedIOHandler/transcript``, with input echoed as `> command` the way a player would see it. It ships in the library rather than in the test support target because game authors write transcript tests too — `play(_:_:)` in `GnustoTestSupport` is a thin wrapper over one. See <doc:TestingYourGame>.

The `inputs:` initializer takes ``Input`` values rather than strings, which is how a test scripts a Ctrl-C:

```swift
let io = ScriptedIOHandler(inputs: [.line("north"), .line("take lamp"), .quit])
```

## Driving the loop yourself

``REPL`` is the engine-owned outer loop:

```swift
let world = try GameWorld(game: MyGame())
await REPL(world: world, io: MyHandler()).run()
```

Two tester conveniences are filtered inside it, ahead of the parser. A line beginning `//` or `#` is a comment: it lands in the transcript and re-prompts, and never reaches ``GameWorld/perform(_:)``, so no fuse or daemon advances. `script` and `unscript` toggle recording the session to a file. Both are front-end concerns by construction — the world simulation cannot see them, so a tester's notes cost no turns.

``REPL/init(world:io:transcriptURL:status:environment:)`` takes two optional output settings. `transcriptURL` records from the first turn. `status` appends the one-line `[status] room=… | moves=… | score=… | turn=cost|free` footer described in `docs/playtesting.md`. Both default to `nil`, and that default is the safety argument: the test suite builds its REPLs without either argument, so no environment variable can enable recording at launch or add a status footer. `TerminalLaunch` is the composition root that reads `GNUSTO_TRANSCRIPT` and `GNUSTO_STATUS` and passes what it found.

The `environment` argument defaults to the process environment. A mid-session `script` command uses its `GNUSTO_TRANSCRIPT_DIR` value to resolve a bare transcript name; pass an explicit environment to keep those recordings in a test's own directory.

`bin/run-game <Game>` wires the standard terminal launcher to your library's `game` factory through an ignored generated package. A custom executable can instead supply its own handler, or share one ``PreparedGame`` across several worlds. Maintained game libraries contain no executable entry points.

## What the engine needs from the platform

The engine uses Foundation, `Synchronization` and `Dispatch`. Its platform C calls stay behind Darwin/Glibc guards in the MCP transport and thread-priority support. Terminal byte decoding, raw mode, ANSI rendering and process launch belong to GnustoTerminal, which supports macOS 15 and Linux.

Gnusto supports iOS 18, whose floor comes from `Synchronization.Mutex`, and keeps the terminal package out of its dependency graph. An iOS app drives ``GameWorld`` directly or supplies its own handler. CI builds Gnusto's library products for iOS; terminal launchers are separate generated packages.

## Topics

- ``IOHandler``
- ``IOHandler/write(_:)``
- ``IOHandler/readLine(prompt:)``
- ``IOHandler/showStatus(_:)``
- ``IOHandler/wantsCompletions``
- ``IOHandler/updateCompletions(_:)``
- ``IOHandler/finish(_:)``
- ``Input``
- ``StatusLine``
- ``StatusLine/init(locationID:locationName:score:moves:)``
- ``GameStatus``
- ``CompletionCandidates``
- ``CompletionCandidates/Context``
- ``GameWorld/vocabulary()``
- ``WordsInScope``
- ``ScriptedIOHandler``
- ``ScriptedIOHandler/transcript``
- ``REPL``
- ``REPL/init(world:io:transcriptURL:status:environment:)``
- ``REPL/run()``
- ``GameWorld``
- ``GameWorld/begin()``
- ``GameWorld/perform(_:)``
- ``GameWorld/requestQuit()``
- ``GameWorld/inputContext``
- ``GameWorld/cancelPendingInput()``
- ``InputContext``
- ``TurnResult``
- ``TurnResult/report``
- ``TurnReport``
- ``TurnReport/InputEvent``
- ``TurnReport/OperationEvent``
- ``GameWorld/mapView()``
- ``RoomMapView``
- ``RoomMapView/ExitObservation``
- ``MapExit``
- ``PreparedGame/declaredMap``
- ``DeclaredMap``
- ``PreparedGame``
- ``PackagedGame``
- ``DisplayWidth``
- ``TextWrap``
- ``TesterInput``
- ``StatusFooter``
- ``SeedRequest``
- ``TranscriptRequest``
- ``PlaytestLaunch``
- ``PlaytestLaunchError``

## See also

- <doc:SharingYourGame>
- <doc:TestingYourGame>
- <doc:TheTurnPipeline>
