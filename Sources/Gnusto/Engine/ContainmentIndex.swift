/// The placement graph grouped by parent, built once and read many times a
/// turn. Every visibility walk, room listing, and proxy accessor needs "what
/// is on / in / held by / directly in this entity"; computing that from the
/// flat `placements` dictionary is an O(n) scan, and the engine did it three
/// or four times per turn. This index does the scan once, and `WorldState`
/// caches it until the next placement write.
///
/// Buckets are keyed by the parent entity and sorted by `EntityID`, so a
/// caller that needs a stable listing can read a bucket directly instead of
/// re-sorting. The index is a pure function of `placements`: nothing else in
/// the state affects it, which is why the cache is invalidated only when a
/// placement changes.
struct ContainmentIndex: Sendable {
    /// Items resting on each surface, keyed by the surface's ID.
    let onSurface: [EntityID: [EntityID]]
    /// Items inside each container, keyed by the container's ID.
    let inContainer: [EntityID: [EntityID]]
    /// Items held by each holder (the player or an actor), keyed by holder ID.
    let held: [EntityID: [EntityID]]
    /// Items lying directly in each room, keyed by the room's ID.
    let inRoom: [EntityID: [EntityID]]

    /// Groups every placement by its parent in one O(n) pass, then sorts each
    /// bucket by `EntityID` for stable listings. `.nowhere` items belong to no
    /// bucket.
    ///
    /// - Parameter placements: the flat item-to-placement map to index.
    init(placements: [EntityID: Placement]) {
        var onSurface: [EntityID: [EntityID]] = [:]
        var inContainer: [EntityID: [EntityID]] = [:]
        var held: [EntityID: [EntityID]] = [:]
        var inRoom: [EntityID: [EntityID]] = [:]
        for (id, placement) in placements {
            switch placement {
            case .on(let parent): onSurface[parent, default: []].append(id)
            case .inside(let parent): inContainer[parent, default: []].append(id)
            case .heldBy(let holder): held[holder, default: []].append(id)
            case .room(let room): inRoom[room, default: []].append(id)
            case .nowhere: break
            }
        }
        for key in onSurface.keys { onSurface[key]?.sort() }
        for key in inContainer.keys { inContainer[key]?.sort() }
        for key in held.keys { held[key]?.sort() }
        for key in inRoom.keys { inRoom[key]?.sort() }
        self.onSurface = onSurface
        self.inContainer = inContainer
        self.held = held
        self.inRoom = inRoom
    }

    /// Everything the entity holds through containment: what rests on it (a
    /// surface's items) followed by what sits inside it (a container's
    /// contents). Each half is `EntityID`-sorted; the concatenation is not, so
    /// a caller that needs a single sorted listing must sort the result.
    ///
    /// - Parameter id: the surface/container to read.
    /// - Returns: its surface items followed by its inside items.
    func children(of id: EntityID) -> [EntityID] {
        (onSurface[id] ?? []) + (inContainer[id] ?? [])
    }
}
