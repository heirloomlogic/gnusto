import Gnusto

/// One world declared two ways. `latched` spells each one-time beat as
/// `@Latch` plus `$flag.trips()`; otherwise it is the `@Global var flag =
/// false` / `guard !flag` / `flag = true` pair the latch replaces. Every
/// transcript must match.
struct LatchGame: Game {
    let title = "Latch"
    let intro = ""
    let latched: Bool

    let hall = Location {
        name("Hall")
        description("A bare hall. The vault lies north.")
    }
    let vault = Location {
        name("Vault")
    }
    let bell = Item {
        name("brass bell")
        adjectives("brass")
    }
    let lever = Item {
        name("iron lever")
        adjectives("iron")
    }
    let candle = Item {
        name("tallow candle")
        adjectives("tallow")
        lightSource
    }
    let annex: LatchAnnex

    @Latch var rung
    @Latch var vaultOpen
    @Latch var candleSpent
    @Latch var muttered

    @Global var rungFlag = false
    @Global var vaultOpenFlag = false
    @Global var candleSpentFlag = false
    @Global var mutteredFlag = false

    init() {
        self.init(latched: true)
    }

    init(latched: Bool) {
        self.latched = latched
        annex = LatchAnnex(latched: latched)
    }

    var content: GameContents { annex }

    // `.hum` is `CustomVerbGames.swift`'s verb-wired-to-nothing, declared
    // module-wide. A rule below trips a latch and answers nothing, so the
    // turn reaches stage 4's last resort and is rolled back.
    var verbs: [SyntaxRule] { [.hum] }

    var map: WorldMap {
        hall.north(
            vault,
            when: { self.latched ? self.vaultOpen : self.vaultOpenFlag },
            otherwise: Self.vaultShut)
        vault.south(hall)
        vault.east(annex.crypt)
        player.starts(in: hall)
        bell.starts(in: hall)
        lever.starts(in: hall)
        candle.starts(in: hall)
    }

    var timers: [TimedEvent] {
        fuse("candleDies", after: 2) {
            if latched { $candleSpent.trips() } else { candleSpentFlag = true }
            say(Self.candleDies)
        }
    }

    var rules: Rules {
        candle.after(.turnOn) { startFuse("candleDies") }
        if latched {
            bell.before(.touch) {
                guard $rung.trips() else { try reply(Self.bellAgain) }
                try reply(Self.bellFirst)
            }
            lever.before(.push) {
                $vaultOpen.trips()
                try reply(Self.leverPushed)
            }
            candle.describe { candleSpent ? Self.candleStub : Self.candleWhole }
            // Trips, then falls through to stage 4's last resort. Nothing
            // answers `mutter`, so the turn is unhandled and rolled back.
            hall.before(.hum) { $muttered.trips() }
            bell.before(.examine) {
                try reply(muttered ? Self.bellMuttered : Self.bellQuiet)
            }
        } else {
            bell.before(.touch) {
                guard !rungFlag else { try reply(Self.bellAgain) }
                rungFlag = true
                try reply(Self.bellFirst)
            }
            lever.before(.push) {
                vaultOpenFlag = true
                try reply(Self.leverPushed)
            }
            candle.describe { candleSpentFlag ? Self.candleStub : Self.candleWhole }
            hall.before(.hum) { mutteredFlag = true }
            bell.before(.examine) {
                try reply(mutteredFlag ? Self.bellMuttered : Self.bellQuiet)
            }
        }
    }

    static let bellMuttered = "The bell remembers the muttering."
    static let bellQuiet = "The bell has heard no muttering."
    static let bellFirst = "The bell answers with one long note, and the hall listens."
    static let bellAgain = "The bell only mutters this time."
    static let leverPushed = "The lever goes over, and something heavy gives to the north."
    static let vaultShut = "The way north is walled."
    static let candleWhole = "A tallow candle, most of it still to burn."
    static let candleStub = "A stub of tallow, cold."
    static let candleDies = "The candle gutters out."
}

/// The bundle half of ``LatchGame``: a namespaced latch, to prove one
/// registers under the bundle the way a `@Global` does.
struct LatchAnnex: GameContent {
    let latched: Bool
    let crypt = Location {
        name("Crypt")
        description("A low crypt.")
    }
    let slab = Item {
        name("stone slab")
        adjectives("stone")
    }

    @Latch var slabMoved

    @Global var slabMovedFlag = false

    init(latched: Bool) {
        self.latched = latched
    }

    var map: WorldMap {
        slab.starts(in: crypt)
    }

    var rules: Rules {
        if latched {
            slab.before(.push) {
                guard $slabMoved.trips() else { try reply(Self.slabAgain) }
                try reply(Self.slabFirst)
            }
        } else {
            slab.before(.push) {
                guard !slabMovedFlag else { try reply(Self.slabAgain) }
                slabMovedFlag = true
                try reply(Self.slabFirst)
            }
        }
    }

    static let slabFirst = "The slab grinds aside on grit."
    static let slabAgain = "The slab is as far over as it goes."
}
