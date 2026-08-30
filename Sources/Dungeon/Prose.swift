/// Every line of prose in the game, gathered as named constants.
///
/// **Dungeon adapts; it does not reproduce.** That is the sharpest difference
/// from `Sources/Zork1/`, which reproduces the original Zork I text verbatim
/// throughout and says so in `THIRD_PARTY_NOTICES`. Here, each line is one of:
///
/// 1. the **Zork I/II/III line verbatim**, where the trilogy's room or object
///    is the same one the mainframe has (MIT-licensed);
/// 2. the **trilogy line adapted** — its voice kept, its facts corrected
///    against the mainframe's exit table, because the trilogy usually rewrote
///    the prose *because* it had rewritten the room;
/// 3. **written fresh** in the Infocom register, for mainframe-only content.
///
/// **No 1981 MDL text is reproduced anywhere.** The 1981 source is consulted
/// for structure only — map topology, exit tables, point values, object
/// properties, puzzle logic — which is the limit `THIRD_PARTY_NOTICES` records
/// for it. `FIDELITY.md`'s Dungeon section states this rule ahead of any region
/// entry, and `docs/games/dungeon-prose-comparison.md` is the per-line
/// authority.
///
/// **Prose is filed by the region it reads in, not by the type that wires it.**
/// The troll's refusal is in `Regions/Prose+Cellar.swift` even though the host
/// declares the exit; the canary's song is in `Regions/Prose+AboveGround.swift`
/// even though the host owns the trick. `Prose+Systems.swift` holds what belongs
/// to no region — the front matter, the verb defaults, the liquids — and this
/// file holds the two lines that belong to no region and to no one villain or
/// room: the grue's, and the one the melee mechanism prints over every villain.
///
/// Every `Prose+*.swift` cites this doc comment for the three-way rule rather
/// than restating it.
enum Prose {
    // MARK: - The grue

    static let grueWarning = """
        It is pitch black. You are likely to be eaten by a grue.
        """

    static let grueDeath = """
        Oh, no! You have walked into the slavering fangs of a lurking grue!
        """

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
