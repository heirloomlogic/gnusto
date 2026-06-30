import Gnusto

/// A worked example proving a single game can be authored across several
/// files.
///
/// Entity declarations (locations, items, `@Global` state) must stay in this
/// primary struct body — Swift requires stored properties in the type's main
/// declaration, and the bootstrap discovers them by reflecting over this one
/// type. Everything else composes: `map` and `rules` are built from helper
/// properties defined in `SplitGame+Garden.swift` and `SplitGame+House.swift`,
/// so a large game's geography and logic can be split file-by-file by region.
struct SplitGame: Game {
    let title = "Split"
    let intro = "Split."

    // MARK: - Declarations (must live in the struct body)

    let garden = Location {
        name("Walled Garden")
        description("A walled garden, open to the sky.")
    }

    let cottage = Location {
        name("Cottage")
        description("A snug stone cottage.")
    }

    let rose = Item {
        name("crimson rose")
        adjectives("crimson", "red")
        description("A single crimson rose.")
    }

    let key = Item {
        name("brass key")
        adjectives("brass")
        description("A small brass key.")
    }

    @Global var rosesPicked = 0

    // MARK: - Composition (each region defined in its own file)

    /// Geography composed from per-region fragments plus the player start.
    var map: WorldMap {
        gardenMap
        houseMap
        player.starts(in: garden)
    }

    /// Logic composed from per-region rule groups.
    var rules: Rules {
        gardenRules
        houseRules
    }
}
