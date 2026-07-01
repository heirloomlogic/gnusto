/// The one shared computation of "which items can the player see or reach
/// here" — used by the parser's scope, the room describer, and any default
/// action that needs to walk placements. Pure functions over a definition and
/// a state snapshot; callers hold whatever lock they need before calling in.
enum Visibility {
    /// Items the player can currently perceive: carried items always, plus —
    /// with light — the room's direct contents and one surface/container
    /// level deep. Mirrors the classic IF "scope" rule.
    ///
    /// Today identical to `reachableItems`; the split exists so a later
    /// container model (closed/transparent) can diverge them — e.g. an item
    /// visible through glass but not reachable while the lid is shut.
    static func visibleItems(
        at location: EntityID,
        definition: GameDefinition,
        state: WorldState
    ) -> Set<EntityID> {
        var visible: Set<EntityID> = []

        for (id, placement) in state.placements where placement == .heldBy(.player) {
            visible.insert(id)
        }

        if !isDark(at: location, definition: definition, state: state) {
            for (id, placement) in state.placements {
                switch placement {
                case .room(location):
                    visible.insert(id)
                case .on(let surface) where state.placements[surface] == .room(location):
                    visible.insert(id)
                case .inside(let container) where state.placements[container] == .room(location):
                    visible.insert(id)
                default:
                    break
                }
            }
        }

        return visible
    }

    /// Items the player can currently manipulate. Today identical to
    /// `visibleItems`; will diverge once closed containers make some items
    /// visible but not reachable.
    static func reachableItems(
        at location: EntityID,
        definition: GameDefinition,
        state: WorldState
    ) -> Set<EntityID> {
        visibleItems(at: location, definition: definition, state: state)
    }

    /// The one darkness predicate, shared by the room describer, the parser
    /// scope, and the perception defaults.
    /// Seam: when light-providing items exist, check their presence here.
    static func isDark(
        at location: EntityID,
        definition: GameDefinition,
        state: WorldState
    ) -> Bool {
        !state.litRooms.contains(location)
    }
}
