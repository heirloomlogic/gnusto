import Gnusto
import GnustoActors

/// Fixtures for `GnustoActors`. `WanderGame` exercises roaming (100% so
/// every turn moves, announcements asserted under a pinned seed) and its
/// `while:` gate, which is shut for as long as the player stands in the chapel;
/// `PickpocketGame` exercises theft, reactions, theft in the dark (`douse`),
/// and daemon stopping; `FollowGame` exercises the companion daemon
/// (deterministic, no seeds).
struct WanderGame: Game {
    let title = "Wander"
    let intro = "Someone is pacing the grounds."

    let yard = Location {
        name("Yard")
        description("Patchy grass.")
    }

    let armory = Location {
        name("Armory")
        description("Racks, mostly empty.")
    }

    let chapel = Location {
        name("Chapel")
        description("Cold candles.")
    }

    let crypt = Location {
        name("Crypt")
        description("You should not be able to read this.")
        dark
    }

    let wanderer = Actor {
        name("restless wanderer")
        adjectives("restless")
        description("Never still.")
    }

    let behaviors = ActorBehaviors()

    var map: WorldMap {
        yard.north(armory)
        armory.south(yard)
        armory.east(chapel)
        chapel.west(armory)
        chapel.down(crypt)
        crypt.up(chapel)

        player.starts(in: yard)
        wanderer.starts(in: armory)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("swoon", intent: Intent("swoon"))
        SyntaxRule("rouse", intent: Intent("rouse"))
    }

    var rules: Rules {
        world.before(Intent("swoon")) {
            wanderer.isUnconscious = true
            try reply("He folds up on the spot.")
        }
        world.before(Intent("rouse")) {
            wanderer.isUnconscious = false
            try reply("He picks himself up.")
        }
    }

    var timers: [TimedEvent] {
        behaviors.roams(
            wanderer,
            daemonName: "wander",
            rooms: [yard, armory, chapel, crypt],
            chancePerTurn: 100,
            // The gate: stand in the chapel and he holds still, wherever he is.
            while: { player.location != chapel },
            arrival: "The wanderer saunters in.",
            departure: "The wanderer slips away.")
    }
}

struct PickpocketGame: Game {
    let title = "Pickpocket"
    let intro = "Mind your pockets."

    let plaza = Location {
        name("Plaza")
        description("Sun and pigeons.")
    }

    let thief = Actor {
        name("nimble thief")
        adjectives("nimble")
        description("All fingers.")
    }

    let locket = Item {
        name("silver locket")
        adjectives("silver")
    }

    let coin = Item {
        name("bent coin")
        adjectives("bent")
    }

    /// A steal candidate lying on the floor of the thief's room — reachable
    /// now that theft is no longer held-only.
    let pebble = Item {
        name("dull pebble")
        adjectives("dull")
    }

    /// A closed strongbox on the floor, and the gem locked inside it. The gem
    /// is a steal candidate but stays immune by construction: the thief cannot
    /// rifle a shut container.
    let strongbox = Item {
        name("iron strongbox")
        adjectives("iron")
        container
        openable
    }

    let gem = Item {
        name("green gem")
        adjectives("green")
    }

    /// An open bag in the player's own hands, and a candidate itself. The old
    /// allowlist never reached inside it — the thief's whole point is that he
    /// does — and once the bag is in his bag, its ruby must stop counting as
    /// loot he can still lift.
    let satchel = Item {
        name("canvas satchel")
        adjectives("canvas")
        container
        openable
        startsOpen
    }

    let ruby = Item {
        name("cracked ruby")
        adjectives("cracked")
    }

    /// The thief's own open pouch, with a candidate already in it. His hands
    /// are in his own reach set, so only a guard that walks the whole way up
    /// stops him "stealing" what is already his and announcing it.
    let pouch = Item {
        name("leather pouch")
        adjectives("leather")
        container
        openable
        startsOpen
    }

    let token = Item {
        name("tin token")
        adjectives("tin")
    }

    /// A `surface` in the room. Surfaces were never `isOpen`, so no allowlist
    /// of containers could ever have covered the medal lying on it.
    let plinth = Item {
        name("stone plinth")
        adjectives("stone")
        surface
        scenery
    }

    let medal = Item {
        name("tin medal")
        adjectives("tin")
    }

    let behaviors = ActorBehaviors()

    var map: WorldMap {
        player.starts(in: plaza)
        thief.starts(in: plaza)
        locket.startsHeld
        coin.startsHeld
        pebble.starts(in: plaza)
        strongbox.starts(in: plaza)
        gem.starts(inside: strongbox)
        satchel.startsHeld
        ruby.starts(inside: satchel)
        plinth.starts(in: plaza)
        medal.starts(on: plinth)
        pouch.starts(heldBy: thief)
        token.starts(inside: pouch)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("hail", .directObject, intent: Intent("hail"))
        SyntaxRule("accuse", intent: Intent("accuse"))
        SyntaxRule("whistle", intent: Intent("whistle"))
        SyntaxRule("douse", intent: Intent("douse"))
        SyntaxRule("swoon", intent: Intent("swoon"))
        SyntaxRule("rouse", intent: Intent("rouse"))
    }

    var timers: [TimedEvent] {
        behaviors.steals(
            thief,
            daemonName: "pick",
            candidates: [locket, coin, pebble, gem, ruby, medal, satchel, token],
            chancePerTurn: 100,
            announcement: { "Featherlight fingers make off with the \($0)." })
    }

    var rules: Rules {
        behaviors.reaction(
            of: thief, to: [Intent("hail")],
            reply: "He nods, warily.")
        world.before(Intent("accuse")) {
            let haul = thief.inventory.map(\.name).joined(separator: ", ")
            try reply("Haul: \(haul.isEmpty ? "nothing" : haul).")
        }
        world.before(Intent("whistle")) {
            stopDaemon("pick")
            try reply("The whistle freezes every hand in the plaza.")
        }
        // Puts the plaza out, so a theft can be watched from inside the dark
        // the player's own reach set stops at.
        world.before(Intent("douse")) {
            plaza.isLit = false
            try reply("The sun goes out over the plaza.")
        }
        // Puts the thief out, and brings him round, without a combat plugin in
        // the game at all — `isUnconscious` is the engine's, so `steals` reads
        // it whatever set it.
        world.before(Intent("swoon")) {
            thief.isUnconscious = true
            try reply("The thief drops where he stands.")
        }
        world.before(Intent("rouse")) {
            thief.isUnconscious = false
            try reply("The thief blinks and sits up.")
        }
    }
}

/// `FollowGame` exercises following: a companion hound that catches up with
/// the player each turn — silently in the dark, never while parked or
/// offstage. No randomness, so no seed pinning anywhere.
struct FollowGame: Game {
    let title = "Follow"
    let intro = "The hound pads at your heel."

    let foyer = Location {
        name("Foyer")
        description("Coats and boot-scrapes.")
    }

    let hall = Location {
        name("Hall")
        description("A long rug.")
    }

    let parlor = Location {
        name("Parlor")
        description("Doilies everywhere.")
    }

    let cellar = Location {
        name("Cellar")
        description("You should not be able to read this.")
        dark
    }

    let hound = Actor {
        name("loyal hound")
        adjectives("loyal")
        description("All ears and devotion.")
    }

    let behaviors = ActorBehaviors()

    var map: WorldMap {
        foyer.east(hall)
        hall.west(foyer)
        hall.east(parlor)
        parlor.west(hall)
        foyer.down(cellar)
        cellar.up(foyer)

        player.starts(in: foyer)
        hound.starts(in: foyer)  // co-located: no spurious turn-one arrival
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("dismiss", intent: Intent("dismiss"))
        SyntaxRule("park", intent: Intent("park"))
        SyntaxRule("resume", intent: Intent("resume"))
    }

    var timers: [TimedEvent] {
        behaviors.follows(
            hound,
            daemonName: "follow",
            arrivals: ["The hound pads in after you."])
    }

    var rules: Rules {
        world.before(Intent("dismiss")) {
            hound.vanish()
            try reply("The hound is spirited away.")
        }
        world.before(Intent("park")) {
            stopDaemon("follow")
            try reply("\"Stay,\" you say. The hound sits.")
        }
        world.before(Intent("resume")) {
            startDaemon("follow")
            try reply("\"Come along,\" you say.")
        }
    }
}

/// A follower with both gates on, which is the Dungeon Master's shape: a gaoler
/// who walks the corridors at your heel, will not set foot in a cell, and holds
/// still when told to. The cell is the point — somewhere he will not go is
/// somewhere you can stand and still be heard.
struct GaolerGame: Game {
    let title = "Gaoler"
    let intro = "He walks where you walk, up to a point."

    let guardroom = Location {
        name("Guardroom")
        description("A stool, a ledger, and a ring of keys.")
    }

    let corridor = Location {
        name("Corridor")
        description("Stone, and a drain down the middle of it.")
    }

    let cell = Location {
        name("Cell")
        description("Four walls and a shelf of a bed.")
    }

    let gaoler = Actor {
        name("stone-faced gaoler")
        adjectives("stone-faced")
        description("He has done this a long time.")
    }

    /// Whether he has been told to wait — the `while:` gate.
    @Global var gaolerStaying = false

    let behaviors = ActorBehaviors()

    var map: WorldMap {
        guardroom.east(corridor)
        corridor.west(guardroom)
        corridor.north(cell)
        cell.south(corridor)

        player.starts(in: guardroom)
        gaoler.starts(in: guardroom)  // co-located: no spurious turn-one arrival
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("halt", intent: Intent("halt"))
        SyntaxRule("heel", intent: Intent("heel"))
    }

    var timers: [TimedEvent] {
        behaviors.follows(
            gaoler,
            daemonName: "gaoler.follow",
            rooms: [guardroom, corridor],
            while: { !gaolerStaying },
            arrivals: ["The gaoler comes in behind you."])
    }

    var rules: Rules {
        world.before(Intent("halt")) {
            gaolerStaying = true
            try reply("\"Wait here,\" you say. He waits.")
        }
        world.before(Intent("heel")) {
            gaolerStaying = false
            try reply("\"With me,\" you say.")
        }
    }
}
