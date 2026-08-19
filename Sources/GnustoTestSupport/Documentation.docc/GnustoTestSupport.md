# ``GnustoTestSupport``

Boot a game, feed it the commands a player would type, and assert on what it printed.

## Overview

A Gnusto game is a value and a play session is a function of its typed input, so
the natural test is a *transcript test*. ``play(_:_:seed:saveDirectory:)`` boots
the game, feeds it a list of commands, and returns everything printed with the
input interleaved as `> command` — the same text the player saw. Everything else
in this library either cuts that string down to the part a claim is about, or
records a Swift Testing issue with the whole of it attached, which is what a bare
`#expect(transcript.contains(…))` cannot do. Gnusto's own suite is roughly a
thousand tests of this shape.

This is neither a `GameContent` bundle nor a `GamePlugin`. It declares no verbs,
no rules and no entities, and a game never links it: it is a test-only helper
library, and it imports the toolchain's Testing library, which ships with the
compiler rather than the OS. Put it in a test target's dependencies and nowhere
else — an executable that links it can fail at load time.

The host passes a game type and a list of commands; the library holds one piece
of state of its own, a process-wide cache of prepared games behind a `Mutex`.
``cachedWorld(_:seed:saveDirectory:)`` exists because `Bootstrap.build` reflects
over the game and every content bundle it lists, and that runs about 15× longer
than a turn does. The suite boots the same handful of game types thousands of
times, so building each once and copying the prepared definition takes bootstrap
out of the suite's critical path. `play` goes through it; a test that wants the
world rather than the transcript can call it directly and drive `REPL` itself.

The Gnusto catalog's *Testing Your Game* article teaches four of these helpers
and the habits around them — pinning a seed, sweeping `GNUSTO_SEED` for tests
that pass by luck, deciding when a trap is worth a test at all. This page is the
list it stops short of.

## A transcript test

```swift
import GnustoTestSupport
import Testing

@testable import MyGame

@Test func ringingTheBellWinsTheGame() async throws {
    let transcript = try await play(
        MyGame(),
        ["take rope", "north", "ring bell"],
        seed: 7)

    expectInOrder(
        transcript,
        [
            "Village Garden",
            "Taken.",
            "Bell Tower",
            "The great bronze bell peals",
        ])

    let looking = turnOutput(of: "examine hook", in: transcript)
    #expect(looking.contains("screwed to the wall"))
    #expect(occurrences(of: "The bell tolls", in: transcript) == 1)
}
```

Omit `seed:` and the stream is fresh each run, unless `GNUSTO_SEED` is set,
which pins every call that passed no seed of its own and leaves the ones that
did alone. Pass `saveDirectory:` when a test exercises named `save`/`restore`,
so it never writes to the real per-user saves directory.

## Slicing before asserting

`turnOutput(of:in:)` matches the *first* occurrence of a command, so a route
that types `look` four times wants four different commands or a different
helper. `output(after:in:)` and `output(before:in:)` cut on any marker rather
than a prompt, which is the slice for "and then, later…". `occurrences(of:in:)`
is the count assertion — a beat that must fire exactly once.
`lines(mentioning:in:)` returns the matching lines in transcript order, which is
what an alignment check compares between two runs to prove that a guard burned
no randomness.

## Asserting

`expectInOrder` is the workhorse: a sequence of substrings, each match resuming
after the last, strict enough to pin the beats that matter and loose enough to
survive an edit between them. The rest of the assertions are about a whole
transcript rather than a phrase in it. `expectEveryNounAnswered` fails on either
answer a game gives a noun it doesn't know — `I don't know the word "x"` and
`You can't see any such thing` — which is what a walk of `x <noun>` over a
room's own description is checking. `expectNoAmbiguity` fails on *Which do you
mean…*, and is deliberately a separate call: an unanswered noun is always a
defect, while an ambiguity is only one where the author believed the room held a
single thing of that kind.

`expectNoEngineStubLineSurvives` is for a game that has re-voiced the stub verbs
and wants to keep the claim whole. It reads `text.stubs` with `Mirror` rather
than naming the properties, so a stub added to the engine tomorrow is compared
the day it lands. `engineVoicedStubLines` is the same sweep without the issue
recording, split out so the sweep itself can be tested for being alive — a
reflection loop that matches nothing passes silently.

## Trapping a `fatalError`

The engine answers an authoring mistake by crashing with a message that names
it. A `fatalError` cannot be caught, so the only way to assert on one is to run
it in a child process and read what it printed; Swift Testing's exit tests do
the running and `expectTrap` does the reading.

```swift
let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
    _ = try await play(MyGame(), ["prime the bomb"])
}
expectTrap(result, says: "names a daemon", "use startDaemon(_:)")
```

Each call is a child process, some 60 ms against 1 ms for an in-process
assertion, and the `#expect` has to stay at the call site because its body is
compiled into a C function that captures nothing. `expectTrap`'s own doc comment
carries the rule for when that is worth spending, since it is where the person
deciding is standing: make the bad message unrepresentable and write no test,
or split the message into a pure function and assert it in a millisecond, before
reaching for the third shape. Exit tests are built on macOS, Linux and Windows
and are absent elsewhere, so `expectTrap` is compiled under `GNUSTO_EXIT_TESTS`
and a test using it wants a `#if` on a suite that also runs on iOS, watchOS,
tvOS, visionOS or WASI.

## Topics

### Playing a session

- ``play(_:_:seed:saveDirectory:)``
- ``cachedWorld(_:seed:saveDirectory:)``

### Slicing a transcript

- ``turnOutput(of:in:)``
- ``output(after:in:)``
- ``output(before:in:)``
- ``occurrences(of:in:)``
- ``lines(mentioning:in:)``

### Asserting

- ``expectInOrder(_:_:sourceLocation:)``
- ``expectEveryNounAnswered(_:_:sourceLocation:)``
- ``expectNoAmbiguity(_:_:sourceLocation:)``
- ``expectNoEngineStubLineSurvives(in:game:sourceLocation:)``
- ``engineVoicedStubLines(in:)``

### Trapping a `fatalError`

- ``expectTrap(_:says:sourceLocation:)``
