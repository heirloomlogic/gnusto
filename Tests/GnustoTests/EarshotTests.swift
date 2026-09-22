import GnustoTestSupport
import Testing

@testable import Gnusto

/// ``Earshot`` and ``say(_:from:)-(String,Earshot)`` — the neighbourhood form of
/// #305's per-room gate, for a timer whose subject is a *noise* (#306).
///
/// The fixture's blast sets its flag before it speaks, so every case below can
/// ask the second question too: did the world move on a turn the player was
/// told nothing about?
struct EarshotTests {
    /// **In the room it happens in.** The plain case, and the control for every
    /// silence below.
    @Test func theLinePrintsInTheRoomTheNoiseIsMadeIn() async throws {
        let transcript = try await play(
            EarshotGame(), ["prime", "wait", "wait", "report"])

        #expect(transcript.contains("A charge goes off in the quarry."))
        #expect(transcript.contains("Blasted: true."))
    }

    /// **And in the other rooms the author named** — the whole point of a set:
    /// the track and the hut are not where the charge is, and they hear it.
    ///
    /// **And the inline variadic is the same gate with its list written out.**
    /// `say(_:from: Location...)` builds an ``Earshot`` and hands it over, so
    /// #305's spelling keeps behaving exactly as it did. The whistle carries to
    /// the quarry and the hut but not to the track, where the blast is heard —
    /// two lists, two answers, one turn.
    @Test func theLinePrintsFromEveryRoomInTheSet() async throws {
        let onTheTrack = try await play(
            EarshotGame(), ["prime", "north", "wait", "report"])
        #expect(onTheTrack.contains("A charge goes off in the quarry."))
        #expect(!onTheTrack.contains("A whistle blows down at the quarry."))

        let inTheHut = try await play(
            EarshotGame(), ["prime", "north", "east", "report"])
        #expect(inTheHut.contains("A charge goes off in the quarry."))
        #expect(inTheHut.contains("A whistle blows down at the quarry."))
    }

    /// **And nowhere else — even one move away.** The farmhouse is a step off
    /// the track, which hears it. An earshot is a list the author wrote, not a
    /// distance the engine measured, which is exactly why the two disagree.
    ///
    /// The `report` is the control: the fuse ran, the flag moved, and the only
    /// thing that did not happen was the telling.
    @Test func theLineIsSilentOutsideTheSetAndTheWorldMovesAnyway() async throws {
        let transcript = try await play(
            EarshotGame(), ["prime", "north", "north", "report"])

        #expect(!transcript.contains("A charge goes off in the quarry."))
        #expect(transcript.contains("Blasted: true."))
    }

    /// **A body that has to ask before it speaks asks ``Earshot/contains(_:)``.**
    /// The rook daemon counts a turn only where the quarry is audible, which a
    /// `say(_:from:)` could not do: by the time the line is dropped the count
    /// has already been taken. Three turns in earshot, then two out of it.
    @Test func containsGatesABodyThatMustDecideBeforeItSpeaks() async throws {
        let stayingClose = try await play(
            EarshotGame(), ["wait", "north", "east", "report"])
        #expect(stayingClose.contains("Rooks: 3."))

        let walkingOff = try await play(
            EarshotGame(), ["wait", "north", "north", "wait", "report"])
        #expect(walkingOff.contains("Rooks: 2."))
    }

    /// **An unregistered room traps rather than printing nothing** (#476).
    ///
    /// `Location.==` is reference identity on the declaration token, so a room
    /// the bootstrap never saw could never equal the room the player is in, and
    /// the old membership test answered "no" for it exactly as it answered for
    /// the farmhouse above. Silence is the gate's ordinary output, which is what
    /// made the mistake unreadable: the author sees a line that never prints and
    /// nothing at all to say why. Membership now resolves each room through the
    /// registry, so the mistake lands on the diagnostic every other inline
    /// entity gets.
    ///
    /// A child process apiece — see ``expectTrap(_:says:sourceLocation:)`` for
    /// when that is worth spending. It is here because the wording is the whole
    /// of the teaching: "not part of the running game" alone leaves an author
    /// staring at a `Location` that plainly exists.
    @Test func anUnregisteredRoomTrapsInsteadOfPrintingNothing() async throws {
        let result = await #expect(
            processExitsWith: .failure, observing: [\.standardErrorContent]
        ) {
            _ = try await play(UnregisteredEarshotGame(), ["ring"])
        }
        expectTrap(
            result,
            says: "Location is not part of the running game",
            "stored properties of your Game type")
    }

    /// **And so does an unregistered thing**, on the ``Item`` overload — which
    /// never had the identity bug, because its gate is ``Item/isVisible`` and
    /// that read resolves the item's id before it can answer. Asserted so the
    /// two channels are held to one answer.
    @Test func anUnregisteredThingTrapsOnTheItemOverload() async throws {
        let result = await #expect(
            processExitsWith: .failure, observing: [\.standardErrorContent]
        ) {
            _ = try await play(UnregisteredEarshotGame(), ["toll"])
        }
        expectTrap(
            result,
            says: "Item is not part of the running game",
            "stored properties of your Game type")
    }
}
