import Gnusto
import GnustoScoring

/// The jewel-encrusted egg lives in `ZorkAboveGround` (Up a Tree), but the
/// living room's trophy case (`ZorkHouse`) needs to describe itself
/// differently once the egg is inside it. A file-scope `let` is how this
/// codebase always shares one item's identity across sibling declarations
/// that can't reference each other directly — a *stored property*
/// initializer can't reference `self` or another stored property, but a
/// top-level `let` is lazily initialized, so a closure captured inside a
/// later top-level `let` can freely name an earlier one (see
/// `DslQuickWinGames.swift`'s `eggItem`/`trophyCaseItem` pair for the
/// single-file precedent). `ZorkAboveGround.egg` and `ZorkHouse.trophyCase`
/// both simply *are* this same file-scope value, so the two bundles share
/// one identity with no explicit injection needed.
let zork1Egg = Item {
    name("jewel-encrusted egg")
    adjectives("jewel-encrusted", "jeweled")
    description(Prose.egg)
    // The original's values: 5 for the find, 5 for the case.
    trait(.takeValue, 5)
    trait(.depositValue, 5)
}

/// The lantern's description reads its own lit state, which runs into the
/// same self-reference restriction as the trophy case above — hence the same
/// file-scope-`let` idiom.
private let zork1Lantern = Item {
    name("brass lantern")
    adjectives("brass")
    synonyms("lamp")
    description { zork1Lantern.isLit ? Prose.lanternOn : Prose.lanternOff }
    lightSource
}

private let zork1TrophyCase = Item {
    name("trophy case")
    description {
        zork1TrophyCase.holds(zork1Egg)
            ? Prose.trophyCaseHolding("a \(zork1Egg.name)")
            : Prose.trophyCaseEmpty
    }
    container
    openable
    transparent
    scenery
}

/// The interior of the White House: kitchen, living room, attic, and the
/// cellar the trap door drops into. The region beyond the cellar (East of
/// Chasm, Gallery, Studio) is ``ZorkCellar``'s; the troll passage north and
/// the maze are later phases — see `FIDELITY.md`.
///
/// The trap door joins two rooms this bundle owns outright (`livingRoom`
/// and `cellar`), so it's wired below in this bundle's own `map`. The
/// kitchen window is different: it's a door between this bundle's `kitchen`
/// and `ZorkAboveGround.behindHouse`, a room this bundle doesn't own, so
/// *that* exit is wired by the host, ``Zork1``, at the top level — the
/// ordinary way two bundles' geography meets (as are the cellar's exits
/// into ``ZorkCellar``).
struct ZorkHouse: GameContent {
    // MARK: - Rooms

    let kitchen = Location {
        name("Kitchen")
        description(Prose.kitchen)
    }

    let livingRoom = Location {
        name("Living Room")
        description(Prose.livingRoom)
    }

    let attic = Location {
        name("Attic")
        description(Prose.attic)
    }

    let cellar = Location {
        name("Cellar")
        description(Prose.cellar)
        dark
    }

    // MARK: - Kitchen

    /// The door between `ZorkAboveGround.behindHouse` and `kitchen`. Starts
    /// closed; "slightly ajar" (Prose.kitchenWindow) is flavor text, not a
    /// distinct open/closed state of its own.
    let window = Item {
        name("kitchen window")
        adjectives("kitchen", "narrow")
        description(Prose.kitchenWindow)
        openable
        scenery
    }

    let sack = Item {
        name("brown sack")
        adjectives("brown")
        description(Prose.sack)
        container
        openable
        startsOpen
    }

    let garlic = Item {
        name("clove of garlic")
        adjectives("clove")
        description(Prose.garlic)
    }

    let lunch = Item {
        name("lunch")
        description(Prose.lunch)
    }

    let bottle = Item {
        name("glass bottle")
        adjectives("glass")
        description(Prose.bottle)
        container
        openable
        transparent
    }

    let water = Item {
        name("quantity of water")
        adjectives("quantity")
        description(Prose.water)
    }

    // MARK: - Living Room

    /// A real light source with finite fuel: two fuses (dim warning, then
    /// out for good) that run only while it burns — turning it off banks
    /// the remaining turns. See the file-scope `zork1Lantern` for why the
    /// declaration lives outside the struct.
    let lantern = zork1Lantern

    /// Fuel remaining on the dim-warning fuse while the lantern is off.
    /// Deliberately small numbers (the original burns for hundreds of
    /// turns) so a transcript test can watch it die — see `FIDELITY.md`.
    @Global var lanternDimIn = 20
    /// Fuel remaining on the burn-out fuse while the lantern is off.
    @Global var lanternDiesIn = 25
    @Global var lanternBurnedOut = false

    let sword = Item {
        name("elvish sword")
        adjectives("elvish")
        description(Prose.sword)
    }

    /// Pushing the rug reveals the hidden trap door — the same Task 4
    /// acceptance pattern the leaves/grating pair in `ZorkAboveGround` uses.
    let rug = Item {
        name("oriental rug")
        adjectives("oriental")
        description(Prose.rug)
        scenery
    }

    /// Shared between `livingRoom` and the stub `cellar`: opening it from
    /// either side is the same state, so the classic "trap door slams shut
    /// behind you" moment (`cellar.onEnter` below) is felt from both rooms.
    let trapDoor = Item {
        name("trap door")
        description(Prose.trapDoor)
        openable
        scenery
        hidden
    }

    /// A closure description, live on every examine: whether the case is
    /// empty or holds the egg is read from `holds(_:)` rather than fixed at
    /// declaration time — see the file-scope `zork1TrophyCase` this aliases,
    /// just above.
    let trophyCase = zork1TrophyCase

    // MARK: - Attic

    let rope = Item {
        name("coil of rope")
        adjectives("coil")
        description(Prose.rope)
    }

    let knife = Item {
        name("nasty knife")
        adjectives("nasty")
        description(Prose.knife)
    }

    // MARK: - Map

    var map: WorldMap {
        livingRoom.east(kitchen)
        kitchen.west(livingRoom)
        kitchen.up(attic)
        attic.down(kitchen)
        livingRoom.down(cellar, via: trapDoor)
        cellar.up(livingRoom, via: trapDoor)
        // The troll's passage — a later phase; rubble for now (FIDELITY.md).
        cellar.north(blocked: Prose.cellarNorthBlocked)

        sack.starts(in: kitchen)
        garlic.starts(inside: sack)
        lunch.starts(inside: sack)
        bottle.starts(in: kitchen)
        water.starts(inside: bottle)

        lantern.starts(in: livingRoom)
        sword.starts(in: livingRoom)
        rug.starts(in: livingRoom)
        trapDoor.starts(in: livingRoom)
        trophyCase.starts(in: livingRoom)

        rope.starts(in: attic)
        knife.starts(in: attic)
    }

    // MARK: - Rules

    var rules: Rules {
        // Not `require`: that helper is hardwired to `refuse` (see
        // `Sources/Gnusto/Declarations/Helpers.swift`), but "already moved"
        // needs to fully own the turn's response (`reply`), not just block
        // a default action with a complaint. Same reasoning at
        // `leaves.before` in `AboveGround.swift`.
        rug.before(.push) {
            guard !trapDoor.isRevealed else { try reply(Prose.rugAlreadyMoved) }
            trapDoor.reveal()
            try reply(Prose.rugMoveEmbellishment)
        }

        // The classic moment: descending through the trap door slams it shut
        // behind you. It can still be re-opened from the cellar side for now
        // (the thief who bars it arrives in Phase 8 — see `FIDELITY.md`).
        cellar.onEnter {
            guard trapDoor.isOpen else { return }
            trapDoor.isOpen = false
            say(Prose.trapDoorSlam)
        }

        // The lantern's fuel economy: the fuses run only while it burns.
        lantern.before(.turnOn) {
            try require(!lanternBurnedOut, else: Prose.lanternSpent)
        }
        lantern.after(.turnOn) {
            if lanternDimIn > 0 {
                startFuse("lanternDim", after: lanternDimIn)
            }
            startFuse("lanternDies", after: lanternDiesIn)
        }
        lantern.after(.turnOff) {
            // Bank what's left, then stop the clock — no fuel burns while
            // the lantern is off.
            lanternDimIn = fuseRemaining("lanternDim") ?? 0
            lanternDiesIn = fuseRemaining("lanternDies") ?? 0
            stopFuse("lanternDim")
            stopFuse("lanternDies")
        }
    }

    var timers: [TimedEvent] {
        fuse("lanternDim", after: 20) {
            say(Prose.lanternDim)
        }
        fuse("lanternDies", after: 25) {
            lanternBurnedOut = true
            zork1Lantern.isLit = false
            say(Prose.lanternDies)
        }
    }
}
