import Gnusto

/// Every description string in the game, gathered as named constants.
///
/// These are the original Zork I room and item descriptions, transcribed from
/// the MIT-licensed historical Zork source — see `THIRD_PARTY_NOTICES` at the
/// repo root for the license and attribution.
///
/// The constants are split across files by region for locality: the exterior
/// lives in `Prose+AboveGround.swift`, the interior in `Prose+House.swift`,
/// the cellar and its inhabitants in `Prose+Cellar.swift`, and the systems
/// layer (custom verbs, score ranks, liquids) in `Prose+Systems.swift`. This
/// file holds the prose that belongs to no region: the grue, and the sentence
/// the melee mechanism prints over every villain it removes.
enum Prose {
    // MARK: - The grue

    static let grueWarning = """
        It is pitch black. You are likely to be eaten by a grue.
        """

    /// Verbatim (`gverbs.zil:2110-2114`), and the *second* of
    /// the source's two grue deaths — the one that fits this mechanic. See
    /// `DangerousDark.timers` for which and why. (#350)
    static let grueDeath = GameText.Line<GameText.Noun?>.naming(
        orBare: "Oh, no! A lurking grue slithered into the room and devoured you!"
    ) {
        "Oh, no! A lurking grue slithered into \($0) and devoured you!"
    }

    // MARK: - The melee mechanism's own line

    /// Verbatim (Zork I `1actions.zil:3568`; the mainframe's is byte-identical
    /// at `melee.137:274`, so both grants that cover prose carry it and no 1981
    /// text is reproduced).
    ///
    /// `VILLAIN-RESULT` prints three things in order and this is the second:
    /// the melee table's fatal-blow line, **this**, then `REMOVE-CAREFULLY` and
    /// the villain's own `F-DEAD`. It belongs to the mechanism rather than to
    /// any one villain, which is why it takes a name instead of being written
    /// into each villain's death line.
    ///
    /// - Parameter villain: the villain's **rendered definite phrase** — "the
    ///   thief", not "thief". The sentence supplies no article of its own.
    /// - Returns: the disposal sentence, naming that villain.
    ///
    /// It is what accounts for the body. `MeleeCombat` removes the actor the
    /// same way `REMOVE-CAREFULLY` does, so a death line that leaves a villain
    /// slumped on the floor and stops there leaves a corpse the world does not
    /// hold: one turn later `x thief` and `x body` both refuse and LOOK lists
    /// nothing. (#350)
    static func carcassVanishes(_ villain: String) -> String {
        """
        Almost as soon as \(villain) breathes his last breath, a cloud of
        sinister black fog envelops him, and when the fog lifts, the carcass has
        disappeared.
        """
    }
}
