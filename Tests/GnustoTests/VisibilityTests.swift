import Testing

@testable import Gnusto

/// The visibility set with a containment index built fresh from the state —
/// these unit tests exercise the walk, not `WorldState`'s per-turn cache, so
/// they build the index inline rather than threading one through.
private func visibleItems(
    at location: EntityID, definition: GameDefinition, state: WorldState
) -> Set<EntityID> {
    Visibility.visibleItems(
        at: location, definition: definition, state: state,
        index: ContainmentIndex(placements: state.placements))
}

/// The reachable set, built the same way as `visibleItems` above.
private func reachableItems(
    at location: EntityID, definition: GameDefinition, state: WorldState
) -> Set<EntityID> {
    Visibility.reachableItems(
        at: location, definition: definition, state: state,
        index: ContainmentIndex(placements: state.placements))
}

/// Unit tests for the shared visibility computation, independent of the turn
/// pipeline. `MiniGame` already places a book directly in the den, a coin on
/// the den's table, a hat held by the player, and a dark cellar — exactly the
/// four cases this harness needs, and the ones Task 3 will extend.
struct VisibilityTests {
    @Test func itemDirectlyInARoomIsVisible() throws {
        let (definition, state) = try Bootstrap.build(MiniGame())
        let visible = visibleItems(
            at: EntityID("den"), definition: definition, state: state)
        #expect(visible.contains(EntityID("book")))
    }

    @Test func itemOnASurfaceIsVisible() throws {
        let (definition, state) = try Bootstrap.build(MiniGame())
        let visible = visibleItems(
            at: EntityID("den"), definition: definition, state: state)
        #expect(visible.contains(EntityID("coin")))
    }

    @Test func heldItemIsAlwaysVisible() throws {
        let (definition, state) = try Bootstrap.build(MiniGame())
        let visible = visibleItems(
            at: EntityID("den"), definition: definition, state: state)
        #expect(visible.contains(EntityID("hat")))
    }

    @Test func darkRoomHidesEverythingButHeldItems() throws {
        let (definition, state) = try Bootstrap.build(MiniGame())
        let visible = visibleItems(
            at: EntityID("cellar"), definition: definition, state: state)
        #expect(visible == [EntityID("hat")])
    }

    @Test func reachableItemsMatchesVisibleItemsToday() throws {
        let (definition, state) = try Bootstrap.build(MiniGame())
        for location in [EntityID("den"), EntityID("cellar")] {
            let visible = visibleItems(
                at: location, definition: definition, state: state)
            let reachable = reachableItems(
                at: location, definition: definition, state: state)
            #expect(reachable == visible)
        }
    }

    @Test func isDarkReflectsLitRooms() throws {
        let (definition, state) = try Bootstrap.build(MiniGame())
        #expect(!Visibility.isDark(at: EntityID("den"), definition: definition, state: state))
        #expect(Visibility.isDark(at: EntityID("cellar"), definition: definition, state: state))
    }

    // MARK: - Container recursion (Task 3)

    private func pantry() throws -> (GameDefinition, WorldState) {
        try Bootstrap.build(PantryGame())
    }

    /// Closed opaque crate: its can is neither visible nor reachable.
    @Test func closedOpaqueContainerHidesContents() throws {
        let (definition, state) = try pantry()
        let visible = visibleItems(
            at: EntityID("pantry"), definition: definition, state: state)
        let reachable = reachableItems(
            at: EntityID("pantry"), definition: definition, state: state)
        #expect(!visible.contains(EntityID("can")))
        #expect(!reachable.contains(EntityID("can")))
        // The crate itself is visible and reachable.
        #expect(visible.contains(EntityID("crate")))
        #expect(reachable.contains(EntityID("crate")))
    }

    /// Open opaque crate: its can is both visible and reachable.
    @Test func openOpaqueContainerRevealsContents() throws {
        var (definition, state) = try pantry()
        state.openItems.insert(EntityID("crate"))
        let visible = visibleItems(
            at: EntityID("pantry"), definition: definition, state: state)
        let reachable = reachableItems(
            at: EntityID("pantry"), definition: definition, state: state)
        #expect(visible.contains(EntityID("can")))
        #expect(reachable.contains(EntityID("can")))
    }

    /// Closed transparent jar: pickle is visible but NOT reachable.
    @Test func closedTransparentContainerShowsButBlocksContents() throws {
        let (definition, state) = try pantry()
        let visible = visibleItems(
            at: EntityID("pantry"), definition: definition, state: state)
        let reachable = reachableItems(
            at: EntityID("pantry"), definition: definition, state: state)
        #expect(visible.contains(EntityID("pickle")))
        #expect(!reachable.contains(EntityID("pickle")))
    }

    /// Open transparent jar: pickle is visible and reachable.
    @Test func openTransparentContainerAllowsContents() throws {
        var (definition, state) = try pantry()
        state.openItems.insert(EntityID("jar"))
        let reachable = reachableItems(
            at: EntityID("pantry"), definition: definition, state: state)
        #expect(reachable.contains(EntityID("pickle")))
    }

    /// A container with no `openable` is always open: apple visible & reachable.
    @Test func alwaysOpenContainerRevealsContents() throws {
        let (definition, state) = try pantry()
        let visible = visibleItems(
            at: EntityID("pantry"), definition: definition, state: state)
        let reachable = reachableItems(
            at: EntityID("pantry"), definition: definition, state: state)
        #expect(visible.contains(EntityID("apple")))
        #expect(reachable.contains(EntityID("apple")))
    }

    /// Deep recursion: bottle inside an open sack inside the always-open basket
    /// is visible and reachable.
    @Test func deepRecursionThroughOpenContainers() throws {
        let (definition, state) = try pantry()
        let visible = visibleItems(
            at: EntityID("pantry"), definition: definition, state: state)
        let reachable = reachableItems(
            at: EntityID("pantry"), definition: definition, state: state)
        #expect(visible.contains(EntityID("sack")))
        #expect(visible.contains(EntityID("bottle")))
        #expect(reachable.contains(EntityID("bottle")))
    }

    /// If an intermediate container is closed-opaque, deeper contents vanish.
    @Test func closedIntermediateContainerHidesDeepContents() throws {
        var (definition, state) = try pantry()
        // Close the sack (which starts open); bottle should disappear.
        state.openItems.remove(EntityID("sack"))
        let visible = visibleItems(
            at: EntityID("pantry"), definition: definition, state: state)
        #expect(visible.contains(EntityID("sack")))
        #expect(!visible.contains(EntityID("bottle")))
    }

    /// A runtime-created placement cycle must not send the recursive descent
    /// into an infinite loop.
    ///
    /// `WorldState.placements` is a `[EntityID: Placement]` dictionary, so an
    /// item has exactly one placement at a time — which means a cycle
    /// reachable from a room/held root is not constructible through the
    /// normal placement API (every member of a cycle would need an
    /// `.inside`/`.on` placement pointing to the next member, which leaves
    /// none of them able to also declare `.room`/`.heldBy(.player)`). That
    /// invariant is exactly why the model has stayed cycle-free so far. This
    /// test targets the walk's robustness if that invariant is ever broken
    /// anyway — by a hand-edited save file, a future direct-placement API, or
    /// a bug — by wiring two containers into a mutual cycle and confirming
    /// `visibleItems`/`reachableItems` still return promptly rather than
    /// recursing forever.
    @Test func placementCycleDoesNotInfiniteLoopTheWalk() throws {
        var (definition, state) = try pantry()
        state.place(EntityID("crate"), .inside(EntityID("can")))
        state.place(EntityID("can"), .inside(EntityID("crate")))
        state.openItems.insert(EntityID("crate"))

        // The call itself returning is the assertion: without the
        // visited-set guard in `Visibility.descend`, a walk that ever
        // reached this pair would recurse forever.
        let visible = visibleItems(
            at: EntityID("pantry"), definition: definition, state: state)
        let reachable = reachableItems(
            at: EntityID("pantry"), definition: definition, state: state)

        // Orphaned from every room/held root (by construction, per the note
        // above), the cycle pair is simply absent from both sets — the rest
        // of the pantry is unaffected.
        #expect(!visible.contains(EntityID("crate")))
        #expect(!visible.contains(EntityID("can")))
        #expect(visible.contains(EntityID("basket")))
        #expect(reachable.contains(EntityID("basket")))
    }
}
