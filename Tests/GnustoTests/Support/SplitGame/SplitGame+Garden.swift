import Gnusto

/// The garden region of ``SplitGame``: its geography fragment and its rules,
/// defined in a file separate from the main struct. The bare identifiers
/// (`garden`, `rose`, `player`, `rosesPicked`) resolve to the stored
/// declarations and engine globals exactly as they would inside the struct.
extension SplitGame {
    @MapBuilder var gardenMap: WorldMap {
        garden.east(cottage)
        rose.starts(in: garden)
    }

    @RuleBuilder var gardenRules: Rules {
        rose.before(.examine) {
            try reply("[garden] The rose is crimson and full.")
        }
        rose.after(.take) {
            rosesPicked += 1
        }
    }
}
