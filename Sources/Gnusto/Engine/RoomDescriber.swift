enum DescribeMode {
    /// Entering the room: the session's ``DescriptionMode`` decides.
    case entry
    /// An explicit LOOK: always verbose.
    case look
}

/// How much of a room the player wants on the way in — the classic
/// VERBOSE / BRIEF / SUPERBRIEF preference.
///
/// A preference about *this run of the program*, not about the world. It lives
/// on the `GameWorld` actor beside `firedTimers` and never reaches
/// `WorldState`, and that placement is the whole of its lifetime rule: a save
/// file is written out of a `WorldState` and read back into one, UNDO and
/// RESTART assign a `WorldState` over the live one, and the play-test
/// `restore(_:)` puts one back — so every one of them leaves the mode where
/// the player set it without a line of code saying so. A newly launched
/// session gets a fresh `GameWorld` and therefore ``brief``.
enum DescriptionMode: Sendable {
    /// The long description on every entry.
    case verbose
    /// The long description on the first visit only — the default.
    case brief
    /// The long description on no entry at all.
    case superbrief

    /// Whether *entering* a room prints its long description.
    ///
    /// Only the entry path asks. An explicit LOOK and a room declared
    /// `alwaysDescribed` are both long whatever the preference says, and
    /// `RoomDescriber` tests those beside this rather than folding them in
    /// here — as it tests darkness, which returns before any of the three.
    ///
    /// - Parameter revisit: whether the player has stood in this room before.
    /// - Returns: whether to print the long description.
    func describesEntry(revisit: Bool) -> Bool {
        switch self {
        case .verbose: true
        case .brief: !revisit
        case .superbrief: false
        }
    }
}

/// Composes room descriptions per classic IF conventions.
enum RoomDescriber {
    /// - Parameters:
    ///   - mode: entering the room, or an explicit LOOK.
    ///   - withRoomName: whether to open with the room's name. See
    ///     ``describeSurroundings(withRoomName:)``, which is where an author
    ///     reaches this.
    ///   - frame: the live turn.
    static func describeCurrentLocation(
        mode: DescribeMode,
        withRoomName: Bool = true,
        frame: TurnFrame
    ) {
        let definition = frame.definition

        // One snapshot of everything this function reads; the visited mark
        // (lit visits only) is the one write and happens in the same lock.
        let (locationID, isDark, wasVisited, vehicle, index, touched, state) = frame.with {
            scratch -> (
                EntityID, Bool, Bool, EntityID?, ContainmentIndex, Set<EntityID>, WorldState
            ) in
            let id = scratch.state.playerLocation
            let dark = Visibility.isDark(at: id, definition: definition, state: scratch.state)
            let visited = scratch.state.visited.contains(id)
            scratch.describedAtOccupancyCount = scratch.roomsOccupied.count
            if !dark {
                scratch.state.visited.insert(id)
            }
            return (
                id, dark, visited,
                scratch.state.playerVehicle,
                scratch.state.containment(),
                scratch.state.touched,
                scratch.state
            )
        }

        // Outside the scratch lock above, deliberately: every stock line is a
        // `Line`, so any of them may be `.live` and read the world to word
        // itself (is the companion still here?), which re-enters the frame via
        // `Ctx.current` and would deadlock if called while holding the lock.
        // `pitchBlack` is the one most likely to; the rule is for all of them.
        // Same reason `describedText` waits until line 55.
        //
        // Once per turn, because a game may point another emitter at this same
        // sentence — Zork's dark-room line *is* the grue's threat — and the two
        // are not ordered: the describer usually speaks first, but a timer that
        // warns and then `arrive(at:)`s a dark room reverses it.
        guard !isDark else {
            frame.sayOnceThisTurn(frame.definition.text.pitchBlack())
            return
        }

        let location = definition.locations[locationID]
        // Under the default BRIEF a revisit is short — the player has read the
        // room already — and VERBOSE and SUPERBRIEF move that line to every
        // entry or to none. Two things overrule the preference: an explicit
        // LOOK, which is the player asking to be told again, and a room whose
        // description is the state they are changing, where withholding it
        // withholds the only readout there is.
        let verbose =
            mode == .look
            || location?.isAlwaysDescribed == true
            || frame.descriptionMode.describesEntry(revisit: wasVisited)

        if withRoomName {
            let roomName = location?.name ?? locationID.raw
            if let vehicle {
                frame.say(
                    frame.definition.text.locationInVehicle(
                        roomName, frame.definiteNoun(of: vehicle)))
            } else {
                frame.say(roomName)
            }
        }
        if verbose {
            // Reads outside the lock above: `describedText` may call a
            // `describe { … }` rule closure, which typically re-enters the
            // frame via `Ctx.current` (proxies, `@Global`s) and would
            // deadlock if called while still holding the scratch lock.
            let text = frame.describedText(of: locationID)
            if !text.isEmpty {
                frame.say(text)
            }
        }

        // Item paragraphs: firstSight text until touched (even for scenery),
        // then a standard mention for non-scenery items. Actors are held
        // back for their own paragraphs below — people close the scene. The
        // boarded vehicle loses its *own* sentence and nothing else: its
        // presence is the title suffix, and "There is a red boat here."
        // under "…, in the red boat" is noise. What it holds is listed from
        // the seat exactly as it is from outside (#525).
        let present = (index.inRoom[locationID] ?? [])
            .filter { Visibility.isPerceivable($0, definition: definition, state: state) }
        let roomItems = present.filter { definition.items[$0]?.isActor != true }

        // The one line any listed thing earns, wherever it is standing: its
        // presence paragraph until the player touches it, else the stock
        // sentence, else nothing. `scenery` is what withholds the *stock*
        // sentence and only that — a fixed fitting is no more a room's news
        // inside a container than on a floor, but a fitting the author gave a
        // line of its own still gets it. `stock` is lazy, so the templates and
        // their string building are skipped whenever a presence line wins.
        //
        // It is *this* sentence `scenery` withholds, not every mention. OPEN and
        // SEARCH ask what is inside a thing rather than composing prose about
        // it, and name its fittings — see `DefaultActions.perceivableContents`.
        //
        // `alwaysListed` is the opt-out of the touch gate, for a mobile thing
        // whose paragraph is its state — see the trait. An actor needs no such
        // flag: neither gate applies to one, here or in the actor loop below,
        // because an actor is always listed where they are. The actor loop
        // reads the room's own contents, so a person one level down — inside a
        // container, on a surface — arrives here instead. No author API places
        // an actor there today (`Actor.move(to:)` takes a location), so this
        // arm is a guard on the rule rather than a path with a test behind
        // it.
        func sayListing(of id: EntityID, stock: () -> String) {
            let item = definition.items[id]
            let isActor = item?.isActor == true
            let stillNews = isActor || !touched.contains(id) || item?.isAlwaysListed == true
            if stillNews, let presence = frame.presenceText(of: id) {
                frame.say(presence)
            } else if isActor || item?.isScenery != true {
                frame.say(stock())
            }
        }

        // What a thing standing in the room holds — and one level only. The
        // walk covers the room's own things and their contents, never what
        // *those* contents hold, so a listing line declared two levels down
        // has nowhere to print. Deliberate — a recursive listing reads as a
        // manifest — and `Bootstrap` warns for a line declared below the
        // boundary, so the silence is reported rather than discovered.
        func listContents(
            _ ids: [EntityID]?,
            of holder: EntityID,
            as line: GameText.Line<GameText.Holding>
        ) {
            for id in ids ?? []
            where Visibility.isPerceivable(id, definition: definition, state: state) {
                sayListing(of: id) {
                    line(frame.indefiniteNoun(of: id), frame.definiteNoun(of: holder))
                }
            }
        }

        for itemID in roomItems {
            guard let item = definition.items[itemID] else { continue }
            if itemID != vehicle {
                sayListing(of: itemID) {
                    definition.text.itemHere(frame.indefiniteNoun(of: itemID))
                }
            }

            // "On the X is a Y." for a surface standing in the room.
            if item.isSurface {
                listContents(index.onSurface[itemID], of: itemID, as: definition.text.itemOnSurface)
            }

            // "In the X is a Y." for a container whose contents are visible —
            // an open one, or a closed transparent one. A closed opaque
            // container stays silent, so its contents never leak into the room
            // description — a boarded vehicle included, which is also what
            // keeps the listing and the parser's scope agreeing about a shut
            // hull.
            if Visibility.contentsVisible(itemID, definition: definition, state: state) {
                listContents(
                    index.inContainer[itemID], of: itemID, as: definition.text.itemInContainer)
            }
        }

        // Actor paragraphs. An actor's presence line — `firstSight`, or the
        // live `presence { … }` rule that supersedes it — is printed every
        // time, not gated on `touched` the way an item's is (people aren't
        // props; handling them doesn't wear off their entrance). What an
        // actor carries is not listed.
        // An `enterable` actor can be boarded too, and loses its paragraph
        // while ridden for the same reason an inanimate hull does.
        for actorID in present
        where actorID != vehicle && definition.items[actorID]?.isActor == true {
            if let presence = frame.presenceText(of: actorID) {
                frame.say(presence)
            } else {
                frame.say(frame.definition.text.actorHere(frame.indefiniteNoun(of: actorID)))
            }
        }
    }
}
