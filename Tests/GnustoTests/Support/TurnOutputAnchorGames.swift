import Gnusto

// MARK: - QuotingLab

/// Exercises the anchoring in ``turnOutput(of:in:)``/``turnOutput(ofLast:in:)``:
/// a room description quotes a command with the two-space form CLAUDE.md
/// documents for a form-text line, so an unanchored search for `"> look\n"`
/// finds it before it finds a real prompt.
struct QuotingLab: Game {
    let title = "Quoting Lab"
    let intro = "A sign."

    let lab = Location {
        name("Lab")
        description(
            """
            A lab. The sign reads:

              > look
              Nothing happens.
            """)
    }

    var map: WorldMap { player.starts(in: lab) }
}
