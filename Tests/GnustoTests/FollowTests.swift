import Gnusto
import GnustoTestSupport
import Testing

/// `FOLLOW <actor>`: the verb that lets a player go after somebody who has
/// just walked out.
///
/// Two decisions are pinned here, and both are load-bearing. The search is
/// **one exit deep** — it can only ever move the player into the room the
/// quarry is actually standing in, never into a room a wider search guessed
/// at. And the target is *nameable* while out of sight even though it is not
/// *visible*, because "You can't see any such thing" is exactly the wrong
/// answer to `follow him` on the turn after he left.
struct FollowTests {
    // MARK: - Refusals

    @Test func followingSomebodyInTheRoomSaysSo() async throws {
        let transcript = try await play(FollowLab(), ["follow walker"])
        #expect(transcript.contains("The walker is right here."))
    }

    @Test func followingAThingRefuses() async throws {
        let transcript = try await play(FollowLab(), ["follow statue"])
        #expect(transcript.contains("The statue isn't going anywhere."))
    }

    /// Somebody taken off the map entirely is not standing in a room, so they
    /// are not in the naming reach either — the widening is "actors elsewhere
    /// in the house", not "actors that ever existed".
    @Test func followingSomebodyTakenOffTheMapFindsNobody() async throws {
        let transcript = try await play(
            FollowLab(), ["send elsewhere marker", "follow walker"])
        #expect(
            turnOutput(of: "follow walker", in: transcript).contains("can't see any such thing"))
    }

    // MARK: - Moving

    @Test func followingIntoAnAdjacentRoomMovesThePlayer() async throws {
        let transcript = try await play(
            FollowLab(), ["send study marker", "follow walker"])
        let followed = turnOutput(of: "follow walker", in: transcript)
        // The aside lands ahead of the room, which is where an aside belongs.
        expectInOrder(followed, ["(after the walker)", "Study"])
    }

    /// The depth decision, pinned. The attic is two hops from the hall, and
    /// the verb says so rather than walking the player halfway and announcing
    /// a pursuit into an empty room. A regression test against somebody
    /// quietly adding a breadth-first search later.
    @Test func followingSomebodyTwoRoomsAwayAdmitsIgnorance() async throws {
        let transcript = try await play(
            FollowLab(), ["send attic marker", "follow walker"])
        let followed = turnOutput(of: "follow walker", in: transcript)
        #expect(followed.contains("You have no idea which way the walker went."))
        #expect(!followed.contains("(after the walker)"))
        #expect(!followed.contains("Study"))
    }

    // MARK: - Awkward exits behave exactly as GO makes them behave

    @Test func followingThroughAShutDoorRefusesLikeGo() async throws {
        let transcript = try await play(
            FollowLab(), ["send pantry marker", "follow walker", "east"])
        let followed = turnOutput(of: "follow walker", in: transcript)
        #expect(followed.contains("The pantry door is closed."))
        // And the pursuit is never announced for a move that didn't happen.
        #expect(!followed.contains("(after the walker)"))
        #expect(turnOutput(of: "east", in: transcript).contains("The pantry door is closed."))
    }

    @Test func followingThroughAFalseConditionGivesItsOwnBlockedMessage() async throws {
        let transcript = try await play(
            FollowLab(), ["send vault marker", "follow walker", "unbar", "follow walker"])
        #expect(transcript.contains("The vault is barred."))
        // Once the condition passes, the same command goes through.
        expectInOrder(transcript, ["The vault is barred.", "Unbarred.", "(after the walker)", "Vault"])
    }

    @Test func followingIsStableWhenTwoExitsLeadToTheSameRoom() async throws {
        let first = try await play(FollowLab(), ["send porch marker", "follow walker"])
        let second = try await play(FollowLab(), ["send porch marker", "follow walker"])
        #expect(first == second)
        #expect(first.contains("Porch"))
    }

    // MARK: - Naming somebody who has gone

    /// The whole reason the verb needed a widened naming set. Without it this
    /// reads "You can't see any such thing", which is a parser bug as far as
    /// the player is concerned.
    @Test func somebodyWhoHasLeftIsStillNameable() async throws {
        let transcript = try await play(
            FollowLab(), ["send attic marker", "follow walker"])
        #expect(!transcript.contains("can't see any such thing"))
    }

    /// The far-sighted pass answers a *name*, never a description. A phrase
    /// that picks out several people who are all out of sight has named
    /// nobody, and listing them would hand the player a cast they have not
    /// met — in Fulminate, `follow man` on turn one would otherwise print
    /// three names out of an empty hall.
    @Test func anAmbiguousNameOutOfSightNamesNobodyRatherThanListingTheCast() async throws {
        let transcript = try await play(
            FollowLab(), ["send attic marker", "follow person"])
        let followed = turnOutput(of: "follow person", in: transcript)
        #expect(followed.contains("can't see any such thing"))
        #expect(!followed.contains("Which do you mean"))
        #expect(!followed.contains("porter"))
    }

    /// Somebody standing in a room no exit leads to — a game's off-map holding
    /// pen, where a character waits for their entrance — is not nameable
    /// either. Otherwise a refusal reads back the name of a person the story
    /// has not introduced: in Fulminate, `follow patrolman` on turn one would
    /// tell the player there is a policeman coming.
    @Test func somebodyInAnOffMapHoldingPenIsNotNameable() async throws {
        let transcript = try await play(FollowLab(), ["send limbo marker", "follow walker"])
        let followed = turnOutput(of: "follow walker", in: transcript)
        #expect(followed.contains("can't see any such thing"))
        #expect(!followed.contains("You have no idea which way"))
    }

    /// A conditional exit whose gate is shut must not shadow an open way to
    /// the same room. GO would take the open one, so FOLLOW has to as well.
    @Test func anOpenExitBeatsAConditionalOneOntoTheSameRoom() async throws {
        let transcript = try await play(FollowLab(), ["send crypt marker", "follow walker"])
        let followed = turnOutput(of: "follow walker", in: transcript)
        #expect(followed.contains("Crypt"))
        #expect(!followed.contains("The crypt gate is barred."))
    }

    /// In-room ambiguity is untouched: those are people the player can see, so
    /// asking which one is the right question.
    @Test func ambiguityAmongPeopleInTheRoomStillAsks() async throws {
        let transcript = try await play(
            FollowLab(), ["send study marker", "north", "follow person"])
        #expect(turnOutput(of: "follow person", in: transcript).contains("Which do you mean"))
    }

    /// And the widening is narrow: it reaches FOLLOW's noun phrase and nothing
    /// else, so every other verb still tells the truth about what is in view.
    @Test func aDistantActorIsStillInvisibleToEveryOtherVerb() async throws {
        let transcript = try await play(
            FollowLab(), ["send attic marker", "examine walker", "take walker"])
        #expect(turnOutput(of: "examine walker", in: transcript).contains("can't see any such thing"))
        #expect(turnOutput(of: "take walker", in: transcript).contains("can't see any such thing"))
    }

    /// FOLLOW puts its target in the *direct object* slot, so the target's own
    /// rules get first refusal. That is the escape hatch a game buys a longer
    /// pursuit with — Fulminate uses it for the one crossing that is two hops
    /// — and a topic slot would have made it unreachable.
    @Test func theTargetsOwnBeforeRuleRunsFirst() async throws {
        let transcript = try await play(FollowLab(), ["follow porter"])
        #expect(transcript.contains("The porter turns a corner you did not know was there."))
        #expect(!transcript.contains("(after the porter)"))
    }
}
