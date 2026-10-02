import Gnusto

extension Intent {
    #verb(
        "redirectRelay", ["relay", .directObject, "at", .indirectObject], ["relay", .direction],
        ["relay", "about", .topic])
}

struct RedirectProbeGame: Game {
    enum Mode: Sendable {
        case normal, refused, replied, unhandled, laterUnhandled, unreachable, chained, grouped, cycle, before, after,
            earlyDefault,
            meta, engine
    }

    let mode: Mode
    init() { mode = .normal }
    init(mode: Mode) { self.mode = mode }
    let title = "Redirect Probe"
    let intro = "A testing room."
    let lab = Location { name("Lab") }
    let rod = Item { name("rod") }
    let dummy = Item { name("dummy") }
    let box = Item {
        name("box")
        container
    }
    @Global var upkeeps = 0
    @Global var changes = 0
    @Global var ticks = 0

    static let hit = Intent("redirectHit")
    static let bridge = Intent("redirectBridge")
    static let missing = Intent("redirectMissing")

    var map: WorldMap {
        player.starts(in: lab)
        rod.starts(in: lab)
        dummy.starts(in: lab)
        box.starts(in: lab)
    }

    var verbs: [SyntaxRule] { .redirectRelay }

    var actions: [IntentAction] {
        action(.redirectRelay, reach: .bothObjects) {
            changes += 1
            say("[relay-default]")
            switch mode {
            case .unhandled:
                try redirect(to: Self.missing, directObject: dummy)
            case .chained:
                try redirect(to: Self.bridge, directObject: dummy, indirectObject: rod)
            case .meta:
                try redirect(to: .undo)
            case .engine:
                try redirect(to: .again)
            default:
                try redirect(to: Self.hit, directObject: dummy, indirectObject: rod, preposition: "with")
            }
        }
        action(Self.bridge, reach: .bothObjects) {
            say("[bridge-default]")
            try redirect(to: Self.hit, directObject: dummy, indirectObject: rod, preposition: "with")
        }
        action(Self.hit, reach: .bothObjects) {
            if mode == .cycle {
                try redirect(to: Self.hit, directObject: dummy, indirectObject: rod)
            }
            if mode == .refused { try refuse("[hit-refused]") }
            changes += 1
            if mode == .laterUnhandled { rod.moveToPlayer() }
            say("[hit-default]")
            say(
                "slots=\(command.directObject == dummy):\(command.indirectObject == rod):\(command.preposition ?? "nil")"
            )
            say("typed=\(command.verbPhrase):\(command.rawInput)")
            say("direction=\(command.direction == .north);topic=\(command.topic?.text ?? "nil")")
        }
        action(.putIn, reach: .bothObjects, overriding: true) {
            say("[put-default]")
            if mode == .unhandled || (mode == .laterUnhandled && command.directObject == dummy) {
                try redirect(to: Self.missing, directObject: command.directObject)
            }
            try redirect(to: Self.hit, directObject: command.directObject, indirectObject: rod)
        }
    }

    var rules: Rules {
        dummy.reach(otherwise: "[hit-unreachable]") {
            command.intent != Self.hit || mode != .unreachable
        }
        world.beforeEachTurn {
            upkeeps += 1
            say("[upkeep]")
        }
        world.before(.redirectRelay) {
            say("[relay-world]")
            if mode == .before { try redirect(to: Self.hit) }
            if mode == .earlyDefault { try proceed() }
        }
        lab.before(.redirectRelay) { say("[relay-room]") }
        dummy.before(.redirectRelay) { say("[relay-indirect]") }
        rod.before(.redirectRelay) { say("[relay-direct]") }
        world.before(Self.hit) { say("[hit-world]") }
        lab.before(Self.hit) { say("[hit-room]") }
        rod.before(Self.hit) { say("[hit-indirect]") }
        dummy.before(Self.hit) {
            say("[hit-direct]")
            if mode == .replied { try reply("[hit-replied]") }
        }
        dummy.after(Self.hit) {
            say("[hit-direct-after]")
            if mode == .after { try redirect(to: Self.hit) }
        }
        rod.after(Self.hit) { say("[hit-indirect-after]") }
        lab.after(Self.hit) { say("[hit-room-after]") }
        world.after(Self.hit) { say("[hit-world-after]") }
        world.after(.redirectRelay) { say("[relay-after-must-not-run]") }
        world.afterEachTurn {
            say("[epilogue=\(command.intent == .redirectRelay)]")
        }
    }

    var timers: [TimedEvent] {
        daemon("pulse", autostart: true) {
            ticks += 1
            say("[tick]")
        }
    }
}
