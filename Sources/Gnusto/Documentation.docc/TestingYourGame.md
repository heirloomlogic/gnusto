# Testing Your Game

Play scripted sessions in your test suite and assert on the transcript.

## Overview

A Gnusto game is a value, and a play session is a function of its typed input — so the natural test is a *transcript test*: boot the game, feed it the commands a player would type, and assert on what it printed. The `GnustoTestSupport` product packages the helpers Gnusto's own suite is built on.

## Add the product to your test target

`GnustoTestSupport` links against the Swift Testing library, which ships in the toolchain rather than the OS — so add it to your **test target only**, never to the game executable:

```swift
.testTarget(
    name: "MyGameTests",
    dependencies: [
        "MyGame",
        .product(name: "GnustoTestSupport", package: "Gnusto"),
    ]
)
```

## Play a session, assert in order

`play` boots the game, feeds it each command, and returns everything the game printed with the input interleaved as `> command` — exactly what a player would have seen. `expectInOrder` then asserts that a sequence of substrings appears in order, each match resuming after the last; on failure it records one Swift Testing issue at your call site, with the full transcript in the message.

```swift
import GnustoTestSupport
import Testing

@testable import MyGame

struct MyGameTests {
    @Test func ringingTheBellWinsTheGame() async throws {
        let transcript = try await play(
            MyGame(),
            ["take rope", "north", "ring bell"])

        expectInOrder(
            transcript,
            [
                "Village Garden",
                "Taken.",
                "Bell Tower",
                "The great bronze bell peals",
                "Your score is 1 of a possible 1",
            ])
    }
}
```

Ordered needles are the sweet spot for transcript assertions: strict enough to pin the beats that matter, loose enough to survive incidental prose edits between them. For a claim about one specific turn, `turnOutput(of:in:)` slices out everything printed between a command and the next prompt:

```swift
let looking = turnOutput(of: "examine hook", in: transcript)
#expect(looking.contains("screwed to the wall"))
```

### Slicing a transcript

`turnOutput(of:in:)` matches the **first** occurrence of a command, so a test that types `look` four times and asks about the third gets the first. Vary the commands rather than repeating them. Four more helpers cut the transcript other ways:

```swift
output(after: "open the door", in: transcript)   // everything from that turn on
output(before: "open the door", in: transcript)  // everything up to it
occurrences(of: "The bell tolls.", in: transcript)
lines(mentioning: "keeper", in: transcript)
```

`occurrences(of:in:)` is the one to reach for when the bug is a line printing *twice* — an assertion that the text `contains` it cannot see the difference.

## Sweep the vocabulary

Two assertions check something no hand-written needle does: whether the game answers for the words it printed.

```swift
let transcript = try await play(MyGame(), probe, seed: 0)
expectEveryNounAnswered(transcript, "\(probe)")
expectNoAmbiguity(transcript, "\(probe)")
```

`expectEveryNounAnswered` walks the nouns the prose printed and fails on any the parser does not know. A named thing the parser has never heard of reads to a player as a bug in the game, and it is the commonest defect there is, because adding a noun to a description costs nothing and adding the scenery item is a separate thought. `expectNoAmbiguity` fails when a phrase the game itself printed makes the parser ask which one you meant.

The third of the family reads the game's text rather than a transcript, and is about voice rather than correctness. `expectNoEngineStubLineSurvives(in:game:)` reflects over your `text.stubs` and records an issue for every line still worded exactly as the engine ships it:

```swift
expectNoEngineStubLineSurvives(in: MyGame().text.stubs, game: "MyGame")
```

`engineVoicedStubLines(in:)` returns those property names instead of asserting, for a test that means to allow a few by name. See <doc:StubVerbs>.

## Boot each game once

`cachedWorld` hands back a prepared ``GameWorld``, built the first time a game is asked for and reused after. The bootstrap costs many times what a turn does, so a suite that boots afresh in every test spends most of its run in it:

```swift
let world = try cachedWorld(MyGame())
```

`play` does not need this — it takes the game value and boots its own — but a test that inspects ``GameWorld`` state directly does.

## Pin the random stream

Anything random in a game — combat rolls, roaming actors, `oneOf` prose — draws from one seeded stream (see <doc:TextAndRandomness>). A transcript that crosses randomness will differ run to run unless you pin the seed:

```swift
let transcript = try await play(MyGame(), ["attack troll with sword"], seed: 7)
```

With a pinned seed the whole session replays identically everywhere, so the transcript is safe to assert byte by byte. Two habits from Gnusto's own suite: discover a seed that produces the sequence you want with a throwaway scratch test, then record the expected outcomes in a comment beside the pinned assertions; and expect to re-pin when the game gains a new daemon or actor, because every extra consumer shifts the draw sequence.

The same seed is available to the built binary as `GNUSTO_SEED`, so a session someone played by hand becomes a test: pin the seed, record the transcript with `GNUSTO_TRANSCRIPT`, and the command list replays under `play(_:_:seed:)` to the same prose. See <doc:SharingYourGame> for the full set of environment variables.

## Sweep for tests that pass by luck

A test that pins no seed draws a fresh stream every run. That is the right default for a route that never reaches a random value, and a latent flake for one that does — it passes for months and then fails once, on somebody else's machine, in a run that has nothing to do with what they changed.

`GNUSTO_SEED` seeds the suite as well as a built binary. It supplies the seed for every `play(_:_:)` call that passed none of its own, and leaves the calls that did pin one alone:

```sh
for s in $(seq 0 99); do
  GNUSTO_SEED=$s swift test 2>&1 | grep "recorded an issue"
done
```

Pinned tests keeping their own seeds is the point. A sweep is hunting for tests that pass because the dice were kind; if it overrode `seed: 11` it would re-fail every test that pinned a seed deliberately and say nothing at all about the ones that didn't.

A green sweep means every unpinned test was insensitive to the seed across the band you swept. It is a band, not a proof — a route that only misbehaves for one draw in three hundred needs a wider one. When you are chasing a specific test rather than the whole suite, a throwaway scratch test that replays one route across thousands of seeds and collects the failures is far more sensitive than sweeping whole runs, and takes seconds:

```swift
for seed in UInt64(0)..<5000 {
    let transcript = try await play(MyGame(), route, seed: seed)
    if !transcript.contains("what should always happen") { failing.append(seed) }
}
```

Pin the seeds that sweep turns up, and say in a comment what the seed *buys* — "seed 11: the troll falls to the first blow" — so the next person to re-pin knows what they are re-pinning for.

## Assert a trap

Some mistakes are the author's, not the player's, and the engine answers those by crashing with a message that names the mistake — `startFuse` handed a daemon's name, a `describe { }` closure that calls the describer already running it. A `fatalError` cannot be caught, so the only way to assert on one is to run it in a child process and read what it printed. Swift Testing's exit tests do the running; `expectTrap` does the reading.

```swift
@Test func namingTheWrongTimerSaysWhichHelperToUse() async throws {
    let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
        _ = try await play(MyGame(), ["prime the bomb"])
    }
    expectTrap(result, says: "names a daemon", "use startDaemon(_:)")
}
```

The `#expect` has to stay at the call site — its body is compiled into a C function, so it captures nothing unless you name the value and its type in the capture list (`{ [n = n as Int] in … }`), and a helper taking the closure as an argument cannot be written at all.

Each of these costs a child process, some 60 ms. That is worth spending where the *message* is what an author will read to find their mistake, and not worth it for an ordinary precondition — split that message into a pure function and assert it in process instead. Best of all is a trap you can delete: where several share a sentence, fold them into one helper that takes the missing half as a required argument, and where one guards an argument nobody could sensibly mean, change the signature so the compiler refuses it. `expectTrap` carries the full rule, since it is where the person deciding is standing.

Exit tests are unavailable on iOS, watchOS, tvOS, visionOS and WASI, so a test using one wants a `#if` around it if your game's tests run on those.

## What the helpers are made of

`play` is three lines over public API — ``GameWorld/init(game:seed:saveDirectory:)``, ``ScriptedIOHandler``, and ``REPL`` — so when a test needs something the helpers don't cover (inspecting ``GameWorld`` state mid-session, a custom ``IOHandler``), drop down and compose the pieces directly.

A transcript test still only asserts that a line *appeared*. Whether the line was *true of the room it printed in* is a different question, and <doc:PlayTesting> is how it gets asked.

## See also

- <doc:PlayTesting>
- <doc:TextAndRandomness>
- <doc:GettingStarted>
