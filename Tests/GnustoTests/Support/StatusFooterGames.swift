import Gnusto

/// A content bundle that contributes two status-footer fields.
///
/// `weather` reads a `@Global`, which only works inside a live turn frame — so
/// the bundle proves the field is evaluated in one rather than at bootstrap.
///
/// `readings` is deliberately *mutating*, which the contract forbids: it is
/// here so a test can pin the documented consequence. The frame the fields run
/// in is a throwaway that `GameWorld.statusFields()` discards, so the write
/// goes nowhere and the reading reads 1 forever, however many turns pass.
struct WeatherReport: GameContent {
    @Global var barometer = 30
    @Global var readings = 0

    var statusFields: [(String, String)] {
        readings += 1
        return [
            ("weather", barometer > 29 ? "fair" : "foul"),
            ("readings", "\(readings)"),
        ]
    }

    /// Moves the glass, from inside a live turn — the `Clock.advance(by:)`
    /// shape, so the host writes bundle state through the bundle.
    func dropTheGlass() {
        barometer = 28
    }
}

/// A logic-only plugin that contributes a status field. A plugin owns no state,
/// so its field is a constant; what it is here to prove is that the bootstrap
/// finds a plugin the host merely *stores* — the one thing a plugin
/// contributes without the host splicing it.
struct LanternDial: GamePlugin {
    var statusFields: [(String, String)] { [("lamp", "trimmed")] }
}

/// One room, one bundle, one plugin, and a verb for dropping the glass so a
/// test can watch a contributed field change.
struct WeatherStation: Game {
    let title = "Weather Station"
    let intro = "Rain on the roof, and a needle to read."

    let weather = WeatherReport()
    let dial = LanternDial()

    let deck = Location {
        name("Observation Deck")
        description("A railed platform with a brass barometer bolted to the post.")
    }

    var content: GameContents { weather }

    var actions: [IntentAction] {
        action(.dig) {
            weather.dropTheGlass()
            say("The needle drops.")
        }
    }

    var map: WorldMap {
        player.starts(in: deck)
    }
}
