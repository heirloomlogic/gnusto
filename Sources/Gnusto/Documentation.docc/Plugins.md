# Plugins

Package a reusable game system as an importable unit of verbs and rules.

## Overview

A content bundle (<doc:ContentBundles>) splits a game's own world across types and packages. A plugin does something else: it packages a reusable *system* — spellcasting, a wall clock, combat — so a second game can import it. The seven `Gnusto*` libraries in this repo are all built this way, and so is the `buy`/`sell` logic you would otherwise hand-copy into every shop game.

A plugin is **logic only**. It contributes the vocabulary its system needs and the rules that react to it, and owns no rooms, items, or `@Global` state; everything it touches is declared by the host game and handed to it as a parameter. A plugin that needs a room of its own is not a plugin.

## A plugin is a `GamePlugin`

```swift
extension Intent {
    #verb("haggle", ["haggle", "over", .directObject])
}

struct CommercePlugin: GamePlugin {
    var verbs: [SyntaxRule] {
        .haggle
    }
}
```

`verbs`, `actions`, `rules`, and `timers` all default to empty, so a plugin declares only what it needs. The `#verb` declarations (see <doc:AddingCustomVerbs>) give the plugin *and* its hosts the same typed constants — host rules key on `.haggle` exactly as the plugin's verbs emit it.

Note what *isn't* declared here. `buy` and `sell` are engine stub verbs (see <doc:StubVerbs>), so the words are already in every game's vocabulary; a commerce plugin only has to supply the behavior, which it does with the rules below. `haggle` is genuinely the plugin's own, so it needs the `#verb`. `GnustoMeleeCombat` splits the same way: the `attack` family is promoted, `stab` and `strike` are added.

A plugin's `timers` splice the same way (`var timers: [TimedEvent] { actors.timers }`), and parameterized timer *factories* — methods returning a ``TimedEvent`` for the host's own `timers` block — are how a plugin animates the host's actors on the end-of-turn clock. A bare timer name the host or another bundle also declares is namespaced into the declaring bundle's namespace at bootstrap, so prefixes are a courtesy rather than a requirement (`"actors.roam"`) — but an unambiguous name keeps its bare schedule key, which is also its save-file key.

## The host splices verbs and rules

The host stores the plugin as a plain property and splices its vocabulary into its own `verbs` block. A plain plugin property is neither a ``Location``, ``Item``, nor `@Global`, so the bootstrap's reflection walk ignores it — it never becomes an entity and never collides.

`.price` below is a `TraitKey<Int>` declared once (`extension TraitKey<Int> { static let price = Self("price") }`) — see <doc:CustomStateAndTraits>.

```swift
struct LampShop: Game {
    let commerce = CommercePlugin()
    @Global var purse = Purse(coins: 10)          // the HOST owns the wallet
    let lantern = Item { name("brass lantern"); trait(.price, 5) }

    var verbs: [SyntaxRule] { commerce.verbs }    // splice the vocabulary
    // rules below
}
```

## Parameterized rules over host entities

The plugin's rules need the host's own lantern and purse — things it can't know about in advance. So rules that touch host state are exposed as **parameterized methods** returning ``Rules``, which the host calls with its own declarations. The wallet is handed in as closures that read and adjust the host's `@Global`; they run under the live turn, so they see and mutate state exactly as an inline rule would.

```swift
extension CommercePlugin {
    @RuleBuilder
    func purchase(
        of item: Item,
        balance: @escaping @Sendable () -> Int,
        charge:  @escaping @Sendable (Int) -> Void
    ) -> Rules {
        item.before(.buy) {
            let price = item[.price] ?? 0
            guard balance() >= price else {
                try refuse("You can't afford the \(item.name); it costs \(price) coins.")
            }
            charge(price)
            try reply("You buy the \(item.name) for \(price) coins. You have \(balance()) left.")
        }
    }
}

// in the host:
var rules: Rules {
    commerce.purchase(of: lantern,
                      balance: { purse.coins },
                      charge:  { purse.coins -= $0 })
}
```

The protocol's own `rules` requirement is for self-contained, world-scoped rules that need nothing from the host; anything host-specific goes through a factory method like this.

## A plugin can contribute only vocabulary

The rules are optional. A plugin can teach the parser a word and leave the behavior to the host, which handles the shared intent in its own `rules`:

```swift
extension Intent {
    #verb("appraise", ["appraise", .directObject])
}

struct Appraiser: GamePlugin {
    var verbs: [SyntaxRule] {
        .appraise
    }
}

// in the host:
var rules: Rules {
    gem.before(.appraise) {
        try reply("The \(gem.name) is worth \(gem[.price] ?? 0) coins.")
    }
}
```

## The one thing the host doesn't splice

``GamePlugin/statusFields`` adds `name=value` pairs to the play-test status footer, and it is the single member the host gets by *storing* the plugin rather than by splicing it into a block of its own:

```swift
struct Barometer: GamePlugin {
    var statusFields: [(String, String)] { [("glass", "falling")] }
}
```

Everything else here changes what the game does, so the host opts in by hand. A status field annotates a transcript the host already asked for and changes nothing about the world — and there is no `Game` block to splice it into — so the bootstrap reads it off the host's stored properties, the same walk that catches an unlisted bundle. A plugin the host stores is found; one constructed inline inside a computed property is not.

The field is read inside a live turn frame that is then discarded, so it must be read-only — and it is sampled at the *close* of the turn rather than after the turn's counter advanced, so a field derived from `moves` names the turn it is printed under. See <doc:ContentBundles#A-bundle-can-add-a-field-to-the-status-footer> for the full contract, sampling point included, which is identical for both protocols.

## Content-bearing plugins own their region

A logic-only ``GamePlugin`` declares no world of its own — it operates entirely over entities the host passes it. A plugin that needs to ship its *own* rooms, items, and `@Global` state is a <doc:ContentBundles> instead: a ``GameContent`` carries `map`, `rules`, and `verbs`, and the bootstrap discovers its entities by reflection, [namespacing](<doc:ContentBundles#EntityIDs-are-namespaced-by-the-bundle>) them under the bundle so a reusable plugin can't collide with the host. List it in the game's `content`.

The two roles compose in one type. A single struct can conform to ``GameContent`` (for its auto-namespaced region and self-contained rules) **and** expose host-facing rule factories exactly like a ``GamePlugin`` — factories are just methods returning ``Rules``, so any type can offer them:

```swift
extension Intent {
    #verb("donate", ["donate", .directObject])
}

struct ShrineContent: GameContent {
    let shrine = Location { name("Stone Shrine"); description("…") }   // its own room
    @Global var visits = 0                                             // its own state

    var verbs: [SyntaxRule] { .donate }
    var rules: Rules { shrine.onEnter { visits += 1; try reply("…") } }  // self-contained

    // Host-facing factory over a host item + host global — the GamePlugin pattern.
    func offering(of item: Item,
                  merit: @escaping @Sendable () -> Int,
                  credit: @escaping @Sendable (Int) -> Void) -> Rules {
        item.before(.donate) { credit(item[.value] ?? 0)
            try reply("Your merit rises to \(merit()).") }
    }
}
```

The host lists it in `content` (registering the namespaced region) **and** splices the factory into its own `rules`, wiring it to host declarations:

```swift
struct PilgrimGame: Game {
    let shrineKit = ShrineContent()
    @Global var merit = 0
    let coin = Item { name("brass coin"); trait(.value, 7) }

    var content: GameContents { shrineKit }
    var verbs: [SyntaxRule] { shrineKit.verbs }
    var rules: Rules {
        shrineKit.offering(of: coin, merit: { merit }, credit: { merit += $0 })
    }
    // map: place coin in shrineKit.shrine, wire plaza ↔ shrineKit.shrine, …
}
```

References stay token-based across the boundary, so a host item can sit in a plugin room and a plugin rule can hook a host entity regardless of the namespace.

## The first-party plugins

Seven shipped library products exercise both plugin shapes for real — each
imports only `Gnusto`, and the Zork 1 executable target is the worked
example that wires the first four:

| Product | Shape | Owns | The host passes |
| --- | --- | --- | --- |
| `GnustoDangerousDark` | `GameContent` | one dark-turn counter, the grue daemon | prose + grace period at init; `suspended` to make the dark harmless for a stretch (never `stopDaemon("grue")`, which freezes the count) |
| `GnustoScoring` | `GameContent` | award-once registers | the award table to `init(awards:)`, treasures + the trophy case to `treasures(_:into:)` |
| `GnustoActors` | `GamePlugin` | nothing — position *is* the actor's placement | actors, room sets, candidates to `roams`/`steals`/`reaction` |
| `GnustoMeleeCombat` | `GameContent` | the combat ledger (health/stun/engagement by key) | villains, weapons, prose to `villain`/`aggression`, and each villain's `strikesFirst` odds of picking a fight nobody offered him |
| `GnustoSpellcasting` | `GameContent` | the spell memory and the energy pool | spells + their `SpellCost` to `spell(_:cost:effect:)` |
| `GnustoClock` | `GameContent` | the clock's offset and pause state | start time, minutes per turn, alarms to `at(_:named:perform:)`, timetables to `schedule(_:daemonName:_:)` |
| `GnustoConversation` | `GameContent` | the facts the player has worked out, and which answers each actor has already given | actors + topic rows to `topics(of:)` (with `again:` lines for the answers that should land once), opening lines to `greeting(of:)`, evidence to `shows(_:to:)` |

The split follows one rule: a system that needs its own saved state is a
`GameContent` bundle (its `@Global`s namespace automatically and travel in
saves); a stateless toolkit is a `GamePlugin`. Plugin prose arrives as
**init and factory parameters** with sensible defaults — ``GameText`` is a
fixed struct, so a plugin can't add lines to it retroactively; what it can
do is take its lines from the host, which also keeps every player-visible
string in the game's own voice.

## Worked examples

- `Sources/Lighthouse/` — a small host that splices just two: `GnustoScoring` (a `visit` award and a one-off `awardOnce`, both declared in its award table so the bootstrap can check `maxScore`) and `GnustoActors` (a roaming keeper). The smallest of these examples.
- `Sources/Zork1/Zork1.swift` — the host that wires four first-party plugins over entities from three content bundles.
- `Sources/Gramarye/Gramarye.swift` — a small original game built entirely around `GnustoSpellcasting`, with one puzzle per casting paradigm.
- `Sources/Fulminate/Fulminate.swift` — the mystery demo, built around `GnustoClock`: an evening on a wall clock with three alarms bracketing it. Its story and mechanics contract live in `docs/games/fulminate.md`.
- `Sources/KindlyDeep/` — a survival-and-companion host: `GnustoActors.follows` for a mule who trails you, is parked by a crawl he cannot fit through, and rejoins through a door, plus `GnustoScoring.awardOnce` on each of its five beats.
- `Tests/GnustoTests/Support/CommerceGame.swift` — the logic-only commerce plugin (`buy`/`sell` verbs, `purchase`/`sale` factories, `LampShop` host); `PluginTests` drives a buy/sell turn end to end.
- `Tests/GnustoTests/Support/ShrineContent.swift` — the content-bearing `ShrineContent` plugin (owns a namespaced shrine region *and* exposes an `offering` factory) with its `PilgrimGame` host; `ContentPluginTests` drives a donate turn across the namespace boundary and checks the namespacing.
