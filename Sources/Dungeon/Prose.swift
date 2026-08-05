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
/// file holds what belongs to no region *and* no system.
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
}
