@testable import Gnusto

extension GameWorld {
    func vanishForTrollAxeRegression(_ rawID: String) {
        state.place(EntityID(rawID), .nowhere)
    }

    func placementForTrollAxeRegression(_ rawID: String) -> Placement? {
        state.placements[EntityID(rawID)]
    }
}
