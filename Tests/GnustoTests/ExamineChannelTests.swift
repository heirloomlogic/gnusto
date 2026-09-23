import GnustoTestSupport
import Testing

@testable import Gnusto

/// A listing line on the examine channel, looked for in every shipped game.
///
/// `firstSight(…)` is the sentence a room description lists an item with, and
/// it stops at the first touch. `description(…)` answers EXAMINE — and READ —
/// wherever the item is. A sentence that says where the item lies belongs on the
/// first channel. On the second it is false as soon as the player carries the
/// item somewhere else: *"There is an object which looks like a tube of
/// toothpaste here."*, answered from the player's hand in the Dam Lobby.
struct ExamineChannelTests {
    /// #350 fixed Zork 1 items of this class and guarded them by naming them,
    /// and #514 found more, because a guard that names items sees only the
    /// items it names. #514's sweep derived its subjects from the built game
    /// instead, but only from Zork 1, and its pattern missed the tube, the trunk
    /// and both canaries there (#617). Dungeon's canaries had the same
    /// sentences, and that sweep never asked about them. So this one asks every
    /// shipped game, and matches the other ways the sources write the sentence.
    ///
    /// Only a takable item is judged. Scenery cannot be picked up, so a sentence
    /// placing it stays true. An actor's listing line is standing state,
    /// reprinted on every look, and the bootstrap's own check exempts actors
    /// for the same reason.
    @Test func noShippedItemExaminesToASentenceAboutWhereItIs() throws {
        /// Takable in the engine's sense, but never moved from the place the
        /// sentence names. Keyed `title/id`.
        let neverCarried: Set<String> = [
            // Fixed to its chain, so "At the end of the chain is a basket." is
            // true wherever the chain hangs. The original splits it into
            // `LOWERED-BASKET` and `RAISED-BASKET` for the same reason; this
            // port uses one item and a scenery stand-in.
            "Zork1/ZorkCoalMine.basket",
            // `before(.take)` refuses, so the coat stays on the hat stand.
            "Fulminate/coat",
        ]

        // The shapes: a sentence ending on "here" ("… a tube of toothpaste
        // here.", "… an old trunk here, bulging with …"); one that opens by
        // saying a thing exists ("There is a golden clockwork canary nestled
        // in the egg."); a posture ("… is lying in the corner."); and one that
        // opens with a place and then puts the thing in it ("On the table is a
        // sack.", "Above the trophy case hangs a sword."). The last needs the
        // verb list because the sources write the inversion several ways.
        let locative = try Regex(
            #"(?i)\bhere[.,]|^there (is|are) (a|an|some)\b|\bis (lying|sitting|suspended|hanging)\b"#
                + #"|^(on|above|at the end of|beside|from|in) (the|a|an) .+\b(is|are|hangs|stands|lies|sits)\b"#
        )

        var offenders: [String] = []
        for (title, definition) in try ShippedGames.definitions() {
            for (id, item) in definition.items
            where item.isTakable && !neverCarried.contains("\(title)/\(id)")
                && item.descriptionTexts.contains(where: { $0.contains(locative) })
            {
                offenders.append("\(title)/\(id)")
            }
        }

        #expect(offenders.isEmpty, "these examine texts are listing lines: \(offenders.sorted())")
    }
}
