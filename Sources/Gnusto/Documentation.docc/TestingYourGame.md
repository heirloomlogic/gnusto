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

## What the helpers are made of

`play` is three lines over public API — ``GameWorld/init(game:seed:)``, ``ScriptedIOHandler``, and ``REPL`` — so when a test needs something the helpers don't cover (inspecting ``GameWorld`` state mid-session, a custom ``IOHandler``), drop down and compose the pieces directly.

## See also

- <doc:TextAndRandomness>
- <doc:GettingStarted>
