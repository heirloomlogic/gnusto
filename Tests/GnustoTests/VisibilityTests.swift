import Testing

@testable import Gnusto

/// Unit tests for the shared visibility computation, independent of the turn
/// pipeline. `MiniGame` already places a book directly in the den, a coin on
/// the den's table, a hat held by the player, and a dark cellar — exactly the
/// four cases this harness needs, and the ones Task 3 will extend.
struct VisibilityTests {
    @Test func itemDirectlyInARoomIsVisible() throws {
        let (definition, state) = try Bootstrap.build(MiniGame())
        let visible = Visibility.visibleItems(
            at: EntityID("den"), definition: definition, state: state)
        #expect(visible.contains(EntityID("book")))
    }

    @Test func itemOnASurfaceIsVisible() throws {
        let (definition, state) = try Bootstrap.build(MiniGame())
        let visible = Visibility.visibleItems(
            at: EntityID("den"), definition: definition, state: state)
        #expect(visible.contains(EntityID("coin")))
    }

    @Test func heldItemIsAlwaysVisible() throws {
        let (definition, state) = try Bootstrap.build(MiniGame())
        let visible = Visibility.visibleItems(
            at: EntityID("den"), definition: definition, state: state)
        #expect(visible.contains(EntityID("hat")))
    }

    @Test func darkRoomHidesEverythingButHeldItems() throws {
        let (definition, state) = try Bootstrap.build(MiniGame())
        let visible = Visibility.visibleItems(
            at: EntityID("cellar"), definition: definition, state: state)
        #expect(visible == [EntityID("hat")])
    }

    @Test func reachableItemsMatchesVisibleItemsToday() throws {
        let (definition, state) = try Bootstrap.build(MiniGame())
        for location in [EntityID("den"), EntityID("cellar")] {
            let visible = Visibility.visibleItems(
                at: location, definition: definition, state: state)
            let reachable = Visibility.reachableItems(
                at: location, definition: definition, state: state)
            #expect(reachable == visible)
        }
    }

    @Test func isDarkReflectsLitRooms() throws {
        let (definition, state) = try Bootstrap.build(MiniGame())
        #expect(!Visibility.isDark(at: EntityID("den"), definition: definition, state: state))
        #expect(Visibility.isDark(at: EntityID("cellar"), definition: definition, state: state))
    }
}
