/// Every description string in the game, gathered as named constants.
///
/// **Placeholder prose only.** Every line here is original text written for
/// this slice — it conveys the same facts a description needs to (what's
/// here, which exits lead where, what's worth touching) without reusing or
/// lightly rewording Infocom's copyrighted room and item text. Room and item
/// *names* are the iconic proper nouns ("West of House", "brass lantern"),
/// which are fine; the prose describing them is not. A later pass can drop
/// in verbatim text by editing exactly one constant per entity — see
/// `FIDELITY.md` at the repo root.
///
/// The constants are split across files by region for locality: the exterior
/// lives in `Prose+AboveGround.swift`, the interior in `Prose+House.swift`,
/// the cellar and its inhabitants in `Prose+Cellar.swift`, and the systems
/// layer (custom verbs, score ranks, liquids) in `Prose+Systems.swift`. This
/// file holds only the truly shared prose the host wires directly — the grue.
enum Prose {
    // MARK: - The grue
    //
    // Original prose only: the famous "likely to be eaten by a grue"
    // sentence is Infocom's and is deliberately not reproduced. The name
    // "grue" itself is fair game under the ledger's names-vs-prose line.

    static let grueWarning = """
        The darkness here is total. Something with slow, wet breathing
        has noticed you.
        """

    static let grueDeath = """
        Claws find you long before your eyes could ever adjust. You are
        devoured by a grue.
        """
}
