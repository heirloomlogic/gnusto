import Gnusto

/// The grating's key doesn't exist yet in this slice — the maze that hides
/// it is Phase 7 content, but `lockable(with:)` still needs a real,
/// bootstrap-registered `Item` to point at (an unresolvable key is a fatal
/// diagnostic, same as a dangling door). The file-scope `let` is the usual
/// `lockable(with:)` workaround — a stored-property initializer can't
/// reference a sibling stored property — and ``ZorkAboveGround`` also holds
/// it as its own stored property (`skeletonKey`, below) so Bootstrap's
/// reflection actually discovers and registers it as a declared item. It is
/// simply never placed in `map`, which resolves to `.nowhere`: a declared
/// but unplaced item is legal (every item defaults to `.nowhere` unless a
/// `map` entry says otherwise), so the key exists as a future pickup with no
/// stub room required.
private let skeletonKeyItem = Item {
    name("skeleton key")
}

/// The forest/house/canyon region of the map: the White House exterior, the
/// woods around it, and the canyon beyond — everything above ground in this
/// slice. `ZorkHouse` (the interior) and this bundle meet at the kitchen
/// window and are wired together by the host, ``Zork1``.
struct ZorkAboveGround: GameContent {
    // MARK: - House exterior

    let westOfHouse = Location {
        name("West of House")
        description(Prose.westOfHouse)
    }

    let northOfHouse = Location {
        name("North of House")
        description(Prose.northOfHouse)
    }

    let southOfHouse = Location {
        name("South of House")
        description(Prose.southOfHouse)
    }

    let behindHouse = Location {
        name("Behind House")
        description(Prose.behindHouse)
    }

    // Examinable from all four house-side rooms. A single `Item` only ever
    // occupies one place (the last `starts(in:)` for a token wins — see
    // `FIDELITY.md`), so "the house is examinable everywhere around it"
    // needs one scenery item per room rather than one item placed four
    // times; all four share the same name and `Prose.whiteHouse` text so
    // they read as the same house.
    let whiteHouseAtWest = Item {
        name("white house")
        adjectives("white")
        description(Prose.whiteHouse)
        scenery
    }

    let whiteHouseAtNorth = Item {
        name("white house")
        adjectives("white")
        description(Prose.whiteHouse)
        scenery
    }

    let whiteHouseAtSouth = Item {
        name("white house")
        adjectives("white")
        description(Prose.whiteHouse)
        scenery
    }

    let whiteHouseAtBehind = Item {
        name("white house")
        adjectives("white")
        description(Prose.whiteHouse)
        scenery
    }

    /// Nailed shut: opening it always refuses, so the only way into the
    /// house in this slice is the kitchen window `ZorkHouse` owns.
    let frontDoor = Item {
        name("front door")
        adjectives("front")
        description(Prose.frontDoor)
        scenery
    }

    let mailbox = Item {
        name("small mailbox")
        adjectives("small")
        description(Prose.mailbox)
        container
        openable
        scenery
    }

    let leaflet = Item {
        name("leaflet")
        description(Prose.leaflet)
    }

    // MARK: - Forest & clearings

    let forestWest = Location {
        name("Forest")
        description(Prose.forestWest)
    }

    let forestEast = Location {
        name("Forest")
        description(Prose.forestEast)
    }

    let forestNortheast = Location {
        name("Forest")
        description(Prose.forestNortheast)
    }

    let forestPath = Location {
        name("Forest Path")
        description(Prose.forestPath)
    }

    let upATree = Location {
        name("Up a Tree")
        description(Prose.upATree)
    }

    /// Scenery in `forestPath`; climbing it is just the `up` exit to
    /// `upATree` for now (see `FIDELITY.md` — a dedicated `climb` verb is
    /// future work).
    let tree = Item {
        name("large tree")
        adjectives("large", "gnarled")
        description(Prose.tree)
        scenery
    }

    let nest = Item {
        name("nest")
        description(Prose.nest)
        surface
        scenery
    }

    /// Shared with `ZorkHouse.trophyCase`'s closure description — see
    /// `House.swift`'s file-scope `zork1Egg`, which this aliases, for why
    /// the shared identity lives at file scope rather than being injected.
    let egg = zork1Egg

    let clearingGrating = Location {
        name("Clearing")
        description(Prose.clearingGrating)
    }

    /// Pushing the leaves reveals the grating — the Task 4 push-to-reveal
    /// pattern (`before(.push)` + `reply`, not `after`, so the stock "You
    /// can't move that." never prints ahead of the reveal line).
    let leaves = Item {
        name("pile of leaves")
        adjectives("dead")
        description(Prose.leaves)
        scenery
    }

    /// Openable and lockable with `skeletonKey` below, so it starts (and
    /// stays) locked: `open grating` refuses with the built-in "is locked"
    /// message with no rule of our own needed.
    let grating = Item {
        name("iron grating")
        adjectives("iron", "metal")
        description(Prose.grating)
        container
        openable
        lockable(with: skeletonKeyItem)
        scenery
        hidden
    }

    /// The grating's key — registered with Bootstrap so `lockable(with:)`
    /// above resolves, but not placed anywhere in `map`: it's future pickup
    /// for the maze phase, not a fixture of this slice. See
    /// `skeletonKeyItem`'s doc comment at the top of the file.
    let skeletonKey = skeletonKeyItem

    let clearingEast = Location {
        name("Clearing")
        description(Prose.clearingEast)
    }

    // MARK: - Canyon

    let canyonView = Location {
        name("Canyon View")
        description(Prose.canyonView)
    }

    let rockyLedge = Location {
        name("Rocky Ledge")
        description(Prose.rockyLedge)
    }

    let canyonBottom = Location {
        name("Canyon Bottom")
        description(Prose.canyonBottom)
    }

    let endOfRainbow = Location {
        name("End of Rainbow")
        description(Prose.endOfRainbow)
    }

    // MARK: - Map

    var map: WorldMap {
        // House exterior ring.
        westOfHouse.north(northOfHouse)
        westOfHouse.south(southOfHouse)
        westOfHouse.west(forestWest)
        northOfHouse.west(westOfHouse)
        northOfHouse.east(behindHouse)
        northOfHouse.north(forestPath)
        southOfHouse.west(westOfHouse)
        southOfHouse.east(behindHouse)
        behindHouse.north(northOfHouse)
        behindHouse.south(southOfHouse)
        behindHouse.east(forestEast)

        // Forest & clearings.
        forestWest.east(westOfHouse)
        forestWest.north(forestPath)
        forestPath.south(northOfHouse)
        forestPath.north(clearingGrating)
        forestPath.up(upATree)
        upATree.down(forestPath)
        clearingGrating.south(forestPath)
        clearingGrating.east(clearingEast)
        clearingEast.west(clearingGrating)
        clearingEast.south(forestEast)
        forestEast.west(behindHouse)
        forestEast.north(clearingEast)
        forestEast.east(forestNortheast)
        forestNortheast.south(forestEast)
        forestNortheast.west(forestWest)

        // Canyon. A faithful map has no way back up the canyon wall without
        // climbing gear this slice doesn't model yet, but a dead-end branch
        // makes the slice itself untestable as a loop — so, simplification
        // noted in FIDELITY.md, every leg here is two-way for now.
        forestEast.exit(.southeast, to: canyonView)
        canyonView.exit(.northwest, to: forestEast)
        canyonView.down(rockyLedge)
        rockyLedge.up(canyonView)
        rockyLedge.down(canyonBottom)
        canyonBottom.up(rockyLedge)
        canyonBottom.north(endOfRainbow)
        endOfRainbow.south(canyonBottom)

        // Entities.
        whiteHouseAtWest.starts(in: westOfHouse)
        whiteHouseAtNorth.starts(in: northOfHouse)
        whiteHouseAtSouth.starts(in: southOfHouse)
        whiteHouseAtBehind.starts(in: behindHouse)
        frontDoor.starts(in: westOfHouse)
        mailbox.starts(in: westOfHouse)
        leaflet.starts(inside: mailbox)

        tree.starts(in: forestPath)
        nest.starts(in: upATree)
        egg.starts(on: nest)

        leaves.starts(in: clearingGrating)
        grating.starts(in: clearingGrating)
    }

    // MARK: - Rules

    var rules: Rules {
        frontDoor.before(.open) {
            try refuse(Prose.frontDoorRefusal)
        }

        // The `proceed()` acceptance pattern from Task 5: run the built-in
        // open, then embellish with a line about the leaflet.
        mailbox.before(.open) {
            try proceed()
            say(Prose.mailboxEmbellishment)
        }

        leaves.before(.push) {
            guard !grating.isRevealed else { try reply(Prose.leavesAlreadyMoved) }
            grating.reveal()
            try reply(Prose.leavesMoveEmbellishment)
        }
    }
}
