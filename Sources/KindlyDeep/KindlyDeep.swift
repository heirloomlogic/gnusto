import Gnusto
import GnustoActors
import GnustoScoring

extension Intent {
    /// **drink** — take a swallow from the canteen, resetting the thirst clock.
    #verb(
        "drink",
        ["drink", .directObject],
        ["drink", "from", .directObject],
        ["sip", .directObject],
        ["sip", "from", .directObject])
    /// **rest** — lie down on the shelter-hole straw, resetting the fatigue clock.
    #verb("rest", ["rest"], ["sleep"], ["lie", "down"], ["nap"])
    /// **give** — share the canteen with Biscuit (a real cost; thirst does not reset).
    #verb(
        "give",
        ["give", .directObject, "to", .indirectObject],
        ["feed", .directObject, "to", .indirectObject],
        ["offer", .directObject, "to", .indirectObject])
    /// **talk** — speak to the mule.
    #verb("talk", ["talk", "to", .directObject], ["talk", .directObject], ["speak", "to", .directObject])
    /// **ring** — pull the signal bell.
    #verb("ring", ["ring", .directObject])
    /// **pull** — the bell rope answers to this; so does anything else worth a try.
    #verb("pull", ["pull", .directObject], ["tug", .directObject], ["yank", .directObject])
    /// **sit** — the shelter hole has a bench, and benches invite it.
    #verb("sit", ["sit"], ["sit", "down"], ["sit", "on", .directObject])
    /// **pet** — scratch the mule under the forelock.
    #verb("pet", ["pet", .directObject], ["pat", .directObject], ["stroke", .directObject])
    /// **harness** — back Biscuit up to the beam and hitch on the haul tack.
    /// A player who has never worked a mule will reach for whichever word they
    /// know, so the collar answers to all of them.
    #verb(
        "harness",
        ["harness", .directObject],
        ["harness", .directObject, "to", .indirectObject],
        ["hitch", .directObject],
        ["hitch", .directObject, "to", .indirectObject],
        ["saddle", .directObject],
        ["yoke", .directObject],
        ["rig", .directObject])
}

/// The Kindly Deep — a survival-and-companion demo. A fall of rock has sealed
/// the deep workings of a West Virginia coal mine late in the 1800s, and the
/// driver must reach the hoisting shaft with Biscuit the mine mule: two failing
/// clocks (thirst and fatigue) that end in death unless drunk and rested, and a
/// companion who follows, is parked by a crawl a mule cannot use, and rejoins
/// through the air-door — the general survival/companion substrate, proven via
/// GnustoActors and GnustoScoring.
///
/// Fully original title, world, and prose. The mechanics here are the general
/// survival and companion paradigms, not any specific game's.
@main
struct KindlyDeep: Game, GameMain {
    let title = "The Kindly Deep"
    let tagline = "Two went down; two come up."
    let maxScore = 25

    let intro = """
        The roof gave no more warning than a handful of dust, and then the world came down behind you with a sound \
        you felt in your teeth. That was... some time ago. You came back to yourself in the perfect dark, and you \
        have been sitting in it since, doing the arithmetic: the fall is between you and the main entry; your \
        cap-lamp went out when you did; your water went under the rock with your dinner bucket; and the shift \
        above will have marked these workings lost until the men can timber their way in, which is measured in days, \
        not hours.

        Somewhere close, something large shifts its weight and breathes — patient, unbothered, smelling of hay. It \
        would be a strange sort of comfort to anyone who had not spent two years leading Biscuit along these entries. \
        To you it is just the mule, waiting to hear what the two of you do next.

        There is a flint striker on your belt, where it always is. Down here you learn: first the lamp, then the plan.
        """

    /// The whole mine is dark; the cap-lamp is the only light. The one dark
    /// stretch that matters is the opening in the Fresh Fall, so the stock
    /// pitch-black line carries that room's bespoke prose (§8). `nowOn` carries
    /// every relight after the first — the striker scene is a one-time beat, and
    /// waking in the dark after a rest must not replay it (§8).
    var text: GameText {
        var text = GameText()
        text.pitchBlack = """
            Dark of the sort found only underground: complete, unhurried, and inches from your face. Somewhere near, \
            hooves shift on stone. The flint striker is on your belt, and using it is the only good idea available.
            """
        text.nowOn = { _ in
            """
            Flint, sparks, and the wick takes; the dark gives ground again, grudgingly, to about arm's length.
            """
        }
        return text
    }

    // MARK: - Plugins

    /// The five scored beats. Declared rather than scattered, so the bootstrap
    /// can check them against `maxScore`.
    let scoring = Scoring(awards: [
        "lamp": 5,  // the striker
        "canteen": 5,  // the water, however you find it
        "door": 5,  // the air-door, and the mule back
        "beam": 5,  // the haul
        "bell": 5,  // the cage
    ])
    let actors = ActorBehaviors()

    var content: GameContents {
        scoring
    }

    // MARK: - Survival clocks & beat flags

    /// Turns since the last drink. Warns at 12/20/28; the third stage arms the
    /// dehydration fuse. Reset to 0 by `drink`.
    @Global var thirst = 0
    /// Turns since the last rest. Warns at 16/26/36; the third stage arms the
    /// collapse fuse. Reset to 0 by `rest` on the straw.
    @Global var fatigue = 0
    /// Swallows left in the canteen — three, and no more water in the workings.
    /// Drinking (or sharing one with Biscuit) spends one.
    @Global var canteenDrinks = 3
    /// Whether the striker scene has played. Every later light is ordinary
    /// lamp business, handled by the default action.
    @Global var lampFirstLit = false
    /// Whether the crawl has parked Biscuit at the Forks (beat 4).
    @Global var crawlBeatDone = false
    /// Whether Biscuit has hauled the fallen beam clear of the cage gate (beat 5).
    @Global var beamHauled = false

    // MARK: - Rooms

    let freshFall = Location {
        name("The Fresh Fall")
        description(
            """
            The entry ends, abruptly, in a wall of fallen rock and splintered timber — the whole roof of the main \
            entry, brought down and settled in to stay. Rails run under the rubble and do not come out. The stable \
            lies west, the shelter hole is a step down to the south, and the entry runs east toward the forks.
            """)
        dark
    }

    let stable = Location {
        name("The Stable")
        description(
            """
            Whitewashed walls, worn brick underfoot, and the deep sweet smell of hay: the underground stable, kept \
            cleaner than most kitchens because the stable boss holds strong views. Biscuit's stall stands open, his \
            name chalked over it in a careful hand, and the water trough beside it stands dry. The entry back east \
            is clear.
            """)
        dark
    }

    let shelterHole = Location {
        name("The Shelter Hole")
        description(
            """
            A timbered shelter hole cut into the rib, where a man steps in when the trip runs: a bench, a dry floor, \
            and — luxury of luxuries — a heap of clean straw somebody's conscience left here. It is the driest, \
            safest corner these workings have to offer, which is to say it is dry and mostly safe. The entry is back \
            up to the north.
            """)
        dark
    }

    let forks = Location {
        name("The Forks")
        description(
            """
            The entry forks here at the mouth of the old works. North, the old heading runs off into a silence that \
            smells faintly, sweetly wrong. East, the air-door stands in its frame — and past it, the shaft — but the \
            fall has racked the frame and jammed it fast on this side. Beside it, at floor level, the rock left a low \
            dark gap along the edge of the fall: a crawl, for anyone honest about their size.
            """)
        dark
    }

    let lowCrawl = Location {
        name("The Low Crawl")
        description(
            """
            Rock above, rock below, rock pressing in from both sides, and you between on your hands and knees with \
            the lamp throwing your own shadow into your eyes. The crawl runs east and west, and it is no place to \
            stop and think — thinking is better done where there is room to stand up and pace.
            """)
        dark
    }

    let shaftBottom = Location {
        name("The Shaft Bottom")
        description(
            """
            And here it is: the shaft bottom, the one door out of the world below. The hoisting shaft rises out of \
            sight, breathing cold top-side air down on you. The cage gate stands in its frame — with a twelve-foot \
            beam lying square across it, delivered by the same event that delivered everything else today. On the \
            wall, the signal bell and its rope; on a peg, the haul tack, collar and chains kept where the work is. \
            The air-door is in the west wall, and its bar is on this side.
            """)
        dark
    }

    /// The bad-air heading north of the Forks. Entering it is fatal — a room
    /// whose only rule is a death. Biscuit blocks the way while he is present;
    /// this is the backstop for the case he somehow is not (§9 gas death).
    let oldWorks = Location {
        name("The Old Works")
        dark
    }

    // MARK: - Items

    /// Worn on the cap, so always to hand. Starts unlit; the striker scene in
    /// `rules` lights it (beat 1). No fuel mechanic — but a man does not sleep
    /// beside an open flame, so `rest` snuffs it and you wake needing a relight.
    let capLamp = Item {
        name("cap-lamp")
        adjectives("oil")
        synonyms("caplamp", "light", "flame")
        lightSource
    }

    /// Named by the intro and by the pitch-black prose every dark turn, so it
    /// had better be a thing. It never leaves your belt: a man who drops his
    /// striker in these workings has invented a new way to die.
    let striker = Item {
        name("flint striker")
        synonyms("steel")
        description(
            """
            A flint striker, worn shiny at the grip, riding where it always rides. It has no opinions and asks \
            nothing of you, and twice today it has been the difference between a mine and a grave.
            """)
    }

    /// Biscuit's find, and the whole thirst clock: the day shift's canteen,
    /// three swallows in it, and no other water in the workings. Its
    /// swallows-remaining examine text is a `describe` rule.
    let canteen = Item {
        name("canteen")
        adjectives("tin", "stoppered", "shift")
        synonyms("water", "flask")
        hidden
    }

    let hay = Item {
        name("hay")
        adjectives("good", "dry")
        description(
            """
            Good hay, kept dry. Biscuit's, by rights. It is no use to you at all, which is the first honest thing \
            this mine has said today.
            """)
        scenery
    }

    let straw = Item {
        name("straw")
        adjectives("clean", "deep")
        synonyms("heap", "bed")
        description(
            "Clean straw, deep enough to lie in. It has been a long time since anything looked more like a bed.")
        scenery
    }

    let bench = Item {
        name("bench")
        adjectives("timber", "worn")
        synonyms("seat")
        description(
            """
            A plank bench worn smooth by men waiting out a trip, with two initials cut into the end of it by \
            somebody with time and a knife. It is a good bench. It is not a bed.
            """)
        scenery
    }

    let rubble = Item {
        name("fall")
        adjectives("fresh", "fallen")
        synonyms("rubble", "rock", "rocks", "roof", "timber", "timbers")
        description(
            """
            Rock and splintered prop, packed tight and gone quiet — the settled kind of fall, the kind that has \
            finished moving and has no interest in being moved. Somewhere on the far side of it, men are timbering \
            toward you at the pace of men who think they are recovering bodies.
            """)
        scenery
    }

    let rails = Item {
        name("rails")
        adjectives("iron", "buried")
        synonyms("rail", "track", "tracks")
        description(
            """
            Two iron rails running out of the fall and away east, the gauge of a mine car and a mule. They are the \
            reason you know these workings in the dark: you have walked them, alongside Biscuit, for two years.
            """)
        scenery
    }

    let stall = Item {
        name("stall")
        adjectives("open")
        synonyms("name", "chalk")
        description(
            """
            Biscuit's stall, swept and standing open, his name chalked over it by somebody who took trouble with \
            the letters. He has not looked at it once since the roof came down.
            """)
        scenery
    }

    /// The stable's own water, dry — the reason the canteen is the whole clock.
    let trough = Item {
        name("water trough")
        adjectives("dry", "empty")
        synonyms("basin")
        description(
            """
            The mule trough, dry as a flue. The line that fed it came down the main entry, and the main entry is the \
            wall of rock behind you. What was in it went into the brick hours ago.
            """)
        scenery
    }

    let cornBin = Item {
        name("corn bin")
        adjectives("loose")
        synonyms("board", "boards")
        description(
            """
            A corn bin with a loose board along its foot — the sort of gap a man uses when he wants a thing to be \
            where he left it. Biscuit has clearly known about it longer than you have.
            """)
        scenery
    }

    /// The jammed ventilation door. It lives physically in the Forks (so it is
    /// examinable and refuses `open` from that side, §8) and gates the shaft's
    /// west exit (so `open door` at the Shaft Bottom triggers the rejoin, §6).
    /// A door with a bad side and a good one has to say which side you are on:
    /// its description is a `describe` rule keyed on where you are standing.
    let airDoor = Item {
        name("air-door")
        adjectives("ventilation", "stout", "jammed")
        synonyms("airdoor", "bar")
        scenery
        openable
    }

    let crawl = Item {
        name("crawl")
        adjectives("low", "dark")
        synonyms("gap")
        description(
            """
            Room enough for a man on his hands and knees, if the man is motivated. It was not cut; it was left, by \
            rock that could just as easily not have left it. It runs east, toward the shaft.
            """)
        scenery
    }

    /// The mouth of the bad air, named by the room and by Biscuit's refusal —
    /// so it had better answer when the player looks at it.
    let oldHeading = Item {
        name("old works")
        adjectives("abandoned")
        synonyms("heading", "workings")
        description(
            """
            An old heading, worked out and left, running north into a dark that gives nothing back. The air coming \
            out of it is sweetish, almost pleasant, which is the single most alarming thing in these workings.
            """)
        scenery
    }

    let beam = Item {
        name("beam")
        adjectives("twelve-foot", "poplar", "fallen")
        synonyms("timber")
        description(
            """
            Twelve feet of poplar, lately part of the roof, now lying across the cage gate with the settled look of \
            an object that weighs more than you do. Considerably more. You know someone it does not outweigh.
            """)
        scenery
    }

    let shaft = Item {
        name("hoisting shaft")
        adjectives("cold")
        description(
            """
            The shaft, going up out of the lamplight and on going up: four hundred feet of it, with weather at the \
            top. The air coming down it is cold and moving and smells of the outside, and you have to make yourself \
            stop breathing it and get on.
            """)
        scenery
    }

    let cageGate = Item {
        name("cage gate")
        adjectives("barred")
        synonyms("cage")
        description(
            """
            The gate the cage lands behind, sound enough and perfectly useless while twelve feet of poplar lies \
            across it.
            """)
        scenery
    }

    let bell = Item {
        name("signal bell")
        synonyms("rope", "pull", "cord")
        description(
            """
            The signal bell and its rope, polished by a thousand gloved pulls. One ring travels all the way up the \
            shaft to the engineer's ear, and the hoisting engineer never sleeps on shift. Allegedly.
            """)
        scenery
    }

    let tack = Item {
        name("haul tack")
        synonyms("collar", "chains", "harness", "singletree", "peg")
        description(
            """
            Haul tack on its peg: collar, trace chains, and a singletree, all sized for a mule who has worn them \
            daily for years.
            """)
        scenery
    }

    // MARK: - The companion

    let biscuit = Actor {
        name("Biscuit")
        adjectives("mine")
        synonyms("mule")
        description(
            """
            A mine mule of no particular color under the dust, built close to the ground and wide through the chest, \
            with the calm of an animal that has spent years around falling rock and formed no opinion of it. He has \
            hauled for you for two years. He knows these roads in the dark better than you know them in the light, \
            and both of you know it.
            """)
        firstSight(
            """
            Biscuit the mine mule stands close by, dusty to the knees, watching you with the patience of an animal \
            who has decided the situation is your job.
            """)
    }

    // MARK: - Verbs

    var verbs: [SyntaxRule] {
        [.drink, .rest, .give, .talk, .ring, .pull, .sit, .pet, .harness]
    }

    // MARK: - Timers

    var timers: [TimedEvent] {
        // Biscuit keeps to your shoulder — silent in the dark, parked by the
        // crawl, resumed at the air-door. Starts co-located, so no turn-one
        // arrival.
        actors.follows(
            biscuit,
            daemonName: "biscuit.follow",
            arrivals: [
                "Hooves on stone, unhurried: Biscuit arrives and stations himself at your shoulder.",
                "A clatter of hooves behind you, and Biscuit is there, close enough to lean on.",
                "Biscuit comes up at his working pace and falls in beside you.",
                "Hooves behind you, and then Biscuit, breathing hay-warm air over your collar.",
                "Biscuit arrives, takes stock of the room in one long look, and settles.",
                "The clip of hooves catches up with you; Biscuit takes his place at your elbow.",
                "Biscuit ambles in after you, in the manner of one who was never in doubt about where you were going.",
                "A nudge at your back announces Biscuit, arrived and expecting to be noticed.",
                "Biscuit walks in and stands where he always stands: half a step behind, on your right.",
                "Hooves, a pause at the threshold, and Biscuit is with you again.",
                "Biscuit catches up without hurry, as though the two of you had agreed on it.",
                "The lamplight finds Biscuit arriving, dusty and punctual.",
            ])

        // Two clocks, one mechanic. Both reset elsewhere: thirst by `drink`,
        // fatigue by `rest` on the straw.
        clock(
            "thirst", fuse: "dehydration",
            tick: {
                let n = thirst + 1
                thirst = n
                return n
            },
            warnings: [
                (
                    12,
                    """
                    Your mouth has gone tacky and your tongue keeps finding the roof of it. Rock dust does that. So \
                    does a shift and a cave-in without water.
                    """
                ),
                (
                    20,
                    """
                    Thirst has stopped being an opinion and started being a fact — a dry, insistent one that gets a \
                    word into every thought you try to finish. Swallowing has become something you do on purpose.
                    """
                ),
                (
                    28,
                    """
                    Your lips have split, there is an ache setting up behind your eyes, and the lamp-flame doubles \
                    when you look at it too long. Drink something soon, or the dark will not need a fall of rock to \
                    finish the job.
                    """
                ),
            ],
            death: """
                The weakness arrives all at once, the way the roof did. Your knees go, the floor comes up with \
                surprising gentleness, and the last thing you hear is hooves on stone, coming near, too late. You \
                died of thirst in the dark, one swallow short of the cage.
                """)

        clock(
            "fatigue", fuse: "collapse",
            tick: {
                let n = fatigue + 1
                fatigue = n
                return n
            },
            warnings: [
                (
                    16,
                    """
                    A yawn ambushes you mid-step. It has, you concede, been a very long day, and it started \
                    underground and got deeper.
                    """
                ),
                (
                    26,
                    """
                    Your eyelids have taken on weight. Twice now you have caught yourself standing still, staring at \
                    the lamp-flame, thinking nothing at all — and down here, thinking nothing at all is how accidents \
                    get their start.
                    """
                ),
                (
                    36,
                    """
                    You are walking asleep, in the technical sense: moving, and no longer entirely present for it. \
                    Find the straw and lie down, or your body will choose a spot on its own authority — and it will \
                    not choose well.
                    """
                ),
            ],
            death: """
                Your body, done waiting, sits you down against the rib "for a moment." The cold of the stone climbs \
                into you with tradesmanlike patience. Something warm noses your cheek once, twice — and gets no \
                answer. You fell asleep in the wrong place, in a world where places matter.
                """)
    }

    /// A failing clock: a counter that ticks once a turn, warnings on the way
    /// down, and a fuse the last warning arms. Thirst and fatigue are the same
    /// mechanic with different numbers and different prose, so they are the
    /// same code with different numbers and different prose.
    ///
    /// The reset lives with whatever relieves the condition: set the counter to
    /// zero and `stopFuse(fuse)`.
    ///
    /// - Parameters:
    ///   - name: the daemon's name.
    ///   - fuseName: the death fuse's name — the last warning arms it, and the
    ///     relieving action stops it.
    ///   - tick: advances the counter and returns its new value.
    ///   - warnings: `(turn, prose)` pairs; reaching the last one arms the fuse.
    ///   - grace: turns between that last warning and the death.
    ///   - death: what the fuse dies on.
    /// - Returns: the clock's daemon and fuse, for the game's `timers` block.
    @TimerBuilder private func clock(
        _ name: String,
        fuse fuseName: String,
        tick: @escaping @Sendable () -> Int,
        warnings: [(turn: Int, prose: String)],
        grace: Int = 8,
        death: String
    ) -> [TimedEvent] {
        daemon(name, autostart: true) {
            let turn = tick()
            guard let warning = warnings.first(where: { $0.turn == turn }) else { return }
            say(warning.prose)
            if turn == warnings.last?.turn {
                startFuse(fuseName, after: grace)
            }
        }
        fuse(fuseName, after: grace) {
            try die(death)
        }
    }

    // MARK: - Default actions for the custom verbs

    var actions: [IntentAction] {
        action(.drink) {
            try reply(
                """
                There is nothing here fit to drink. Mine water is mine water, and a man who drinks it trades a bad \
                day for a worse week.
                """)
        }
        action(.rest) {
            try require(
                player.location == shelterHole,
                else: """
                    Not on bare stone, not in this cold. The shelter hole has straw and a dry floor; your legs will \
                    thank you for the walk.
                    """)
            fatigue = 0
            stopFuse("collapse")
            // A man does not sleep beside an open flame, and oil is a thing
            // there is a finite amount of. You wake needing the striker again.
            capLamp.isLit = false
            try reply(
                """
                You pinch the lamp out first — nobody sleeps next to an open flame, and the oil will be wanted \
                later — and lie down in the straw and let the weight of the shift come off your shoulders. Biscuit \
                stands over you in the dark, head low, doing the watching, turnabout being fair, since you have done \
                his for two years. You wake with your legs answering questions again, in a dark so complete it takes \
                a moment to remember it is not the lamp that failed. The striker is on your belt, where it always is.
                """)
        }
        action(.give) {
            try reply("There is no one here to give it to but yourself, and you already have it.")
        }
        action(.talk) {
            try reply("You say a few words into the dark. The dark, professionally, keeps its own counsel.")
        }
        action(.ring) {
            try reply("There is nothing here worth ringing.")
        }
        action(.pull) {
            try reply("It does not want pulling, and you do not have pulling to spare.")
        }
        action(.sit) {
            try reply("There is nothing here built for sitting, and the floor has already made its offer.")
        }
        action(.pet) {
            try reply("There is nothing here that would care to be petted.")
        }
        action(.harness) {
            try reply("There is nothing here to harness.")
        }
    }

    // MARK: - Scenes reachable by more than one command

    /// One swallow. A canteen has exactly one purpose, so `open canteen` comes
    /// here too rather than being told it does not open — and Biscuit only
    /// supervises when he is actually in the room to do it.
    private func takeASwallow() throws -> Never {
        try require(
            canteenDrinks > 0,
            else: "The canteen is dry, and turning it over one more time will not change that.")
        canteenDrinks -= 1
        thirst = 0
        stopFuse("dehydration")
        let scene = """
            You work the stopper out and drink, counting, the way you were taught to do everything down here — and \
            stop while there is still something to stop for. It goes down cold and tastes of tin, and for a while \
            the dust in your throat lets go. The stopper goes back in, and goes back in tight.
            """
        guard biscuit.isIn(player.location) else { try reply(scene) }
        try reply(
            scene + " "
                + """
                Biscuit watches every swallow with the frankness of an animal who has never once pretended not to \
                want a thing.
                """)
    }

    /// Beat 5, the beam. Reachable as `harness biscuit`, as `harness tack`, and
    /// as `put the collar on the mule` — a player who has never worked a mule
    /// should not have to guess the word a driver would use.
    private func hitchOnAndHaul() throws -> Never {
        try require(
            player.location == shaftBottom,
            else: "There is no haul tack here, and nothing that needs hauling. Not yet.")
        try require(
            !beamHauled,
            else: "The beam is off the gate and Biscuit is done with it. He would rather not be reminded.")
        beamHauled = true
        scoring.awardOnce("beam")
        try reply(
            """
            You back him up to the beam and hitch on, and Biscuit takes the strain the way he takes everything — \
            without ceremony. His shoulders set, his hooves bite, and the beam grinds off the gate an inch at a \
            time until it lies clear. He shakes the dust off and looks around for something else to be better at \
            than you.
            """)
    }

    /// The moment itself, wherever the lifting hand belongs — both discovery
    /// routes end on this sentence, so it is written once.
    private static let theFind = """
        Underneath, where a man keeps what he means to come back for: a tin canteen, stoppered, and full when you \
        shake it.
        """

    /// Beat 2's reward, however you come by it: the mule shows you, or you go
    /// through the corn bin yourself. Either way it scores once.
    private func findTheCanteen() {
        canteen.reveal()
        scoring.awardOnce("canteen")
    }

    // MARK: - Rules

    var rules: Rules {
        // Beat 1 — the striker. Lighting the lamp reveals Biscuit and scores.
        // Only the first time: after a rest you wake in the dark and relight,
        // and that is ordinary lamp business for the default action to handle
        // (it re-describes the room the flame just gave back).
        capLamp.before(.turnOn) {
            try require(
                !capLamp.isLit,
                else: "It is lit. Try to stay ahead of the things that are actually wrong.")
            guard !lampFirstLit else {
                try proceed()
                return
            }
            lampFirstLit = true
            capLamp.isLit = true
            scoring.awardOnce("lamp")
            try reply(
                """
                The flame takes on the second strike, steadies, and the dark steps back to a respectful distance. The \
                first thing the light finds is a long mild face, inches from yours, ears forward — Biscuit, of \
                course, dusty to the knees and entirely unsurprised. Whatever happens next, you will not be doing it \
                alone.
                """)
        }
        capLamp.describe {
            capLamp.isLit
                ? "Your cap-lamp, burning small and steady — a modest flame with a large responsibility."
                : """
                Your cap-lamp, out cold, smelling of oil and recent failure. The flint striker on your belt has \
                opinions about that.
                """
        }

        // Beat 2 — the nose-out. It waits on Biscuit rather than on the door:
        // the follow daemon ticks after this rule, so on the turn you walk in
        // he is still a room behind and the beat holds. It lands the turn after
        // his arrival line instead of on top of it.
        stable.afterEachTurn {
            guard capLamp.isLit, !canteen.isRevealed, biscuit.isIn(stable) else { return }
            findTheCanteen()
            say(
                """
                Biscuit walks straight past his own stall — past the hay, past the dry trough — and puts his nose \
                under the loose board at the foot of the corn bin, lifting it with the ease of long practice. \
                \(Self.theFind) He looks from it to you and back, in case you are slow this morning.
                """)
        }

        // …and the same find, made the hard way. The beat belongs to the mule,
        // but the only water in the workings must not depend on the player
        // happening to linger, so the loose board gives it up to anyone who
        // takes the room's own prose at its word and goes through the bin.
        cornBin.before(.lookIn) {
            guard !canteen.isRevealed else {
                try reply("Nothing else under the board but corn dust and the smell of a better week.")
            }
            findTheCanteen()
            try reply(
                """
                You get a hand under the loose board and lift, and it comes up the way things do when somebody has \
                been lifting them for years. \(Self.theFind) Biscuit, when you look up, has the expression of an \
                animal who was about to mention it.
                """)
        }

        // Beat 4 — the crawl. Entering it parks Biscuit at the Forks: the follow
        // daemon stops before it can tick him into a gap a mule cannot use.
        lowCrawl.onEnter {
            stopDaemon("biscuit.follow")
            guard !crawlBeatDone else { return }
            crawlBeatDone = true
            say(
                """
                You get down on your hands and knees at the edge of the fall, where the rock left a gap a man can use \
                if he is honest about his size. Biscuit tries to follow — one hoof, then a knock of his head against \
                stone — and cannot. The bray that follows you into the crawl is the most reproachful sound you have \
                ever heard from anything on four legs. It recedes behind you, complaining, until the stone shuts it \
                out altogether.
                """)
        }

        // The two-way air-door: once it is open, arriving at the Shaft Bottom
        // resumes the follow daemon so Biscuit catches up through it.
        shaftBottom.onEnter {
            guard airDoor.isOpen else { return }
            startDaemon("biscuit.follow")
        }

        // The door has a bad side and a good one, and which you are looking at
        // decides what it tells you. From the Forks it is a wall; from the shaft
        // it is a bar waiting to be lifted, and it must not read as hopeless.
        airDoor.describe {
            if airDoor.isOpen {
                """
                The air-door stands wide on its hinges, and the ventilation goes through it the way it was meant to \
                all along.
                """
            } else if player.location == forks {
                """
                A stout ventilation door, built to swing easy and seal tight. The fall racked its frame and it is \
                jammed hard into it from this side; the bar, naturally, is on the other.
                """
            } else {
                """
                A stout ventilation door, built to swing easy and seal tight. The frame is racked, so it will never \
                be pushed open from the far side — but the bar is on this side, and a bar is a thing that lifts.
                """
            }
        }

        // Rejoin — opening the air-door from the shaft side. From the Forks side
        // it refuses (§8).
        airDoor.before(.open) {
            try require(
                !airDoor.isOpen,
                else: "The air-door already stands open; it needs nothing further from you.")
            if player.location == forks {
                try refuse(
                    """
                    You put your shoulder to it and the door declines, politely but with the whole weight of the \
                    racked frame behind the refusal. If it opens at all, it opens from the far side.
                    """)
            }
            airDoor.isOpen = true
            scoring.awardOnce("door")
            biscuit.move(to: shaftBottom)
            startDaemon("biscuit.follow")
            try reply(
                """
                The door is jammed from the far side, but from here the bar lifts like it was waiting for you, and \
                the door swings wide with a groan of old hinges. Ventilation sighs through the opening — and so does \
                Biscuit, arriving at a businesslike trot, pressing his forehead against your chest hard enough to \
                stagger you. Apology accepted, apparently. Provisionally.
                """)
        }

        // Beat 5 — the beam. Harnessed, Biscuit hauls it clear of the gate.
        // Harnessing the mule and harnessing the tack are the same act, and so
        // is putting the collar on him, so all three roads lead to the haul.
        biscuit.before(.harness) {
            try hitchOnAndHaul()
        }
        tack.before(.harness) {
            try hitchOnAndHaul()
        }
        // "put the collar on the mule" — he is the indirect object here, so the
        // rule hangs on him rather than on the tack.
        biscuit.before(.putOn) {
            guard command.directObject == tack else { return }
            try hitchOnAndHaul()
        }
        beam.before(.push, .take, .pull) {
            try reply(
                """
                You get your back under one end and achieve, at considerable cost, nothing. It wants hauling, not \
                heroics — and hauling is a trade with a professional standing eight feet away.
                """)
        }
        tack.before(.take) {
            try reply(
                """
                The collar alone is most of what you can lift, and none of it is any use on your shoulders. It goes \
                on the mule, or it stays on the peg.
                """)
        }
        bell.before(.take) {
            try reply("Bell, rope, and bracket are all one thing, and that thing is bolted to the wall.")
        }

        // The striker stays on the belt. That is not sentiment; it is procedure.
        striker.before(.drop, .putIn, .putOn) {
            try reply(
                """
                Not down here. It goes on your belt and it stays on your belt, which is a rule you have never once \
                been tempted to test.
                """)
        }
        striker.before(.turnOn) {
            try reply("The striker lights the lamp. Light the lamp.")
        }

        // The ending — ring the bell once the beam is clear. The rope invites
        // pulling as much as the bell invites ringing, so both come here.
        bell.before(.ring, .pull) {
            try require(
                beamHauled,
                else: """
                    You could ring, and the cage could come, and it could sit there on the far side of a gate with a \
                    twelve-foot beam across it while everyone above forms opinions. Shift the beam first.
                    """)
            scoring.awardOnce("bell")
            say(
                """
                You take the pull and ring — one long stroke, and the sound goes up the shaft like a bird out of a \
                trap. A pause, long enough to fit a whole day's fear into. Then, faint and far above, the answering \
                signal: heard, coming.

                The cage comes down singing on its guides, and the cager steps out of it already talking — they had \
                you marked for lost, the men are still two days from the far side of that fall, how in God's name — \
                and stops, because Biscuit has stepped forward to inspect the cage in a proprietary manner.

                A mule cannot climb a ladderway, and the sling goes on him first — he suffers it with the dignity of \
                long practice, and rises out of sight glaring like a parcel with opinions. The cage comes back for \
                you. The gate rings shut, the deck lifts, and the dark of the workings drops away beneath your boots, \
                already turning back into geography.

                Outside, they say, it is raining — soft, gray, spring rain. Biscuit has not stood in rain for four \
                years. You find you are glad it will be the first thing he gets.
                """)
            try end(won: true)
        }

        // Drinking — the canteen holds three swallows and is the only water in
        // the workings; each one resets the clock (§9). Opening it is the same
        // act by another name: there is nothing in a canteen but the drink.
        canteen.before(.drink, .open) {
            try takeASwallow()
        }
        canteen.before(.close) {
            try reply("The stopper is in. You saw to that yourself, the way you were taught.")
        }
        trough.before(.drink) {
            try reply("Dry as a flue, and dry since the roof came down. You knew that before you asked.")
        }

        // The canteen counts down what is left of the only water there is.
        canteen.describe {
            switch canteenDrinks {
            case 3:
                """
                A day-shift canteen, tin, stoppered tight, and — you shake it to be sure — full. It is the only \
                water in these workings, and you have already started doing arithmetic with it.
                """
            case 2:
                """
                A tin canteen, better than half of it left. The arithmetic still comes out, provided nothing else \
                goes wrong today.
                """
            case 1:
                """
                A tin canteen with one swallow in it, which is a thing you would rather not know quite so precisely.
                """
            default:
                "A tin canteen, dry, and light as a lie. It did what it could."
            }
        }

        // Sharing water with Biscuit — a real cost, and thirst does NOT reset (§7).
        biscuit.before(.give) {
            guard let obj = command.directObject else {
                try reply("Give him what?")
            }
            // Handing him the collar is not a gift; it is asking him to work.
            if obj == tack {
                try hitchOnAndHaul()
            }
            guard obj == canteen else {
                try reply(
                    "He lips at it, works out that it is not water, and returns it to your keeping, disappointed.")
            }
            try require(
                canteenDrinks > 0,
                else: "The canteen is dry, and he told you so with his nose before you got the stopper out.")
            canteenDrinks -= 1
            try reply(
                """
                You cup your hand and pour, and he takes it in one long pull that empties your palm and then asks, \
                politely, for the rest. It was yours, and you will feel the lack of it — but he has hauled all shift \
                on hay and promises, and some debts you pay when you can.
                """)
        }

        // Canned reactions with the mule (§7).
        actors.reaction(
            of: biscuit, to: [.talk],
            reply: """
                You tell him how it stands: the fall, the door, the shaft. He listens the way he always does — one \
                ear on you, one on the roof — and when you finish he breathes warm air down your collar, which is as \
                close as he comes to signing off on a plan.
                """)
        actors.reaction(
            of: biscuit, to: [.pet],
            reply: """
                You scratch the spot under his forelock, and he leans into it until keeping your feet becomes a \
                genuine question of engineering.
                """)

        // Sitting: the bench obliges, the straw would rather you committed.
        bench.before(.sit) {
            try reply(
                """
                You sit, because it is there and your legs have opinions. It is a good bench, cut for men waiting on \
                a trip that is not coming. After a minute you stand again — sitting is not resting, and the straw is \
                one step away.
                """)
        }
        straw.before(.sit) {
            try reply("Sitting in it wastes it. The straw is a bed; lie down in it and rest, and mean it.")
        }

        // The bad air, north past an absent Biscuit — the backstop death (§9).
        oldWorks.onEnter {
            try die(
                """
                Three steps into the old works the sweetness in the air turns syrup-thick, and the fourth step is a \
                stumble. The lamp-flame stretches tall and blue as a crocus, which is very beautiful, and means you \
                are already dead. The mule would have stopped you; the mule was not there to.
                """)
        }
    }

    // MARK: - Map

    var map: WorldMap {
        // The shelter hole is "a step down to the south" — so `down` reaches it
        // too, and `up` comes back out.
        freshFall.west(stable)
        freshFall.east(forks)
        freshFall.south(shelterHole)
        freshFall.down(shelterHole)
        freshFall.exit(
            .north,
            blocked: """
                The roof has been down an hour and has no plans to get up. The men above will timber their way \
                through from the far side in a day or three; you do not currently have a day or three to sit here \
                being brave about it.
                """)

        stable.east(freshFall)

        shelterHole.north(freshFall)
        shelterHole.up(freshFall)

        // North into the old works is barred while Biscuit stands across it
        // (beat 3); lethal only if he is somehow gone (the gas death backstop).
        forks.west(freshFall)
        forks.east(lowCrawl)
        forks.exit(
            .north,
            to: oldWorks,
            when: { !biscuit.isIn(forks) },
            otherwise: """
                Biscuit puts himself across the mouth of the old works like a bolted gate. Head low, feet planted; \
                when you press, he leans his whole patient weight against you and pushes you back a step. He has \
                walked past bad air before, and he can smell what you cannot. The old works stay shut, says the \
                mule, and the mule has seniority.
                """)

        lowCrawl.east(shaftBottom)
        lowCrawl.west(forks)

        // The air-door is barred from this side until opened at the shaft;
        // once open it is a true two-way route back toward the shelter hole.
        shaftBottom.west(forks, via: airDoor)

        player.starts(in: freshFall)
        biscuit.starts(in: freshFall)  // co-located: no spurious turn-one arrival

        capLamp.startsHeld
        striker.startsHeld

        rubble.starts(in: freshFall)
        rails.starts(in: freshFall)

        hay.starts(in: stable)
        stall.starts(in: stable)
        trough.starts(in: stable)
        cornBin.starts(in: stable)
        canteen.starts(in: stable)

        straw.starts(in: shelterHole)
        bench.starts(in: shelterHole)

        airDoor.starts(in: forks)
        crawl.starts(in: forks)
        oldHeading.starts(in: forks)

        beam.starts(in: shaftBottom)
        bell.starts(in: shaftBottom)
        tack.starts(in: shaftBottom)
        shaft.starts(in: shaftBottom)
        cageGate.starts(in: shaftBottom)
    }
}
