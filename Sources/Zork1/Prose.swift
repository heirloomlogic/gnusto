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
/// file holds only the truly shared prose the host wires directly — the grue.
enum Prose {
    // MARK: - The grue

    static let grueWarning = """
        It is pitch black. You are likely to be eaten by a grue.
        """

    static let grueDeath = """
        Oh, no! You have walked into the slavering fangs of a lurking grue!
        """
}
