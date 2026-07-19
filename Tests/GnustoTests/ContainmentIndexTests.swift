import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto

/// The containment index: bucket grouping and sort order, `children(of:)`
/// merge semantics, the `WorldState` cache and its invalidation, and the
/// guarantees callers depend on — intra-turn freshness after a placement
/// write, and the cache staying out of the save format.
struct ContainmentIndexTests {
    // MARK: - Bucketing

    /// Every placement lands in the bucket for its kind, keyed by its parent,
    /// and `.nowhere` items land nowhere.
    @Test func placementsGroupIntoBucketsByKind() throws {
        let index = ContainmentIndex(placements: [
            EntityID("apple"): .on(EntityID("table")),
            EntityID("crumb"): .inside(EntityID("table")),
            EntityID("can"): .inside(EntityID("box")),
            EntityID("torch"): .heldBy(.player),
            EntityID("axe"): .heldBy(EntityID("troll")),
            EntityID("rug"): .room(EntityID("den")),
            EntityID("ghost"): .nowhere,
        ])

        #expect(index.onSurface[EntityID("table")] == [EntityID("apple")])
        #expect(index.inContainer[EntityID("table")] == [EntityID("crumb")])
        #expect(index.inContainer[EntityID("box")] == [EntityID("can")])
        #expect(index.held[.player] == [EntityID("torch")])
        #expect(index.held[EntityID("troll")] == [EntityID("axe")])
        #expect(index.inRoom[EntityID("den")] == [EntityID("rug")])

        // A `.nowhere` item is in no bucket at all.
        #expect(index.onSurface[EntityID("ghost")] == nil)
        #expect(index.inContainer[EntityID("ghost")] == nil)
        #expect(index.held[EntityID("ghost")] == nil)
        #expect(index.inRoom[EntityID("ghost")] == nil)
    }

    /// Each bucket is sorted by `EntityID`, regardless of insertion order.
    @Test func bucketsAreSortedByID() throws {
        let index = ContainmentIndex(placements: [
            EntityID("cherry"): .room(EntityID("den")),
            EntityID("apple"): .room(EntityID("den")),
            EntityID("banana"): .room(EntityID("den")),
        ])
        #expect(
            index.inRoom[EntityID("den")]
                == [EntityID("apple"), EntityID("banana"), EntityID("cherry")])
    }

    /// `children(of:)` is the surface bucket followed by the container bucket —
    /// each half sorted, the concatenation not necessarily globally sorted.
    @Test func childrenMergesSurfaceThenContainer() throws {
        let index = ContainmentIndex(placements: [
            EntityID("plate"): .on(EntityID("shelf")),
            EntityID("mug"): .on(EntityID("shelf")),
            EntityID("ant"): .inside(EntityID("shelf")),
        ])
        // Surface half [mug, plate] (sorted), then container half [ant] —
        // "ant" sorts first overall but comes last, proving the two halves
        // are concatenated rather than merge-sorted.
        #expect(
            index.children(of: EntityID("shelf"))
                == [EntityID("mug"), EntityID("plate"), EntityID("ant")])
    }

    /// A parent with nothing on or in it has no children.
    @Test func childrenOfEmptyParentIsEmpty() throws {
        let index = ContainmentIndex(placements: [:])
        #expect(index.children(of: EntityID("void")).isEmpty)
    }

    // MARK: - Cache

    /// `containment()` rebuilds after `place(_:_:)` — the write funnel drops
    /// the cache, so the next read sees the new placement rather than a stale
    /// bucket.
    @Test func cacheInvalidatesAfterPlace() throws {
        var state = WorldState(
            playerLocation: EntityID("room"),
            placements: [EntityID("gem"): .room(EntityID("room"))])

        let before = state.containment()
        #expect(before.inRoom[EntityID("room")] == [EntityID("gem")])
        #expect(before.held[.player] == nil)

        state.place(EntityID("gem"), .heldBy(.player))

        let after = state.containment()
        #expect(after.inRoom[EntityID("room")] == nil)
        #expect(after.held[.player] == [EntityID("gem")])
    }

    // MARK: - Engine-level freshness

    /// A rule that moves an item and then reads a container's contents in the
    /// same turn sees the move immediately — the move goes through `place`,
    /// which invalidates the cache the earlier read populated.
    @Test func moveIsVisibleToContentsSameTurn() async throws {
        struct FreshnessGame: Game {
            let title = "Freshness"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
            }
            let box = Item {
                name("box")
                container
            }
            let coin = Item {
                name("coin")
            }
            let lever = Item {
                name("lever")
                scenery
            }
            var map: WorldMap {
                player.starts(in: room)
                box.starts(in: room)
                coin.startsHeld
                lever.starts(in: room)
            }
            var rules: Rules {
                lever.before(.examine) {
                    // Read first, populating this turn's containment cache
                    // while the box is still empty.
                    let before = box.contents.map(\.name).joined(separator: ",")
                    // Move goes through `place`, invalidating that cache.
                    coin.move(inside: box)
                    // The re-read must rebuild and see the coin.
                    let after = box.contents.map(\.name).joined(separator: ",")
                    try reply("before=[\(before)] after=[\(after)]")
                }
            }
        }

        let transcript = try await play(FreshnessGame(), ["examine lever"])
        let turn = turnOutput(of: "examine lever", in: transcript)
        #expect(turn.contains("before=[] after=[coin]"))
    }

    // MARK: - Save format

    /// The derived cache never reaches the save format: encoding a state whose
    /// cache has been built emits no `containmentCache` key.
    @Test func cacheIsNotEncoded() throws {
        var (_, state) = try Bootstrap.build(MiniGame())
        // Force the cache to exist before encoding.
        _ = state.containment()

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(state)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(!json.contains("containmentCache"))
        // Sanity: the real placement key is present, so we encoded the state.
        #expect(json.contains("placements"))
    }
}
