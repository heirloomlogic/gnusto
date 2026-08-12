# Containers, Doors, and Locks

Hold things, open and close, lock with keys, and gate the map.

## Overview

Most of what makes a world feel physical comes from a small family of item traits: things you can put objects **on** or **inside**, things that **open and close**, things a **key** locks, and **doors** that gate one room from the next. All of them are declared the same way as any other trait — a word inside an `Item { … }` block, or, for the lock/key relationship, one line in the `map` — and all of them expose live state you can read and set from a rule.

For the traits themselves see ``ItemTrait``; for writing the rules that react to them see <doc:WritingRules>.

## Surfaces and containers

A ``surface`` is something other items can rest **on**; a ``container`` is something they can go **inside**. Declaring the trait is all it takes — the parser then accepts `put book on table` and `put coin in box`, and the items travel with their holder.

```swift
let table = Item {
    name("wooden table")
    description("A sturdy oak table.")
    surface
    scenery
}

let sack = Item {
    name("brown sack")
    adjectives("brown")
    description("A soft brown sack.")
    container
    openable
}
```

Cap how much a container holds with ``capacity(_:)`` — the put-in action refuses once it's full:

```swift
let basket = Item {
    name("wicker basket")
    container
    capacity(3)
}
```

Inside a rule, the live relationships are:

- ``Item/holds(_:)`` — is that item on or inside this one?
- ``Item/contents`` — everything currently on or inside it, sorted for stable iteration.
- ``Item/move(inside:)`` and ``Item/move(onto:)`` — place an item directly, bypassing the parser (they trap if the target isn't a container or surface).

```swift
box.after(.open) {
    if box.holds(gem) {
        say("Nestled inside is a glittering gem.")
    }
}
```

### Which room is it in?

Those three all read *downward*, from a holder to what it holds. ``Item/location`` reads the other way: it walks up the containment chain and answers the room at the top, or `nil` while the item is offstage.

```swift
daemon("bloodhound") {
    guard let scent = quarry.location, scent != player.location else { return }
    say("The hound strains toward the \(scent.name).")
}
```

The walk is what makes it worth having. A coin inside a sack on a table in the Hall answers the Hall, and so does the sack, and so does the table — where ``Item/isIn(_:)`` tests one link and would answer `false` for the coin. Something in the player's hands answers wherever the player is standing; something in an actor's hands answers wherever *they* are, which is the distinction ``Player/location`` cannot make on an item's behalf. It costs the depth of the nesting, so it is the thing to reach for rather than scanning a hand-written list of rooms for the one that ``Location/contains(_:)`` says yes to.

It is not a scope question. An item locked in a closed box still answers the box's room, and so does one in the dark — for what the player can see or touch, ask ``Item/isVisible`` or ``Item/isReachable``. ``Actor/location`` is the same accessor; an actor is only ever in a room or nowhere, so for them the walk is a single step.

## Opening and closing

A bare ``container`` is *always open* — its contents are reachable at all times. Add ``openable`` to give it a lid the player must work: an openable item **starts closed** unless it also declares ``startsOpen``. The parser handles `open sack` and `close sack`; a closed container hides and blocks its contents.

```swift
let chest = Item {
    name("treasure chest")
    container
    openable          // starts closed
}

let cupboard = Item {
    name("cupboard")
    container
    openable
    startsOpen        // begins the game open
}
```

``transparent`` splits the difference: the contents are *visible* even while the item is closed — a glass jar, a display case — but still not *reachable* until it's opened. (The same trait lets light through a shut container; see <doc:DarknessTimeAndDeath>.)

Whatever a room can see inside a container it lists, one level down, as *"In the glass jar is a green pickle."* — unless the pickle has a line of its own. ``firstSight(_:)`` and ``Item/presence(_:)`` are consulted here exactly as they are for something lying on the floor, so a thing that starts nested announces itself in its own words; see <doc:WritingRules>. A ``scenery`` fitting is listed neither way, which is how the fixed parts of a container stay out of a paragraph its description has already covered.

One level is where the listing stops. A room description walks what stands in the room and what those things hold, and no further — a deeper walk would read as a manifest rather than a scene — so a jar inside a crate keeps its pickle out of the room's paragraph entirely. Nothing is out of reach; `look in jar` still answers. But a line declared down there can never print, and because a line that never prints reads exactly like a line that does, the bootstrap warns for one: *item "pickle" declares firstSight(…) but the map places it 2 levels below the room…*. Move the thing up a level, or let the container's own description carry the sentence.

That is the *room's* rule, and it stops there. `open jar` and `look in jar` **do** name a fitting: they enumerate what is inside a thing, where a room description composes prose about it, and a player who has asked what is in the jar is owed the whole answer — a jar holding nothing but fittings reports them rather than calling itself empty. The two disagree by design; ``scenery`` says why.

```swift
let jar = Item {
    name("glass jar")
    container
    openable
    transparent       // you can see what's inside a closed jar; you can't take it yet
}
```

Read and set the state with ``Item/isOpen``. It reflects the current state of an openable item; assigning to something that isn't openable is a harmless no-op.

```swift
lid.after(.push) {
    chest.isOpen = true
    say("The lid swings back.")
}
```

## Asking whether the player can get at it

*Visible* and *reachable* are the two sets the engine sorts everything into, and each has a property that answers for one item, from wherever the player is standing right now:

- ``Item/isReachable`` — could they put a hand on it? Carried, lying in the room, or on or inside something open here — **to any depth**, so a bead in a pouch in a basket counts. This is the set the default actions gate on, so a rule that guards with it refuses exactly where `take` would. In the dark it is only what the player is carrying.
- ``Item/isVisible`` — could they see it? Everything reachable, plus what's behind the glass of a closed ``transparent`` container, plus whatever an actor in the room is holding.

```swift
wardedDoor.before(.close) {
    try require(spellbook.isReachable, else: "Not with the book on the far side.")
}

fuse("lampDies", after: 9) {
    let watched = lamp.isVisible      // asked before it goes out
    lamp.isLit = false
    if watched { say("The lamp gutters, and goes out.") }
}
```

Reach for these rather than rebuilding the answer from ``Item/isHeld``, ``Item/isIn(_:)`` and ``Item/holds(_:)``: `holds(_:)` tests one level only, and a ``surface`` is not a ``container`` and so is never ``Item/isOpen`` — which is how a hand-rolled version ends up refusing over a book sitting on a table in the same room.

### …and whether somebody else can

``Item/isReachable(from:)`` asks it of an ``Actor`` instead — the same walk, from their room and their hands:

```swift
let loot = treasures.filter { $0.isReachable || $0.isReachable(from: thief) }
```

Two things differ from the player's own reach. **Darkness does not gate it**: an unlit room stops the player's eyes, not somebody else's arm. And **what the player is holding is not in it**, exactly as another actor's hands are not in ``Item/isReachable`` — lifting from somebody's hands is stealing, which is a plugin's job. That is why a thief wants both sets, as above: one for the room, one for the pockets. An actor who is in no room at all reaches only what they carry.

### When the room is bigger than one place

Containment is room-granular. A thing lying in one square of a floor the player walks around *inside* — a sliding-block puzzle, a mirror box, a gallery with two ends — is "in the room" from every square, and so reachable from every square. ``Item/reach(otherwise:_:)`` is where a game says otherwise, once:

```swift
card.reach(otherwise: "The card is squares away from you, across the sand.") {
    grid.playerSquare == grid.cardSquare
}
```

The alternative is a guard per verb — `before(.take)`, `before(.putIn)`, `before(.open)` — and each one is a place the next author forgets. The rule is asked wherever a verb has to *touch* the thing, core and stub alike, and `otherwise:` is the line it refuses with (omit it for the stock ``GameText/cantReach``).

Four things the engine settles:

- **It narrows reach, not sight.** The item is still listed, still named, still examined — which is what makes `take card` answer "it's across the sand" rather than "you can't see any such thing".
- **What the asker is holding always passes.** A rule keyed to a square can't stop the player opening a box they are carrying.
- **It runs before any rule does.** An item that answers its own verb — `slot.before(.putIn)` — replies and the default action never runs, so a gate any later would miss exactly the cases that need it. It therefore refuses *ahead* of a verb's own complaints: `take` says "it's across the sand" where it would otherwise have said "You can't take that."
- **It gates ``Item/isReachable``**, so a `presence { }` line that wants to say "at your feet" versus "across the floor" can read the engine's answer instead of keeping a second copy of the index. That answer costs a scope walk, so a rule in a hot loop is better off reading the game's own position directly.

Actors take one too, with ``Actor/reach(otherwise:_:)``. Locations don't: the rule belongs to the thing being reached for, not to the room around it. And the rule is not told *who* is asking — ``Item/isReachable(from:)`` is gated by it as well, because a game that tracks one position inside a room tracks the player's.

Positions themselves are still yours to keep. The engine knows the answer to "can he touch it"; it does not know where in the room either of them is standing, so a room-listing paragraph that changes with the player's square is still a `presence { }` rule you write.

Possession is a different question again, and ``Actor/possesses(_:)`` answers it: is this thing anywhere under them — in their hands, or in a bag on their belt, to any depth? It is true in the dark, in another room, and offstage, because owning a thing has nothing to do with seeing it. ``Actor/holds(_:)`` is its one-level form, and the coin in the purse in the satchel is where the two part company.

## Locks and keys

A lock is declared not as a trait but as a relationship in the `map` block: ``Item/lockedBy(_:)`` names the key that locks and unlocks an item. The entry alone makes the item lockable — there's no separate `lockable` trait — and it **starts locked** unless the item also declares ``startsUnlocked``.

```swift
let chest = Item {
    name("iron chest")
    container
    openable
}

let brassKey = Item {
    name("brass key")
    adjectives("brass")
}

var map: WorldMap {
    chest.lockedBy(brassKey)      // chest starts locked; the brass key works it
    // …placements…
}
```

The player then types `unlock chest with brass key` before `open chest`, and `lock chest with brass key` to secure it again. Because the key is an ordinary property reference, renaming it is a compile error, not a broken game. Two guard-rails are enforced at startup as fatal ``BootstrapError``s: naming a key that isn't a stored property, and giving one item two `lockedBy` entries.

Read and set the lock from a rule with ``Item/isLocked`` (a no-op on a non-lockable item):

```swift
panel.after(.push) {
    vault.isLocked = false
    say("Something clicks, and the vault unlocks.")
}
```

## Doors between rooms

A door is just an ``openable`` item shared between two rooms and named as the gate on the exit. Use the directional `via:` form (or the general ``Location/exit(_:to:via:)``) on **both** sides, passing the same item — the exit is passable only while that door is open.

```swift
let trapDoor = Item {
    name("trap door")
    openable
    scenery
}

var map: WorldMap {
    livingRoom.down(cellar, via: trapDoor)
    cellar.up(livingRoom, via: trapDoor)
}
```

Because a door is an ordinary item, everything above composes: give the door a ``Item/lockedBy(_:)`` entry and the player must unlock it before it will open; declare it ``hidden`` (below) and the exit stays secret until the door is revealed.

A door is also a way through **by name**, not only by direction. `enter trap door`, `go through trap door`, `walk through trap door` and `climb through trap door` all take the exit the door gates, from either side — the engine finds the door on the current room's exits and makes the same move `go` would, so a shut door refuses in the same words, a locked one reads as shut, and an unrevealed one is not there at all. Nothing to declare: it follows from naming the door on the exit.

That is one verb with two jobs, which is the classic parser's own shape: the same word boards a vehicle (see <doc:ActorsAndVehicles>). The door wins where an item is somehow both — a door is referenced by an exit rather than placed in a room, so boarding one by name was never possible anyway — and a `before(.board)` rule on the item pre-empts either.

One difference from `go`, since `.board` takes a noun and `go` doesn't: a ``Item/reach(otherwise:_:)`` rule on the door refuses `enter door` at stage 0, ahead of everything, where `go west` through the same door never consults it.

When a passage is gated by something that *isn't* an item — a drawbridge lowered by a lever elsewhere — reach for ``Location/exit(_:to:when:otherwise:)`` instead. Its condition is evaluated at the moment the player tries to move, and the `otherwise` message is the refusal shown while it's false. The condition is ordinary Swift, so it reads whatever state you track — here a ``Global``:

```swift
@Global var drawbridgeLowered = false

var map: WorldMap {
    gatehouse.north(courtyard, when: { drawbridgeLowered }, otherwise: "The drawbridge is up.")
}
```

A conditional exit decides *whether* the player moves. When what you need to decide is *where* they arrive — one passage that leads to different rooms on different turns — use ``Location/exit(_:toward:)``, whose destination is the closure rather than the gate:

```swift
@Global var lastViewingRoom = ViewingSide.west

var map: WorldMap {
    depository.north { lastViewingRoom == .west ? smallRoom : vault }
}
```

Travel takes the same path as any other passable exit, so the destination's ``Location/onEnter(perform:)`` rules run and a boarded vehicle rides along. That is the difference between this and assigning ``Player/location`` from a rule, where neither happens — ``enter(_:)`` is the rule-side move that behaves like the exit. In exchange, a closure is opaque to the bootstrap: the destination isn't validated at launch, and a room reachable *only* this way isn't in the reachable-room set, so `FOLLOW` won't name somebody standing there.

## Hidden items

An item declared ``hidden`` exists and is placed like any other, but it's kept out of visibility and room descriptions until it's revealed — a panel behind a painting, a trap door under a rug. Call ``Item/reveal()`` when the player uncovers it; from then on it behaves normally. ``Item/isRevealed`` reports the current state (and is always `true` for an item that was never `hidden`).

```swift
let rug = Item {
    name("oriental rug")
    surface
    scenery
}

let trapDoor = Item {
    name("trap door")
    openable
    scenery
    hidden            // not mentioned until the rug is moved
}

var rules: Rules {
    rug.after(.push, .take) {
        trapDoor.reveal()
        say("With the rug aside, a trap door is revealed in the floor.")
    }
}
```

## Worked example

The **Lighthouse** example (`Sources/Lighthouse/`) puts all of this in one small game: a `shelf` you take a key off, a `chest` you open for the lamp and oil, and a `storeroomDoor` locked by that key. `LighthouseTranscriptTests` drives each one.

## See also

- <doc:WritingRules>
- <doc:AnatomyOfAGame>
- <doc:DarknessTimeAndDeath>
- ``ItemTrait``
- ``Item/location``
- ``Item/lockedBy(_:)``
- ``Location/exit(_:to:via:)``
