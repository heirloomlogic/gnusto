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

## What the helpers are made of

`play` is three lines over public API — ``GameWorld/init(game:seed:)``, ``ScriptedIOHandler``, and ``REPL`` — so when a test needs something the helpers don't cover (inspecting ``GameWorld`` state mid-session, a custom ``IOHandler``), drop down and compose the pieces directly.

## See also

- <doc:TextAndRandomness>
- <doc:GettingStarted>
