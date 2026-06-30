import Gnusto

/// The house region of ``SplitGame``: a third file contributing its own
/// geography fragment and rules to the same game. Its `houseMap` and
/// `houseRules` are spliced into the struct's `map` and `rules` alongside the
/// garden region's, proving fragments from any number of files combine.
extension SplitGame {
    @MapBuilder var houseMap: WorldMap {
        cottage.west(garden)
        key.starts(in: cottage)
    }

    @RuleBuilder var houseRules: Rules {
        key.before(.examine) {
            try reply("[house] A small brass key, worn smooth.")
        }
    }
}
