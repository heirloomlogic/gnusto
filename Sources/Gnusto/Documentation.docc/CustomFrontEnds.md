# Custom Front Ends

Putting the engine behind something that is not a terminal.

## Overview

``GameWorld`` is an actor with three public methods — ``GameWorld/begin()``,
``GameWorld/perform(_:)`` and ``GameWorld/requestQuit()`` — and none of them
knows what a terminal is. Everything a player sees comes back as a
``TurnResult``: a string, a ``StatusLine``, and a flag saying whether the game
is over. The terminal front end is a client of those three methods, not a
privileged part of the engine, and an iOS app is a client of exactly the same
three.

Which way in to take depends on whether your front end can afford to block.

**Implement ``IOHandler`` and let ``REPL`` drive.** The REPL owns the loop —
prompt, parse, perform, print — and calls your handler for each half. This is
the shape for anything that reads a line at a time: a different terminal, a
pipe, a serial console, a test harness.

**Or call the actor directly.** ``IOHandler/readLine(prompt:)`` is synchronous
and blocking by design, which is fine for a console and wrong for a UI event
loop. An event-driven front end skips the protocol and drives the world itself:

```swift
let world = try GameWorld(game: MyGame())

var turn = await world.begin()
show(turn.output, status: turn.status)

// Later, when the player submits a line from a text field:
turn = await world.perform(line)
show(turn.output, status: turn.status)
if turn.isFinished { showEnding(turn.output) }
```

The driver keeps no state of its own. Round-trip questions — "Which do you mean,
the brass lantern or the brass hook?", a save filename, the RESTART / RESTORE /
UNDO / QUIT prompt after a death — are pending state on the actor, so the next
line you hand `perform` answers whichever one is open. The driver never has to
know a question was asked.

## What a handler has to implement

``IOHandler`` has five requirements and three default implementations, so the
smallest conformance is two methods:

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

That is ``ConsoleIOHandler`` in full, minus the `<br>` translation below. The
other three — ``IOHandler/showStatus(_:)``, ``IOHandler/updateCompletions(_:)``
and ``IOHandler/finish(_:)`` — default to doing nothing, which is the right
answer for a handler whose output is a stream rather than a screen.

The protocol is `Sendable`, so a handler that keeps state keeps it behind a
lock. ``ScriptedIOHandler`` and ``TerminalIOHandler`` both box theirs in a
`Mutex`.

### Rendering the text you are handed

Game prose is written as multi-line string literals wrapped for source
readability. The newlines in them are the author's typing, not the author's
layout: a single newline is a soft break that folds to a space, a blank line is
a paragraph break, `<br>` is a hard break *inside* a paragraph (a banner's title
over its tagline), and an indented line is a form — a sign, an inscription, a
scrap of verse — that keeps its own shape.

So `write(_:)` is handed prose, not layout. A handler that does not lay text out
itself renders it with `TextWrap.plain(_:)`, which applies all four rules:

```swift
func write(_ text: String) {
    print(TextWrap.plain(text), terminator: "")
}
```

Do not print `text` raw. A raw handler shows `<br>` to the player and breaks
every paragraph at whatever column the game's source happened to be typed at.

A handler that *does* reflow — a `UITextView`, a DOM node — wants the paragraph
structure rather than the rendered string, and should fold and split on the same
four rules before handing text to its own layout. The terminal-column machinery
behind the full-screen handler is internal to the engine; a front end with a
real layout engine has a better one already.

## `.quit` is not a command

``IOHandler/readLine(prompt:)`` returns an ``Input``, not a `String`. Most of
the time it is ``Input/line(_:)``. The other case exists for one reason, stated
where it is declared:

> a front-end quit request (e.g. Ctrl-C) that ends the game *without* being
> parsed as a command — so it can't be swallowed by an open save/restore prompt
> or clash with a game that has redefined the `quit` verb. The REPL maps
> `.quit` to `GameWorld.requestQuit()`, which is keyed to `Intent.quit` rather
> than the editable verb word.

Handing the string `"quit"` back instead would work in most games most of the
time, and fail in the two places a player reaches for Ctrl-C: mid-way through a
save prompt, where the line becomes the filename, and in a game whose author
spelled the verb something else. ``GameWorld/requestQuit()`` abandons any open
prompt and ends the game through the same path the verb takes, so the score
epilogue still prints.

A front end with no quit gesture — a pipe, a socket — never returns `.quit`, and
`nil` (end of input) stops the loop instead.

## The status line

``StatusLine`` is the location name, the score and the move count, handed over
after every turn. ``TerminalIOHandler`` paints it as a reverse-video bar;
everything else ignores it.

``TurnResult/isFinished`` is the flag that stops the loop, and it is *not* the
same as "the player is alive". ``GameStatus`` has five cases and only three of
them are final:

- `won`, `lost` and `quit` end the session.
- `playing` continues it.
- `dead` is over but not final. The world's time has stopped and the program
  keeps reading, because the death prompt offers RESTART / RESTORE / UNDO /
  QUIT and the player has not answered yet.

A front end that dismisses its input field on death loses the game it was about
to let the player restore. Read `isFinished`, not the status.

## Completion candidates

``CompletionCandidates`` is a snapshot of what Tab can offer for the *next*
input line: every verb word, the nouns and adjectives of the items currently in
scope, the movement words, and the save slots on disk.

The engine pushes it after each turn rather than the handler pulling it when Tab
is pressed. That is not a convenience — the line editor is synchronous and
`GameWorld` is an actor, so a handler cannot reach into the world for scope
mid-read without an `await` it has nowhere to put. Pushing moves the `await`
back to the REPL, which has one.

``CompletionCandidates/Context`` decides which pool a word completes against.
Under `.command`, the first word of a line completes against verbs and
directions and every later word against in-scope nouns and directions. When the
engine is holding a save or restore prompt open the context becomes `.filename`
and the whole line completes against the save names already on disk, so Tab
finds the slot the player wrote last week instead of offering them `take`.

Scope is recomputed each turn, so the noun pool follows the player from room to
room. It reads the visible set only: an actor who has wandered off is nameable
by FOLLOW but is deliberately kept out of Tab completion, since offering their
nouns would be a spoiler.

The candidate assembly runs on the `GameWorld` actor and ``REPL`` is what calls
it. A front end driving the world directly gets no completions and does not
usually want them — a text field with its own autocomplete has better material
than a word list.

## Ending the session

``IOHandler/finish(_:)`` is called once, after the last turn's output has
already been written, and only when the game actually reached an ending. A bare
end of input stops the loop without it.

The argument is the ending text — the game's last words, not the last line the
handler printed. A stream-backed handler ignores it, because its output already
persists. ``TerminalIOHandler`` uses it for the one thing an alternate screen
buffer makes hard: it holds the final frame until the player presses a key,
restores the primary screen, and reprints the ending there, so the last
paragraph of the game survives into the shell's scrollback instead of vanishing
with the buffer.

## The three handlers that ship

| Handler | Output | Chosen when |
|---|---|---|
| ``TerminalIOHandler`` | Full-screen: status bar, reflow-on-resize, line editor with history, PageUp/PageDown scrollback | stdin **and** stdout are both an interactive terminal |
| ``ConsoleIOHandler`` | `print` to stdout, `readLine` from stdin | anything else — piped input, redirected output, CI |
| ``ScriptedIOHandler`` | An in-memory transcript | constructed by hand; never chosen automatically |

``GameMain`` picks between the first two with an `isatty` check on both
descriptors, and `GNUSTO_PLAIN` forces the plain one. `GNUSTO_PLAIN` is a flag
rather than a setting, so any value at all turns it on, including an empty one.
The TTY check is what keeps a transcript test, a `bin/playtest-replay` run and a
CI job on the plain path without any of them having to ask.

The terminal handler is around 980 lines of hand-rolled `termios` and ANSI with
no dependencies. The console handler is 25. Both satisfy the same protocol,
which is the argument for the protocol.

### `ScriptedIOHandler` is the test-facing one

It feeds a fixed list of lines and accumulates everything into
``ScriptedIOHandler/transcript``, with input echoed as `> command` the way a
player would see it. It ships in the library rather than in the test support
target because game authors write transcript tests too — `play(_:_:)` in
`GnustoTestSupport` is a thin wrapper over one. See <doc:TestingYourGame>.

The `inputs:` initializer takes ``Input`` values rather than strings, which is
how a test scripts a Ctrl-C:

```swift
let io = ScriptedIOHandler(inputs: [.line("north"), .line("take lamp"), .quit])
```

## Driving the loop yourself

``REPL`` is the outer loop, and it holds the only `await` in a Gnusto game:

```swift
let world = try GameWorld(game: MyGame())
await REPL(world: world, io: MyHandler()).run()
```

Two tester conveniences are filtered inside it, ahead of the parser. A line
beginning `//` or `#` is a comment: it lands in the transcript and re-prompts,
and never reaches ``GameWorld/perform(_:)``, so no fuse or daemon advances.
`script` and `unscript` toggle recording the session to a file. Both are
front-end concerns by construction — the world simulation cannot see them, so a
tester's notes cost no turns.

``REPL/init(world:io:transcriptURL:status:)`` takes two optional extras.
`transcriptURL` records from the first turn. `status` appends the one-line
`[status] room=… | moves=… | turn=cost|free` footer described in
`docs/playtesting.md`. Both default to `nil`, and that default is the safety
argument: the test suite builds its REPLs without either argument, so no
environment variable can make a suite transcript grow a line. ``GameMain`` is
the composition root that reads `GNUSTO_TRANSCRIPT` and `GNUSTO_STATUS` and
passes what it found.

If your game type conforms to ``GameMain``, all of this is already wired —
`@main struct MyGame: Game, GameMain {}` is a complete executable. Write your
own entry point when you need a handler `GameMain` would not have picked, or a
world built from a ``PreparedGame`` shared across several sessions.

## What the engine needs from the platform

Nothing in the engine imports anything but Foundation, `Synchronization` (three
files) and `Dispatch` (one). Four files reach for platform C, and all four do it
behind `#if canImport(Darwin)` / `#elseif canImport(Glibc)`: the terminal
handler, the `isatty` check in ``GameMain``, the MCP play-test server and its
stdio transport. Nothing in the parser, the turn pipeline, the rule table or the
world state touches any of it.

The library therefore compiles for iOS unchanged, which has been verified by
declaring the platform and building against iOS 18. The package manifest does
**not** currently declare `.iOS`, so that is a line somebody adding an iOS front
end would have to add themselves, not a configuration this package supports and
tests. The terminal handler compiles there and is useless there; a front end
that never constructs one never pays for it.

## Topics

- ``IOHandler``
- ``IOHandler/write(_:)``
- ``IOHandler/readLine(prompt:)``
- ``IOHandler/showStatus(_:)``
- ``IOHandler/updateCompletions(_:)``
- ``IOHandler/finish(_:)``
- ``Input``
- ``StatusLine``
- ``GameStatus``
- ``CompletionCandidates``
- ``CompletionCandidates/Context``
- ``TerminalIOHandler``
- ``ConsoleIOHandler``
- ``ScriptedIOHandler``
- ``ScriptedIOHandler/transcript``
- ``REPL``
- ``REPL/init(world:io:transcriptURL:status:)``
- ``REPL/run()``
- ``GameMain``
- ``GameWorld``
- ``GameWorld/begin()``
- ``GameWorld/perform(_:)``
- ``GameWorld/requestQuit()``
- ``TurnResult``
- ``PreparedGame``
- ``StatusFooter``
- ``SeedRequest``

## See also

- <doc:SharingYourGame>
- <doc:TestingYourGame>
- <doc:TheTurnPipeline>
