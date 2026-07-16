import Gnusto

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

    /// Scenery in `forestPath`. `climb tree` reaches the perch above (the
    /// `climb` rule in this bundle's `rules`), the same place `up` leads.
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

    /// The jewel-encrusted egg, found up the tree. The living room's trophy
    /// case (in ``ZorkHouse``) describes itself by whether it holds this egg;
    /// since the two live in different bundles, the host declares that
    /// `describe` rule (`Zork1.rules`).
    let egg = Item {
        name("jewel-encrusted egg")
        adjectives("jewel-encrusted", "jeweled")
        description(Prose.egg)
        // The original's values: 5 for the find, 5 for the case.
        trait(.takeValue, 5)
        trait(.depositValue, 5)
        // A container holding the clockwork canary, but sealed by a mechanism no
        // brute can work: force it open yourself (the built-in `open`, gated by a
        // host rule) and you wreck the bird. Starts closed and opaque — the canary
        // stays hidden until it's opened. Only the thief can open it cleanly (his
        // egg-service fuse, wired in ``Zork1``).
        container
        openable
    }

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

    /// Openable, and locked by `skeletonKey` via the `map` block below, so it
    /// starts (and stays) locked: `open grating` refuses with the built-in
    /// "is locked" message with no rule of our own needed.
    let grating = Item {
        name("iron grating")
        adjectives("iron", "metal")
        description(Prose.grating)
        container
        openable
        scenery
        hidden
    }

    /// The grating's key. Not placed anywhere in `map`: it's a future pickup
    /// for the maze phase (the host places it in `Zork1.map`), not a fixture
    /// of this slice — but a declared, unplaced item is legal (it resolves to
    /// `.nowhere`).
    let skeletonKey = Item {
        name("skeleton key")
    }

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

    // MARK: - Endgame

    /// The hand-drawn map to the Stone Barrow. It materialises inside the trophy
    /// case once all nineteen treasures rest there — the host's trophy-case
    /// `after(.putIn)` rule reveals it — and it shows the way southwest from West
    /// of House to the barrow. Starts `hidden` inside the case (host placement in
    /// ``Zork1``), so it stays out of sight — and out of "take all" — until the
    /// collection is complete. Not a treasure: no value, and absent from the
    /// host's `treasureRoster`.
    let ancientMap = Item {
        name("ancient map")
        adjectives("ancient", "hand-drawn")
        description(Prose.ancientMap)
        hidden
    }

    /// The Stone Barrow, southwest of West of House — reachable only once the
    /// ancient map has appeared. Entering it ends the game in victory (the host's
    /// `onEnter` epilogue in ``Zork1``), so this description is only ever seen if
    /// that win hook is removed.
    let stoneBarrow = Location {
        name("Stone Barrow")
        description(Prose.stoneBarrow)
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

        // Canyon. The wall is `CLIMBABLE-CLIFF` in the original — climbable in
        // both directions, no gear required — so every leg here is genuinely
        // two-way, matching canon. (An earlier FIDELITY note that called this a
        // one-way trap was mistaken; corrected in Phase 10.9.) The rainbow, woken
        // by the sceptre at the End of Rainbow, is an *additional* way across the
        // falls, not the canyon's only return.
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
        grating.lockedBy(skeletonKey)
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

        // Not `require`: that helper is hardwired to `refuse` (see
        // `Sources/Gnusto/Declarations/Helpers.swift`), but "already moved"
        // needs to fully own the turn's response (`reply`), not just block
        // a default action with a complaint. Same reasoning at `rug.before`
        // in `House.swift`.
        leaves.before(.push) {
            guard !grating.isRevealed else { try reply(Prose.leavesAlreadyMoved) }
            grating.reveal()
            try reply(Prose.leavesMoveEmbellishment)
        }

        // Climbing the tree is the `up` exit under another name — `climb tree`
        // now reaches the perch, where before only `up` did (FIDELITY.md). The
        // tree is scenery in `forestPath` only, so this fires just from below.
        tree.before(.climb) {
            player.location = upATree
            describeSurroundings()
            try reply("")
        }
    }
}
