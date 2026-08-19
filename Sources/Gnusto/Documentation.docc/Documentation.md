# ``Gnusto``

An engine for writing interactive fiction in Swift.

@Metadata {
    @DisplayName("Gnusto")
    @TitleHeading("Framework")
}

## Overview

A game is one type conforming to ``Game``, and the engine reads four things off it: the ``Location``, ``Item``, ``Actor`` and ``Global`` values you declared as stored properties, which it finds by reflection and names after each property; a `map` block of exits and starting places; a `rules` block of behavior; and an optional `verbs` block that teaches the parser new words. <doc:GettingStarted> builds one from an empty package. <doc:AnatomyOfAGame> is the model underneath.

The same value is both the declaration and the live reference: `let cloak = Item { … }` declares the cloak, and `cloak.isWorn` reads its state inside a rule. That is the idea most of the rest follows from.

Each line the player types is parsed into a ``Command`` and run through a fixed pipeline — world, location and item `before` rules, the built-in action, then `after` rules, each-turn rules, and the timer tick. Any rule can ``refuse(_:)``, ``reply(_:)`` in the action's place, ``end(won:)`` the game, or ``die(_:)``. Every change commits atomically at the end of the turn, which is also what `save` writes and `undo` rewinds. See <doc:TheTurnPipeline>.

### Which article to read

<doc:GettingStarted> first, then the **Lighthouse** demo (`Sources/Lighthouse/`, `swift run Lighthouse`) — one small winnable game that exercises containers and a locked door, a fuse and a daemon, a roaming actor, `@Global` state, a content bundle, and two plugins. Most of the guides below link back to it.

After that the articles are a reference, not a sequence: read <doc:WritingRules> and <doc:WorldMapAndExits> when you are building, <doc:TestingYourGame> and <doc:PlayTesting> when you want to know whether it works, and <doc:BootstrapDiagnostics> when the game refuses to start.

### The optional libraries

The package ships seven libraries beside the engine, each a separate product you import only if you want it: `GnustoClock` (a time of day rather than a turn counter), `GnustoConversation` (asking, telling, showing, and what somebody has already been asked), `GnustoScoring`, `GnustoSpellcasting` (four casting paradigms), `GnustoMeleeCombat`, `GnustoDangerousDark`, and `GnustoActors`. An eighth, `GnustoTestSupport`, belongs in a test target.

Each has its own documentation in this archive. They are not linked from here: a merged archive resolves symbol links only within a module, so a link across one would render as plain text rather than fail loudly. See <doc:Plugins> and <doc:ContentBundles> for how they splice in.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:AnatomyOfAGame>
- <doc:TheTurnPipeline>

### Declaring the World

- ``Game``
- ``Location``
- ``Item``
- ``Player``
- ``World``

### The World Map

- <doc:WorldMapAndExits>
- ``WorldMap``
- ``MapEntry``
- ``Direction``
- ``Location/exit(_:to:)``
- ``Location/exit(_:to:via:)``
- ``Location/exit(_:to:when:otherwise:)``
- ``Location/exit(_:toward:)``

### Describing Entities

- ``LocationTrait``
- ``ItemTrait``
- ``adjectives(_:)``
- ``synonyms(_:)``
- ``firstSight(_:)``
- ``dark``
- ``alwaysDescribed``
- ``lightSource``
- ``startsLit``
- ``wearable``
- ``scenery``
- ``surface``
- ``container``
- ``openable``
- ``startsOpen``
- ``transparent``
- ``capacity(_:)``
- ``hidden``

### Containers, Doors, and Locks

- <doc:ContainersDoorsAndLocks>
- ``Item/lockedBy(_:)``
- ``startsUnlocked``
- ``Item/isOpen``
- ``Item/isLocked``
- ``Item/isReachable``
- ``Item/isReachable(from:)``
- ``Item/isVisible``
- ``Item/reach(otherwise:_:)``
- ``Item/reveal()``
- ``Item/isRevealed``

### Writing Rules

- <doc:WritingRules>
- ``Rule``
- ``Rules``
- ``Intent``
- ``Command``
- ``say(_:)``
- ``sayOnceThisTurn(_:)``
- ``refuse(_:)``
- ``reply(_:)``
- ``require(_:else:)``
- ``handled()``
- ``proceed()``
- ``end(won:)``
- ``die(_:)``
- ``Item/describe(_:)``
- ``Location/describe(_:)``
- ``Item/presence(_:)``

### Player and World State

- ``Player/score``
- ``Player/moves``
- ``Player/inventory``
- ``Player/item``
- ``Player/isCarrying(_:)``
- ``Player/isWearing(_:)``
- ``Location/isLit``
- ``Location/isVisited``

### Actors & Vehicles

- <doc:ActorsAndVehicles>
- ``Actor``
- ``Actor/describe(_:)``
- ``Actor/presence(_:)``
- ``Actor/holds(_:)``
- ``Actor/possesses(_:)``
- ``takesOrders``
- ``Command/actor``
- ``enterable``
- ``Player/vehicle``
- ``describeSurroundings(withRoomName:)``
- ``arrive(at:withRoomName:)``
- ``enter(_:)``

### Time, Light, and Death

- <doc:DarknessTimeAndDeath>
- ``TimedEvent``
- ``fuse(_:after:autostart:perform:)``
- ``daemon(_:autostart:perform:)``
- ``startFuse(_:after:)``
- ``stopFuse(_:)``
- ``fuseRemaining(_:)``
- ``startDaemon(_:)``
- ``stopDaemon(_:)``
- ``isDaemonActive(_:)``

### Custom State and Traits

- <doc:CustomStateAndTraits>
- ``Global``
- ``GlobalValue``
- ``StateValue``
- ``TraitKey``

### Verbs and Intents

- <doc:AddingCustomVerbs>
- <doc:StubVerbs>
- ``verb(_:_:)``
- ``SyntaxRule``
- ``SyntaxElement``
- ``IntentAction``
- ``Topic``

### Text and Randomness

- <doc:TextAndRandomness>
- ``GameText``
- ``GameText/Line``
- ``GameText/StubReplies``
- ``random(_:)``
- ``chance(_:)``

### Running a Game

- ``GameWorld``
- ``TurnResult``
- ``StatusLine``
- ``GameStatus``
- ``REPL``
- ``GameMain``
- ``IOHandler``
- ``ConsoleIOHandler``
- ``TerminalIOHandler``
- ``ScriptedIOHandler``

### Writing a Front End

- <doc:CustomFrontEnds>
- ``Input``
- ``CompletionCandidates``

### Sharing Your Game

- <doc:SharingYourGame>

### Testing and Play-testing

- <doc:TestingYourGame>
- <doc:PlayTesting>

### Diagnostics

- <doc:BootstrapDiagnostics>
- ``BootstrapError``

### Composing Large Games

- <doc:SplittingAGameAcrossFiles>
- <doc:ContentBundles>
- <doc:Plugins>
- ``GameContent``
- ``GameContents``
- ``GamePlugin``
- ``ScoreDeclaring``

### Identity and Storage

- ``EntityID``
- ``Placement``

### Result Builders

- ``GnustoBuilder``
- ``LocationBuilder``
- ``ItemBuilder``
- ``MapBuilder``
- ``RuleBuilder``
- ``VerbBuilder``
- ``ContentBuilder``
- ``TimerBuilder``
