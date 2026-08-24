import Gnusto

/// A fixture for ``Earshot``: a charge going off in a quarry, two rooms that
/// hear it, and a farmhouse over the hill that does not — though the farmhouse
/// is one step from the track, which does, because an earshot is a list and not
/// a radius.
///
/// The blast sets a flag before it speaks, so every test can ask whether the
/// world moved on a turn the player was told nothing.
struct EarshotGame: Game {
    let title = "Earshot"
    let intro = "A quarry, a track, a hut, and a farmhouse over the hill."

    let quarry = Location {
        name("Quarry")
        description("A bitten-out half-bowl of limestone.")
    }

    let track = Location {
        name("Track")
        description("Two ruts and a strip of grass between them.")
    }

    let hut = Location {
        name("Hut")
        description("A powder hut with a tin roof.")
    }

    let farmhouse = Location {
        name("Farmhouse")
        description("A kitchen with the range banked low.")
    }

    @Global var blasted = false
    @Global var rooksHeard = 0

    /// Everywhere the quarry is heard from. Not the farmhouse: it is over the
    /// hill and behind a shut door, one move from the track and out of earshot
    /// all the same.
    var withinEarshot: Earshot {
        Earshot(quarry, track, hut)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("prime", intent: Intent("prime"))
        SyntaxRule("report", intent: Intent("report"))
    }

    var timers: [TimedEvent] {
        fuse("blast", after: 3) {
            blasted = true
            say("A charge goes off in the quarry.", from: withinEarshot)
        }
        // The same gate with its list written inline: #305's spelling, kept
        // honest against the hoisted one by carrying to a different set.
        fuse("whistle", after: 3) {
            say("A whistle blows down at the quarry.", from: quarry, hut)
        }
        daemon("rooks", autostart: true) {
            guard withinEarshot.contains(player.location) else { return }
            rooksHeard += 1
        }
    }

    var rules: Rules {
        world.before(Intent("prime")) {
            startFuse("blast")
            startFuse("whistle")
            try reply("Primed.")
        }
        world.before(Intent("report")) {
            try reply("Blasted: \(blasted). Rooks: \(rooksHeard).")
        }
    }

    var map: WorldMap {
        quarry.north(track)
        track.south(quarry)
        track.east(hut)
        hut.west(track)
        track.north(farmhouse)
        farmhouse.south(track)
        player.starts(in: quarry)
    }
}
