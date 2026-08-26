import Foundation

/// The curiosity engine: what the game has shown a tester that the tester has
/// not followed up, kept as a live queue rather than a report.
///
/// **The firewall is the whole design.** Everything in this file is derived
/// from two sources and no others: the text the game printed *into this
/// session*, and the session's own ``TurnAudit`` history. Nothing here reads
/// `GameDefinition` — not the room roster, not the timer roster, not the verb
/// tables, not the vocabulary, not `maxScore`. That is a rule about test
/// validity before it is a rule about fidelity:
///
/// - A tester handed the room roster cannot *discover* an unreachable room. It
///   can only report a room it was told about and did not reach, which is a
///   coverage statistic, not a finding.
/// - A tester handed the vocabulary cannot discover that a noun the prose
///   printed has nothing behind it, because it would never type a word the
///   game does not know.
///
/// Hand somebody the map and they navigate; they do not explore. So the map
/// stays on the other side of ``PlaytestRole``, and this ledger is built by
/// reading over the tester's shoulder.
///
/// **A queue, not a scoreboard.** Every item carries a ``CoverageItem/how``
/// that is a command to paste — *"in Front Hall: x grout"*, *"go south, then:
/// x nest"* — because a statistic (*"Back Yard unvisited"*) is something an
/// agent reads once and rationalises, where a next move costing one turn is
/// something it takes. Items are ranked by cheapness for the same reason: the
/// item at the top of the queue is always in the room the tester is standing
/// in, if there is one there.
///
/// **Live and growing.** A noun printed by an examine enters that room's queue
/// immediately, at a priority that decays with how deep the tester had to dig
/// to print it. `x nest` prints "something pale is tucked in among the leaves",
/// and `pale` and `leaves` are in the queue before the tool result reaches the
/// agent. The frontier closes when looking stops producing unseen words.

// MARK: - Who is allowed to see the oracle

/// What a session may be told about the game beyond what the game has printed
/// to it.
///
/// **Enforced here, server-side, rather than by handing a tester a smaller tool
/// set.** Client-side gating is not available in the context this runs in:
/// `.claude/workflows/playtest.js` dispatches subagents with `agent(prompt,
/// opts)` where `opts` is only `{label, phase, schema, effort, model}`, and MCP
/// tools arrive as a deferred set that any subagent can pull in for itself with
/// `ToolSearch`. A firewall that depended on nobody looking would not be one.
///
/// Doing it by role is also strictly better than the tool-set plan it replaces:
/// it holds for *any* MCP client, a third-party author's included, and it is
/// testable in this process instead of depending on how a harness happened to
/// be configured.
///
/// The default is ``unrestricted``, which is the human case — a game author
/// driving their own game by hand wants the survey, and is not being measured.
enum PlaytestRole: String, Sendable, CaseIterable {
    /// Walks the map, burns the visible queue and the interaction matrix.
    /// Blind to the oracle.
    case explorer
    /// Watches the clock: the event × room × hour cross-product, discovered by
    /// standing somewhere and waiting rather than by reading a timer roster.
    case timekeeper
    /// Plays for the win. Blind to the oracle, because a walkthrough read off
    /// the map is not a winnability test.
    case solver
    /// Talks to the cast. Blind for the same reason as the explorer.
    case interrogator
    /// Types the wrong thing on purpose and judges the reply.
    case wrongFooter = "wrong-footer"
    /// A human, or a game author driving their own game. Sees everything.
    case unrestricted

    /// Whether this role may ask for facts the game has not printed: the room
    /// roster, the timer roster, the verb tables, the vocabulary, `maxScore`.
    var seesOracleData: Bool {
        self == .unrestricted
    }

    /// The refusal a restricted role gets, written to be read by the agent that
    /// hit it — it says what was refused, why the refusal is deliberate, and
    /// what to do instead, because "permission denied" costs a round trip to
    /// guess at.
    ///
    /// - Parameter tool: the tool that was refused.
    /// - Returns: the sentence to throw.
    func refusal(of tool: String) -> String {
        """
        `\(tool)` is oracle data, and this session opened as `\(rawValue)`, which plays \
        blind. That is deliberate, not a permission problem: a tester holding the room \
        roster navigates instead of exploring, and a tester holding the vocabulary can \
        never discover that a noun the prose printed has nothing behind it. Go by what \
        the game has told you — `coverage` lists what it has shown you and you have not \
        followed up, every item with a command to paste. If you are a person driving this \
        game by hand rather than a tester being measured, open a session with \
        role="unrestricted".
        """
    }
}

// MARK: - Which way this tester is told to go at a fork

/// What a session does the first time the game offers it something it cannot
/// take back.
///
/// **The problem this solves is that testers converge.** Left to itself, every
/// explorer sent into the same game opens the same egg, burns the same leaflet
/// and kills the same troll, because those are the interesting things to do and
/// they are all equally interesting to everybody. The branch nobody took is then
/// untested by the whole round, however many testers it ran — and the untaken
/// branch is where a two-channel defect hides, because a description that
/// outlives the state change is only wrong for the tester who *didn't* make it.
///
/// So the fork is assigned rather than left to chance. Two policies over one
/// object are the coverage; the round report names any fork no tester took at
/// all, which is a gap the old harness could not see because it had no idea a
/// fork existed.
///
/// **A policy is an instruction, not a mechanism.** Nothing here stops a session
/// typing whatever it likes — the engine is not going to refuse `open egg`
/// because a JSON field said `abstain`. What the policy changes is the queue: an
/// `abstain` tester is not *asked*, and is not left holding an obligation it is
/// under orders not to discharge. Enforcement would be the wrong tool anyway,
/// since a tester that stumbles into a fork while doing something else has
/// discovered something, and the ledger would rather record that than forbid it.
enum DivergencePolicy: String, Sendable, CaseIterable {
    /// Take the irreversible action the first time it is available. The
    /// historical behaviour, and the default, so a session that says nothing
    /// gets exactly the queue it always got.
    case commit
    /// Probe everything else about the object and leave it in the state it was
    /// found in. Fork cells are closed on sight rather than offered, so they
    /// never sit in the queue as work this tester is forbidden to do.
    case abstain
    /// Leave it, finish everything else, come back to it last. Fork cells sort
    /// below every other open item instead of competing on cheapness.
    case `defer`

    /// The sentence a session is opened with, so the tester knows what it has
    /// been told to do before it meets its first fork.
    var instruction: String {
        switch self {
        case .commit:
            """
            Divergence policy: commit. When you meet something you cannot take back — \
            opening, burning, eating or drinking a thing — do it the first time you can, \
            then keep testing past it. Another tester has been told to leave it alone, so \
            the far side of that change is yours to describe.
            """
        case .abstain:
            """
            Divergence policy: abstain. Probe everything else about a thing you cannot \
            take back — opening, burning, eating or drinking it — and leave it as you \
            found it. Those moves are already off your queue; you are not missing them. \
            Another tester is committing them, so the unchanged state is yours to \
            describe, and a description that only reads correctly *after* the change is \
            a defect only you can find.
            """
        case .defer:
            """
            Divergence policy: defer. Leave anything you cannot take back — opening, \
            burning, eating or drinking a thing — until you have worked out everything \
            else you can reach. Those moves sort to the bottom of your queue and come \
            back to you at the end, so the state you spend most of the session in is the \
            one the game started in.
            """
        }
    }
}

// MARK: - One thing you were shown and did not follow up

/// A single open item on a session's queue.
struct CoverageItem: Sendable {
    /// What sort of loose end this is.
    ///
    /// Every kind is derivable from printed text plus the parse record; there
    /// is deliberately no kind that could only be built from source.
    ///
    /// `CaseIterable` so that `queueItemSchema` derives its advertised `enum`
    /// from these cases instead of restating them. That schema is embedded in
    /// three declared output schemas — `open`, `coverage` and `finish` — so a
    /// kind added here and not there would break validation on three tools at
    /// once, for a client that checks.
    enum Kind: String, Sendable, CaseIterable {
        /// A word the prose printed that no command has ever named.
        case noun
        /// A direction the prose named, from a room, that was never taken.
        case exit
        /// One cell of the interaction matrix: an object, and a verb from the
        /// standard repertoire that fits what was said about it.
        case object
        /// Re-examine something after an action moved, opened, lit or
        /// relocated it. **This is the egg**: `take egg` then `x egg` still
        /// claiming the egg is in the nest is a two-channel defect
        /// (`firstSight`/`presence` outliving the take), and nothing finds it
        /// unless something insists on the second look.
        case restate
        /// The tester's own suspicion, filed as a `[suspicious]` note and owed
        /// a second look at a different frame.
        case hunch
        /// The same do-nothing probe printed differently in one room at two
        /// moments, with nothing the tester typed in between to explain it —
        /// which is what a fuse or a daemon looks like from the player's chair.
        case timer
        /// Something named in one room's prose and later in another's, without
        /// the tester carrying it. A wandering actor, or an object a rule moved.
        case displacement

        /// Whether typing the item's own command is enough to close it.
        ///
        /// False for ``timer`` and ``displacement``, which is the one guard
        /// kept from the enforcement design this stage otherwise dropped — and
        /// it is kept because it is about *quality*, not compulsion. The class
        /// of defect these two name (an event that fires in the wrong room, at
        /// the wrong hour, or reports a stale fact about where somebody is)
        /// cannot be settled by looking once. It wants a `look` at a second
        /// frame and a verdict quoting a printed line, so it is closed by that
        /// pair and not by a keystroke.
        var closedByLooking: Bool {
            self != .timer && self != .displacement
        }

        /// Which band of the queue this kind sits in. Lower is nearer the top.
        ///
        /// Two bands, and the split is *perishability* rather than importance.
        /// A `restate` asks about a change that just happened, a `hunch` about a
        /// suspicion formed a moment ago, and a `timer` or `displacement` about
        /// a frame the tester is standing in right now — all four go stale as
        /// the session walks away from them, and none can be recovered later
        /// without redoing the turns that set them up. A noun the prose printed
        /// keeps.
        ///
        /// This is the fix for the failure the stage would otherwise have
        /// shipped with: on Dungeon, `take egg` put `restate:egg` on the queue
        /// twelfth, behind *branch*, *reach* and *chirping*, which is to say
        /// behind the ambient scenery of the room it was standing in. The one
        /// item this whole stage exists to raise was below the fold.
        var tier: Int {
            switch self {
            case .restate, .hunch, .timer, .displacement: 0
            case .exit, .object, .noun: 1
            }
        }
    }

    /// A stable identity, `<kind>:<subject>[@<room>]`. Also what the agent
    /// quotes back when it talks about the item.
    let id: String

    /// What sort of loose end it is.
    let kind: Kind

    /// The command to paste, as typed from inside the item's own room.
    let command: String

    /// ``command``, with the step that gets there in front of it when the item
    /// is somewhere else.
    ///
    /// A `var`, filled in by ``CoverageLedger/queue(limit:)`` at the moment it
    /// is asked for rather than at the moment the item was raised — the prefix
    /// depends on where the tester is standing *now*, and an item raised in the
    /// Lane and read back from the Yard would otherwise say "x lane" and mean it
    /// about a room the tester has since walked out of.
    var how: String

    /// Where and when the game showed you this, in the session's own terms.
    let why: String

    /// The room this belongs to, as the status line named it.
    let room: String

    /// The line number of the turn that raised it.
    let line: Int

    /// How many examines deep the tester was when this surfaced. One for
    /// something a room description printed, two for something an examine of
    /// *that* printed, and so on. The queue's priority is `1/depth`.
    let depth: Int

    /// True when an examine printed the noun that raised this. The
    /// noun-follow-rate signal is a count over these.
    let bornOfExamine: Bool

    /// True for a matrix cell asking for something that cannot be taken back.
    ///
    /// Each repertoire row declares its own answer — see
    /// ``CoverageLedger/Commitment`` — and it is what a ``DivergencePolicy``
    /// acts on. **A precaution, not a verdict**: the flag is raised before the
    /// command is typed, so read a count of these as an upper bound.
    ///
    /// **A one-way passage is not marked**, though the plan for this names one
    /// alongside the objects. It cannot be: the ledger reads printed text, and
    /// nothing a room description says tells you an exit has no way back — that
    /// is knowable only after walking it, which is exactly too late for a policy
    /// to have an opinion. Marking exits would mean reading the map, which is
    /// the one thing this file may not do.
    var fork = false

    /// True when an ``DivergencePolicy/abstain`` session closed this fork on
    /// sight rather than being asked to take it.
    ///
    /// Kept distinct from an ordinary discharge because the round report has to
    /// tell the two apart: a fork this tester *took* and a fork it was under
    /// orders to leave are both closed, and only the first one has been tested.
    var abstained = false

    /// Whether it has been followed up.
    var discharged = false

    /// For the two kinds that want a verdict: whether the second look has
    /// happened and only the note is outstanding.
    var lookedAgain = false

    /// Higher is cheaper, and the queue sorts on it after room proximity.
    var priority: Double {
        1 / Double(max(depth, 1))
    }

    /// One line of the queue as the tester reads it.
    var rendered: String {
        "\(how)  —  \(why)"
    }
}

// MARK: - The signals

/// What a session's own record says about how it is playing, measured off the
/// transcript and the parse record rather than asked of the agent.
///
/// The two census agents in the old harness exist because an agent asked how
/// much it had covered answered 2 when the truth was 261, and 112 when the
/// truth was 155. Nothing here is self-reported.
///
/// **Measured and shown, never policed.** One tier of intervention — an inline
/// `harness:` line on a `move` result when a threshold trips — and nothing
/// else. No hard stop, no re-dispatch. The real consumer of these numbers is
/// the round report and the critic, which is where a genuinely shallow run
/// should be caught and named.
struct PlaytestSignals: Sendable {
    /// Lines fed that were not comments.
    let commands: Int

    /// Distinct rooms the status line has named.
    let roomsVisited: Int

    /// Commands per distinct room. High means pacing back and forth; very low
    /// means a tourist walking through.
    let roomDwell: Double

    /// Distinct normalised commands over total commands. Low means repetition.
    let novelCommandRatio: Double

    /// Of the nouns an *examine* printed, the fraction later named in a
    /// command. Curiosity as a number: it asks whether reading a description
    /// leads anywhere.
    let nounFollowRate: Double

    /// How many nouns an examine has printed. The denominator above; below a
    /// handful the rate means nothing.
    let nounsPrintedByExamines: Int

    /// Mean distinct verbs tried per object the tester has bound. The direct
    /// measure of *"tries possibilities"*.
    let interactionBreadth: Double

    /// How many distinct objects the tester's commands have bound.
    let objectsBound: Int

    /// Items closed over items raised.
    let dischargeRate: Double

    /// Items still open.
    let openItems: Int

    /// The one nudge, or `nil` when nothing has tripped.
    ///
    /// Thresholds have floors under their denominators, because a rate over
    /// four samples is noise and an agent told off for noise learns to ignore
    /// the channel.
    var note: String? {
        if nounsPrintedByExamines >= 20 && nounFollowRate < 0.15 {
            return """
                harness: noun-follow rate \(Self.rounded(nounFollowRate)) over \
                \(nounsPrintedByExamines) nouns your examines printed. Descriptions are \
                naming things you are not looking at.
                """
        }
        if objectsBound >= 10 && interactionBreadth < 2 {
            return """
                harness: interaction breadth \(Self.rounded(interactionBreadth)) verbs per \
                object over \(objectsBound) objects. Most things here have been examined \
                and nothing else.
                """
        }
        if commands >= 30 && novelCommandRatio < 0.5 {
            return """
                harness: novel-command ratio \(Self.rounded(novelCommandRatio)) over \
                \(commands) commands. More than half of what you have typed, you had \
                typed before.
                """
        }
        return nil
    }

    /// The signals as one line, for a `finish` record and the round report.
    var line: String {
        """
        rooms=\(roomsVisited) dwell=\(Self.rounded(roomDwell)) \
        novel=\(Self.rounded(novelCommandRatio)) \
        noun-follow=\(Self.rounded(nounFollowRate))/\(nounsPrintedByExamines) \
        breadth=\(Self.rounded(interactionBreadth))/\(objectsBound) \
        discharged=\(Self.rounded(dischargeRate)) open=\(openItems)
        """
    }

    /// Two decimal places, without pulling in a formatter.
    private static func rounded(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

// MARK: - The ledger

/// The per-session ledger. Fed one observation per recorded line, asked for a
/// ranked queue whenever the tester wants to know what is still open.
///
/// A value type held by ``PlaytestSession``, and rebuilt from scratch when a
/// session is evicted and replays itself — which is sound for the same reason
/// eviction is sound at all: the replay is exact, so re-feeding the same lines
/// rebuilds the same ledger.
struct CoverageLedger: Sendable {
    // MARK: - What is remembered

    /// Every item ever raised, in the order it was raised.
    private(set) var items: [CoverageItem] = []

    /// `id` → position in ``items``.
    private var positions: [String: Int] = [:]

    /// One object the tester's commands have bound, keyed by the entity the
    /// parser resolved.
    ///
    /// Keyed by ``EntityID`` and *labelled* by the word the tester typed. The
    /// id is a fact the session earned — the parser bound it because the tester
    /// named something the game could see — and it is what keeps "cloak" and
    /// "cape" from counting as two objects. The label is what goes on the wire,
    /// because a queue item has to be a command somebody can paste.
    private struct ObjectRecord {
        var label: String
        var room: String
        /// Every distinct word the game has printed *about* this thing: the
        /// sentence it was named in, and every examine of it. The interaction
        /// matrix is filtered against this vocabulary and nothing else.
        ///
        /// A set of words rather than the accumulated prose, because the prose
        /// was only ever read one way — split into words and made into a set —
        /// and it was read again in full every time the object was *named*, not
        /// only when it was examined. That made the cost of naming a thing grow
        /// with how often it had already been described: measured on Dungeon,
        /// 400 repetitions of `x <one object>` took the per-turn cost from
        /// 0.87 ms to 5.5 ms, linearly, while `look` and `wait` over the same
        /// span stayed flat. Folding each new output in as it arrives is
        /// O(the new output) instead of O(everything ever printed).
        var vocabulary: Set<String>
        /// The verbs already tried against it, by intent — so `x`, `examine`
        /// and `look at` count once, and `search` does not re-offer `look in`.
        var tried: Set<Intent> = []
        /// True once a `take` moved it into the tester's hands: `drop` and
        /// `throw` only make sense after that.
        var held = false
        /// Where its name was last printed, for the displacement check.
        var lastPrintedRoom: String
        /// True once a command named it since the last time it was printed.
        ///
        /// The displacement check's one guard, and it earns its keep on the
        /// first game it met: Cloak of Darkness starts the player *wearing* the
        /// cloak, so the cloak's name is printed in the Foyer and then in the
        /// Cloakroom without anything having moved it but the player's own legs.
        /// A thing the tester has been handling is a thing the tester moved; a
        /// thing that turns up somewhere else while nobody has touched it is the
        /// wandering actor this item is for.
        var namedSinceSeen = false
        var depth: Int
    }

    private var objects: [EntityID: ObjectRecord] = [:]

    /// Whether the tester is holding anything the game has called a source of
    /// fire — the one piece of *inventory* state a fork test needs.
    ///
    /// **Cached, and recomputed only where it can change.** It was a scan of
    /// every bound object, run inside ``refreshMatrix(for:line:)``, which is the
    /// hot path that method's own comment is written to defend: up to three
    /// calls a turn, each walking the object table and prefix-matching eight
    /// stems against every held thing's whole vocabulary. Measured against the
    /// 0.87 ms/turn Dungeon baseline, that came to a tenth of the turn at a
    /// modest inventory and a third at a full one — paid on every call, and on
    /// the many calls where no `burn` cell is reached at all.
    ///
    /// It is also the fix for a shallower bug. `refreshMatrix` runs for the
    /// turn's own objects, so a flag read there is only re-read when the tester
    /// next *names* a thing: pick up a torch and the twenty things already
    /// examined would keep their old answer. The flag is a property of the
    /// inventory, so it is maintained where the inventory moves, and the turn it
    /// turns true is the turn every open `burn` cell is promoted.
    private var carryingFlame = false

    /// The last output of each do-nothing probe, by `<room>|look` /
    /// `<room>|wait`, and the move counter it printed at.
    private struct ProbeRecord {
        var output: String
        var moves: Int
    }

    private var probes: [String: ProbeRecord] = [:]

    /// A filed suspicion: the words of the note, and the frame it was filed in.
    private struct Hunch {
        var words: Set<String>
        var room: String
        var moves: Int
    }

    private var hunches: [String: Hunch] = [:]

    /// Every word any command has ever named, so a noun printed later is not
    /// queued as unfollowed. Also the interval filter for the timer check.
    private var namedWords: Set<String> = []

    /// Words typed since each probe last printed, for the timer check's "did
    /// the tester cause this?" filter.
    private var wordsSinceProbe: [String: Set<String>] = [:]

    /// Distinct normalised commands, for the novelty ratio.
    private var distinctCommands: Set<String> = []

    /// Rooms the status line has named, in first-seen order.
    private(set) var roomsVisited: [String] = []

    /// Every token the game's vocabulary did not know, and how often it was
    /// typed.
    ///
    /// This is the *parser's* record, taken from ``TurnAudit/unknownWords``,
    /// and not a count of `I don't know the word` lines in the transcript. The
    /// two rounds that grepped the transcript for that sentence were reading
    /// the engine's prose to find out what the engine already knew, which is
    /// why they disagreed with the testers' own tally by two orders of
    /// magnitude and had to be reported side by side. A game that re-voices
    /// ``GameText/unknownWord`` breaks the grep and does not break this.
    private(set) var unknownWords: [String: Int] = [:]

    /// One step of the map the tester has actually walked: room → direction →
    /// where it came out. Purely session-derived, and the reason a queue item
    /// in the next room over can still be a command to paste.
    private var walked: [String: [Direction: String]] = [:]

    /// The room the last observation ended in.
    private(set) var currentRoom = ""

    /// Non-comment lines fed.
    private(set) var commands = 0

    /// `[suspicious]` notes filed.
    private(set) var hunchCount = 0

    /// Comments written, suspicious or not.
    private(set) var notes = 0

    /// The move counter as of the last observation.
    private var moves = 0

    /// Which way this session was told to go at a fork. See
    /// ``DivergencePolicy``.
    let divergence: DivergencePolicy

    /// Nothing is remembered yet.
    ///
    /// - Parameter divergence: what to do at an irreversible action. Defaults to
    ///   ``DivergencePolicy/commit``, which is the queue this ledger has always
    ///   produced.
    init(divergence: DivergencePolicy = .commit) {
        self.divergence = divergence
    }

    // MARK: - Reading a turn

    /// Records the opening, which is where the first nouns and the first exits
    /// come from.
    ///
    /// **Only the room part of it.** `begin()` prints three things at once —
    /// the game's intro, its banner, and the first room — and just the last of
    /// those is about where the player is standing. Harvesting all three files
    /// the blurb's scenery under the starting room, and the cost is not a
    /// rounding error: Zork 1's intro names the dam, the temple, the mine, the
    /// river, the maze, the barrow and the thief, so a blind explorer's opening
    /// queue came back eleven parts scene-setting to one part room. The
    /// explorer charter is measured on burning that queue down, and every one
    /// of those items sends it to examine something hundreds of commands away
    /// — which then answers *you can't see any such thing*, which that charter
    /// is told to report as a printed noun the parser denies. So the round pays
    /// for the turn twice, once in the tester and once in the verifier refuting
    /// what it filed.
    ///
    /// The behaviour was known before it was understood: ``AviaryGame``'s intro
    /// is deliberately noun-free so that the opening-queue assertion is "about
    /// the room rather than about the intro", which is this defect written down
    /// as a fixture workaround.
    ///
    /// - Parameters:
    ///   - output: the opening text, without the status footer.
    ///   - room: the room the status line named.
    mutating func observeOpening(output: String, room: String) {
        visit(room)
        harvest(
            output: Self.roomBlock(in: output, room: room),
            room: room, depth: 1, bornOfExamine: false, line: 0)
    }

    /// The tail of the opening that describes the starting room.
    ///
    /// The room heading is the seam: the engine prints it on a line of its own
    /// immediately before the description, so everything from there down is the
    /// room and everything above it is the intro and the banner. The *last*
    /// such line rather than the first, because a blurb is free to mention the
    /// room by name and the heading is the one nearest the description.
    ///
    /// A game whose opening never prints the heading — one starting in the dark
    /// — falls back to the whole text. Over-harvesting is the survivable error
    /// here, since a wrong queue item costs one turn; harvesting nothing leaves
    /// the first room with no frontier at all, and the explorer with nothing to
    /// work down.
    private static func roomBlock(in output: String, room: String) -> String {
        let heading = room.trimmingCharacters(in: .whitespaces)
        guard !heading.isEmpty else { return output }
        let lines = output.components(separatedBy: "\n")
        guard
            let start = lines.lastIndex(where: {
                $0.trimmingCharacters(in: .whitespaces) == heading
            })
        else {
            return output
        }
        return lines[start...].joined(separator: "\n")
    }

    /// Records one command and what it printed.
    ///
    /// Order matters and is deliberate: the command's own effects are applied
    /// first — a word it named is no longer unfollowed, a direction it took is
    /// no longer untaken — and only then is the output read for new loose ends.
    /// Reading the output first would let `x grout` re-queue the very noun it
    /// just discharged.
    ///
    /// - Parameters:
    ///   - command: the line as the tester typed it.
    ///   - audit: what the parser made of it.
    ///   - output: what the turn printed, without the status footer.
    ///   - room: the room the status line named *after* the turn.
    ///   - moves: the move counter after the turn.
    ///   - line: the line's 1-based index in `commands.txt`.
    ///   - turnCost: whether the move counter advanced across it.
    mutating func observe(
        command: String,
        audit: TurnAudit,
        output: String,
        room: String,
        moves: Int,
        line: Int,
        turnCost: Bool
    ) {
        let departed = currentRoom
        commands += 1
        self.moves = moves
        distinctCommands.insert(Self.normalized(command))

        for word in audit.unknownWords {
            unknownWords[word, default: 0] += 1
        }

        let typed = Self.contentWords(in: command)
        namedWords.formUnion(typed)
        for key in wordsSinceProbe.keys {
            wordsSinceProbe[key]?.formUnion(typed)
        }
        for word in typed {
            close("\(CoverageItem.Kind.noun.rawValue):\(word)@", prefixed: true)
        }
        dischargeHunches(with: typed, room: room, line: line)

        var depth = 1
        if audit.understood {
            depth = apply(audit: audit, command: command, departed: departed, line: line, turnCost: turnCost)
        }

        visit(room)
        if let direction = audit.direction, audit.intent == .go, !departed.isEmpty {
            close("\(CoverageItem.Kind.exit.rawValue):\(direction.rawValue)@\(departed)")
            if room != departed {
                walked[departed, default: [:]][direction] = room
            }
        }

        // A parse failure prints the *engine* talking, not the game: "I don't know
        // the word 'grout'" would otherwise queue `x word` as a thing to examine.
        // Nothing else is lost by skipping it — a line the parser refused ran no
        // rules, no fuse and no daemon, so the only text in it is the refusal.
        if audit.understood || audit.answeredPrompt {
            harvest(
                output: output, room: room, depth: depth,
                bornOfExamine: audit.intent == .examine, line: line)
        }
        watchForTimers(audit: audit, output: output, room: room, moves: moves, line: line)
        watchForDisplacement(output: output, room: room, line: line)

        if audit.intent == .examine, let subject = audit.directObject {
            objects[subject]?.vocabulary.formUnion(Self.words(in: output))
            // The one other way the answer moves: examining a thing already in
            // hand is how the game gets to say *lit* about it.
            if objects[subject]?.held == true { refreshCarriedFlame() }
            refreshMatrix(for: subject, line: line)
        }
    }

    /// Records a `//` comment.
    ///
    /// A comment costs no turn, so it changes nothing about the world — but it
    /// is where a tester's own suspicion enters the ledger. A note whose text
    /// carries the `[suspicious]` marker raises a ``CoverageItem/Kind/hunch``,
    /// which is an obligation to look again from somewhere else: the loss this
    /// closes is the one named in the round reports as *"four refutations
    /// handed over a better claim than the one they killed, and nobody filed
    /// any of them."*
    ///
    /// A note also settles the two kinds that want a verdict: a `timer:` or
    /// `displacement:` item that has had its second look is closed by the next
    /// comment, because the comment is the verdict, in the evidence, quoting
    /// the line that prompted it.
    ///
    /// - Parameters:
    ///   - text: the comment line, marker and all.
    ///   - room: the room the tester is standing in.
    ///   - moves: the move counter.
    ///   - line: the line's index in `commands.txt`.
    mutating func observeComment(_ text: String, room: String, moves: Int, line: Int) {
        notes += 1
        for index in items.indices
        where !items[index].discharged && !items[index].kind.closedByLooking
            && items[index].lookedAgain
        {
            items[index].discharged = true
        }
        guard text.lowercased().contains("[suspicious]") else { return }
        hunchCount += 1
        let id = "\(CoverageItem.Kind.hunch.rawValue):\(hunchCount)"
        hunches[id] = Hunch(
            words: Set(Self.contentWords(in: text)), room: room, moves: moves)
        raise(
            CoverageItem(
                id: id,
                kind: .hunch,
                command: "probe it again from somewhere else",
                how: "probe it again from somewhere else",
                why: """
                    your own note at line \(line) in \(room): \
                    \(Self.quoted(text)) — a hunch wants a second frame
                    """,
                room: room,
                line: line,
                depth: 1,
                bornOfExamine: false))
    }

    // MARK: - Answering

    /// The open queue, cheapest first.
    ///
    /// "Cheapest" is room proximity before anything else, so the top of the
    /// queue is always a move that costs one turn from where the tester is
    /// standing. Within a room it is `1/depth` — a noun the room description
    /// printed outranks a noun that took three examines to surface — and ties
    /// break oldest-first so the frontier closes behind the tester rather than
    /// wandering.
    ///
    /// - Parameter limit: how many to return.
    /// - Returns: the ranked items.
    func queue(limit: Int) -> [CoverageItem] {
        let open = items.filter { !$0.discharged }
        let ranked = open.sorted { left, right in
            // A deferred fork sinks below everything, including items in other
            // rooms, because "come back to it last" means last in the session
            // and not last in the room. Checked ahead of proximity for that
            // reason, and only under `defer`: under the default policy this
            // whole comparison is skipped and the ranking is the one every
            // recorded measurement was taken against.
            if divergence == .defer {
                let held = (left.fork ? 1 : 0, right.fork ? 1 : 0)
                if held.0 != held.1 { return held.0 < held.1 }
            }
            let here = (left.room == currentRoom ? 0 : 1, right.room == currentRoom ? 0 : 1)
            if here.0 != here.1 { return here.0 < here.1 }
            if left.kind.tier != right.kind.tier { return left.kind.tier < right.kind.tier }
            if left.priority != right.priority { return left.priority > right.priority }
            return left.line < right.line
        }
        return ranked.prefix(limit).map { item in
            var rendered = item
            rendered.how = how(item.command, in: item.room)
            return rendered
        }
    }

    /// How many items are still open. The decreasing integer the queue is read
    /// by.
    var openCount: Int {
        items.reduce(0) { $0 + ($1.discharged ? 0 : 1) }
    }

    /// The one player-visible frontier hint, for a queue that has run dry.
    ///
    /// Built from printed text only — the rooms the tester has *stood in* that
    /// described a way out it never used. When even that is empty the honest
    /// answer is that nothing the tester has read names a way on, which is
    /// itself a discoverability finding rather than a coverage gap.
    ///
    /// - Returns: the sentence, or `nil` while the queue still has items.
    func frontierHint() -> String? {
        guard openCount == 0 else { return nil }
        let rooms = Set(
            items.filter { $0.kind == .exit }.map(\.room))
        guard rooms.isEmpty else {
            return """
                Nothing is open. \(rooms.count) room\(rooms.count == 1 ? "" : "s") you have \
                stood in described a way out, and you have used all of them.
                """
        }
        return """
            Nothing is open, and nothing you have read names a way on. If the game is \
            larger than what you found, that is a finding about discoverability — say so.
            """
    }

    /// The measured signals. See ``PlaytestSignals``.
    ///
    /// - Returns: the numbers, computed off this ledger.
    func signals() -> PlaytestSignals {
        let printedByExamines = items.filter { $0.kind == .noun && $0.bornOfExamine }
        let followed = printedByExamines.filter(\.discharged).count
        let bound = objects.values.filter { !$0.tried.isEmpty }
        let verbs = bound.reduce(0) { $0 + $1.tried.count }
        let discharged = items.filter(\.discharged).count
        return PlaytestSignals(
            commands: commands,
            roomsVisited: roomsVisited.count,
            roomDwell: Self.ratio(commands, over: roomsVisited.count),
            novelCommandRatio: Self.ratio(distinctCommands.count, over: commands),
            nounFollowRate: Self.ratio(followed, over: printedByExamines.count),
            nounsPrintedByExamines: printedByExamines.count,
            interactionBreadth: Self.ratio(verbs, over: bound.count),
            objectsBound: bound.count,
            dischargeRate: Self.ratio(discharged, over: items.count),
            openItems: openCount)
    }

    // MARK: - Applying a command

    /// Applies what one understood command did, and answers the depth the
    /// output should be harvested at.
    ///
    /// - Parameters:
    ///   - audit: the parse record.
    ///   - command: the raw line, for the object labels.
    ///   - departed: the room the tester was standing in.
    ///   - line: the line index.
    ///   - turnCost: whether world time passed.
    /// - Returns: the depth new nouns from this turn's output belong at.
    private mutating func apply(
        audit: TurnAudit, command: String, departed: String, line: Int, turnCost: Bool
    ) -> Int {
        let labels = Self.labels(in: command)
        var depth = 1
        if let subject = audit.directObject {
            bind(subject, label: labels.direct, room: departed)
            depth = (objects[subject]?.depth ?? 1) + (audit.intent == .examine ? 1 : 0)
        }
        if let other = audit.indirectObject {
            bind(other, label: labels.indirect, room: departed)
        }
        guard let intent = audit.intent else { return depth }

        for subject in [audit.directObject, audit.indirectObject].compactMap({ $0 }) {
            objects[subject]?.tried.insert(intent)
            objects[subject]?.namedSinceSeen = true
            if let label = objects[subject]?.label {
                close("\(CoverageItem.Kind.object.rawValue):\(label):\(intent.raw)")
                close("\(CoverageItem.Kind.restate.rawValue):\(label)", onlyWhen: intent == .examine)
            }
            if intent == .take && turnCost {
                objects[subject]?.held = true
                refreshCarriedFlame()
            }
            if Self.releasingIntents.contains(intent) && turnCost {
                objects[subject]?.held = false
                refreshCarriedFlame()
            }
            if intent != .examine, Self.changingIntents.contains(intent), turnCost {
                enqueueRestate(subject, room: departed, line: line, verb: intent.raw)
            }
            refreshMatrix(for: subject, line: line)
        }
        if intent == .look || intent == .wait {
            for index in items.indices
            where !items[index].discharged && !items[index].kind.closedByLooking
                && items[index].room == departed
            {
                items[index].lookedAgain = true
            }
        }
        return depth
    }

    /// Notes an object the parser bound, creating its record the first time.
    ///
    /// **No label, no record.** The entity id is `DungeonAboveGround.egg` — a
    /// bundle type and a property name, which is source, and which would reach
    /// the tester the moment it appeared in an item id or a `how`. So an object
    /// is only tracked once the tester has referred to it by a *word*, and a
    /// line that bound something without naming it — `take all`, `take it` — is
    /// simply not the line that introduces it. The next one that says the word
    /// is.
    private mutating func bind(_ id: EntityID, label: String?, room: String) {
        guard objects[id] == nil else {
            if let label, objects[id]?.label.isEmpty == true {
                objects[id]?.label = label
            }
            return
        }
        guard let word = label else { return }
        // A noun the prose printed and the tester has now bound inherits that
        // noun's depth, so an object three examines down the frontier keeps its
        // place in the ranking instead of jumping to the top of the queue.
        let inherited = items.first {
            $0.kind == .noun && $0.id.hasPrefix("\(CoverageItem.Kind.noun.rawValue):\(word)@")
        }
        objects[id] = ObjectRecord(
            label: word,
            room: room,
            vocabulary: Set(Self.words(in: word)),
            lastPrintedRoom: room,
            depth: inherited?.depth ?? 1)
    }

    /// Re-enqueues `x <object>` after something changed it.
    private mutating func enqueueRestate(
        _ id: EntityID, room: String, line: Int, verb: String
    ) {
        guard let record = objects[id] else { return }
        let itemID = "\(CoverageItem.Kind.restate.rawValue):\(record.label)"
        reopen(itemID)
        raise(
            CoverageItem(
                id: itemID,
                kind: .restate,
                command: "x \(record.label)",
                how: "x \(record.label)",
                why: """
                    `\(verb)` changed it at line \(line) and you have not looked since — \
                    does it still describe itself the way it did before?
                    """,
                room: room,
                line: line,
                depth: record.depth,
                bornOfExamine: false))
    }

    // MARK: - Reading the prose

    /// Reads one block of output for new loose ends.
    private mutating func harvest(
        output: String, room: String, depth: Int, bornOfExamine: Bool, line: Int
    ) {
        guard !output.isEmpty else { return }
        for word in Self.words(in: output) {
            guard let direction = Self.directions[word] else { continue }
            let itemID = "\(CoverageItem.Kind.exit.rawValue):\(direction.rawValue)@\(room)"
            guard walked[room]?[direction] == nil else { continue }
            raise(
                CoverageItem(
                    id: itemID,
                    kind: .exit,
                    command: direction.rawValue,
                    how: direction.rawValue,
                    why: "\(room) named \(direction.rawValue) at line \(line); you have not gone that way",
                    room: room,
                    line: line,
                    depth: 1,
                    bornOfExamine: false))
        }

        var raised = 0
        for word in Self.nounCandidates(in: output) {
            guard !namedWords.contains(word), raised < Self.nounsPerBlock else { continue }
            let itemID = "\(CoverageItem.Kind.noun.rawValue):\(word)@\(room)"
            guard positions[itemID] == nil else { continue }
            raised += 1
            raise(
                CoverageItem(
                    id: itemID,
                    kind: .noun,
                    command: "x \(word)",
                    how: "x \(word)",
                    why: "\"\(word)\" printed in \(room) at line \(line), never named",
                    room: room,
                    line: line,
                    depth: depth,
                    bornOfExamine: bornOfExamine))
        }
    }

    /// Looks for a do-nothing probe that printed differently than last time.
    ///
    /// Only `look` and `wait` are watched, because they are the two commands
    /// whose answer the tester did not change, and an added sentence is
    /// discarded when every content word in it is a word the tester typed since
    /// the last probe — that is the filter that keeps "the lamp is gone,
    /// because you took it" out of the queue.
    private mutating func watchForTimers(
        audit: TurnAudit, output: String, room: String, moves: Int, line: Int
    ) {
        guard audit.intent == .look || audit.intent == .wait else { return }
        guard let intent = audit.intent else { return }
        let key = "\(room)|\(intent.raw)"
        defer {
            probes[key] = ProbeRecord(output: output, moves: moves)
            wordsSinceProbe[key] = []
        }
        guard let previous = probes[key], previous.output != output, previous.moves != moves
        else { return }
        let caused = wordsSinceProbe[key] ?? []
        let before = Set(Self.sentences(in: previous.output))
        let after = Set(Self.sentences(in: output))
        // Both directions. A sentence that has appeared is a thing that started;
        // a sentence that has gone is a thing that stopped, and the second is
        // exactly as much a fuse or a daemon as the first — the bell that rang
        // once and then did not is only visible as a *removal*.
        let changed = (after.subtracting(before)).union(before.subtracting(after))
            .filter { sentence in
                let words = Set(Self.contentWords(in: sentence))
                return !words.isEmpty && !words.isSubset(of: caused)
            }
        guard let evidence = changed.sorted().first else { return }
        raise(
            CoverageItem(
                id: "\(CoverageItem.Kind.timer.rawValue):\(room)",
                kind: .timer,
                command: "look, wait a few turns, look again",
                how: "look, wait a few turns, look again",
                why: """
                    \(intent.raw) in \(room) printed something new at line \(line) that \
                    nothing you typed explains: \(Self.quoted(evidence)). Look again at a \
                    different moment and write a note quoting the line
                    """,
                room: room,
                line: line,
                depth: 1,
                bornOfExamine: false))
    }

    /// Looks for something named here that was last named somewhere else.
    private mutating func watchForDisplacement(output: String, room: String, line: Int) {
        guard !output.isEmpty else { return }
        let printed = Set(Self.contentWords(in: output))
        for record in objects.values {
            guard printed.contains(record.label), !record.held, !record.namedSinceSeen,
                !record.lastPrintedRoom.isEmpty, record.lastPrintedRoom != room
            else { continue }
            let elsewhere = record.lastPrintedRoom
            raise(
                CoverageItem(
                    id: "\(CoverageItem.Kind.displacement.rawValue):\(record.label)",
                    kind: .displacement,
                    command: "look and see whether \(record.label) is still there",
                    how: "look and see whether \(record.label) is still there",
                    why: """
                        \(record.label) was last printed in \(elsewhere) and is printed in \
                        \(room) at line \(line), and you are not carrying it. Look at both \
                        and write a note quoting what each says
                        """,
                    room: elsewhere,
                    line: line,
                    depth: 1,
                    bornOfExamine: false))
        }
        for (id, record) in objects where printed.contains(record.label) && !record.held {
            objects[id]?.lastPrintedRoom = room
            objects[id]?.namedSinceSeen = false
        }
    }

    /// Closes a hunch the tester has come back to from a different frame.
    ///
    /// "A different frame" is a different room, or three moves later in the
    /// same one — the point of a hunch is that a suspicion formed at one moment
    /// has to be checked at another, and typing the same thing again in the
    /// same breath is not that.
    private mutating func dischargeHunches(with typed: [String], room: String, line: Int) {
        let words = Set(typed)
        for (id, hunch) in hunches
        where !words.isDisjoint(with: hunch.words)
            && (hunch.room != room || moves >= hunch.moves + 3)
        {
            close(id)
            hunches.removeValue(forKey: id)
        }
    }

    // MARK: - The interaction matrix

    /// Raises the cells of the interaction matrix that fit what has been said
    /// about one object.
    ///
    /// The repertoire is the harness's own knowledge of English, identical for
    /// every game, so consulting it leaks nothing about *this* one; the filter
    /// is the text the game printed about the object and nothing else. That is
    /// what makes the ambient cases work — a river gets `drink` and `swim`
    /// because its description says water, and a tree gets `climb` because its
    /// description says tree — and those are exactly the interactions that
    /// reach the rooms no exit lists.
    private mutating func refreshMatrix(for id: EntityID, line: Int) {
        guard let record = objects[id] else { return }
        let vocabulary = record.vocabulary
        var offered: Set<Intent> = record.tried
        // The cheap test first. `applies` walks up to 255 trigger stems against
        // every word the object has ever been described with, and this runs for
        // every bound object on every turn — while `offered` is a set lookup
        // that already knows the answer for anything the tester has tried.
        // Filtering on `applies` first meant paying the scan and then throwing
        // the result away. Both are pure and `offered` grows only below, so the
        // order is free to choose.
        for probe in Self.repertoire {
            guard !offered.contains(probe.intent),
                probe.applies(to: vocabulary, held: record.held)
            else { continue }
            offered.insert(probe.intent)
            let phrase = probe.takesObject ? "\(probe.verb) \(record.label)" : probe.verb
            raise(
                CoverageItem(
                    id: "\(CoverageItem.Kind.object.rawValue):\(record.label):\(probe.intent.raw)",
                    kind: .object,
                    command: phrase,
                    how: phrase,
                    why: "never tried: `\(probe.verb)` on \(record.label)",
                    room: record.room,
                    line: line,
                    depth: record.depth,
                    bornOfExamine: false,
                    fork: probe.commits(
                        to: vocabulary, carryingFlame: carryingFlame)))
        }
    }

    /// Every fork this session met, and what became of it.
    ///
    /// The round report's input, and the reason the policy is worth recording at
    /// all: two sessions over one object with different policies are the
    /// coverage, and a fork that comes back `taken: false` from *every* session
    /// in a round is a branch the round never tested. The old harness could not
    /// name that gap because nothing in it knew a fork existed.
    ///
    /// - Returns: one entry per fork cell, in the order the game offered them.
    func forks() -> [(id: String, command: String, room: String, taken: Bool)] {
        items.filter(\.fork).map { item in
            (
                id: item.id,
                command: item.command,
                room: item.room,
                taken: item.discharged && !item.abstained
            )
        }
    }

    /// Whether any trigger is a prefix of any word the game used about the
    /// thing.
    ///
    /// Prefix-of-a-word rather than substring-of-the-text, which is a real
    /// distinction and was found by reading the queue: `sea` inside `search`,
    /// `car` inside `carrying`, `rot` inside `rotate`. Prefixes are what the
    /// stems in the tables below are for — `clos` has to reach *closed*,
    /// *closes* and *closing* — and a word boundary at the front is enough to
    /// stop the accidents.
    ///
    /// - Parameters:
    ///   - triggers: the trigger stems.
    ///   - vocabulary: every word the game has used about the thing.
    /// - Returns: whether the cell applies.
    private static func matches(_ triggers: [String], in vocabulary: Set<String>) -> Bool {
        triggers.contains { trigger in
            vocabulary.contains { $0.hasPrefix(trigger) }
        }
    }

    /// One cell of the standard repertoire.
    private struct Probe {
        let intent: Intent
        /// The words to type, `x` / `look in` / `listen to`.
        let verb: String
        /// False for `swim`, which the engine's grammar takes bare.
        let takesObject: Bool
        /// Only offered once the tester is carrying the thing.
        let needsHolding: Bool
        /// Words that have to appear in what the game said about the object, or
        /// `nil` for a cell every object gets.
        let triggers: [String]?
        /// When taking this cell is a move the session cannot take back.
        let commitment: Commitment

        /// Whether this cell fits what the game has said about a thing.
        ///
        /// - Parameters:
        ///   - vocabulary: every word the game has used about it.
        ///   - held: whether the tester is carrying it.
        /// - Returns: whether to offer the cell.
        func applies(to vocabulary: Set<String>, held: Bool) -> Bool {
            guard !needsHolding || held else { return false }
            guard let triggers else { return true }
            return CoverageLedger.matches(triggers, in: vocabulary)
        }

        /// Whether this cell, on this thing, right now, is a fork.
        ///
        /// - Parameters:
        ///   - vocabulary: every word the game has used about the thing.
        ///   - carryingFlame: whether the tester holds a source of fire.
        /// - Returns: whether to flag the cell.
        func commits(to vocabulary: Set<String>, carryingFlame: Bool) -> Bool {
            switch commitment {
            case .never: return false
            case .always: return true
            case .whenCalled(let words): return !vocabulary.isDisjoint(with: words)
            case .whileCarryingFlame: return carryingFlame
            }
        }

        init(
            _ intent: Intent, _ verb: String, takesObject: Bool = true,
            needsHolding: Bool = false, _ triggers: [String]? = nil,
            commits commitment: Commitment = .never
        ) {
            self.intent = intent
            self.verb = verb
            self.takesObject = takesObject
            self.needsHolding = needsHolding
            self.triggers = triggers
            self.commitment = commitment
        }
    }

    /// When a repertoire cell asks for something a later turn cannot put back.
    ///
    /// **Declared on the row, not in a second list of intents.** The fork rule
    /// used to be a `Set<Intent>` ninety lines from the repertoire, and it was
    /// wrong in two directions at once: a fifth member added to the set became
    /// unconditional in silence, and the four already in it were unconditional
    /// when three of them are not. The 2026-08-25 Dungeon round reported *"37
    /// irreversible forks declined"*; its critic closed five in eighteen turns —
    /// `burn nest`, `burn tree`, `burn trees`, `open trees`, `open forest` — and
    /// not one was irreversible.
    ///
    /// **It is a precaution, not a verdict.** The cell is flagged *before* the
    /// command is typed, and it can only ever be flagged then: under
    /// ``DivergencePolicy/abstain`` an item is recorded and closed at raise time
    /// with nothing typed and nothing printed, so there is no output to
    /// reclassify from afterwards. `turn=cost` is no help either — the engine
    /// advances the clock on refused turns by design. So the test uses what the
    /// ledger already holds, which is what the tester is carrying and what the
    /// game has said, and never anything about the game's definition.
    private enum Commitment {
        /// Reversible enough, which is almost everything. `take` is here:
        /// dropping it restores the world, near enough, and a policy that
        /// withheld `take` would withhold most of the game.
        case never
        /// Always committing. `eat` and `drink`, whose trigger lists are
        /// specific enough — *bread*, *cake*, *wine* — that the verb carries
        /// the class on its own. **Holding is the wrong test for these**: the
        /// one fork the 2026-08-25 round named as genuinely committing was
        /// `object:cake:eat`, and Dungeon's `blueCake.before(.eat)` kills the
        /// player whether or not the cake is in their hands.
        case always
        /// Committing once the game has used one of these words about the
        /// thing, matched **whole**. `open`, against ``shut``.
        ///
        /// Whole-word where a trigger is a prefix, and the two are not the same
        /// test: `clos` has to reach *closing* to offer the cell at all, and
        /// *close-grown* trees are not a container. That is why the Forest was
        /// queued for `open` — correctly — and called a divergence, wrongly.
        case whenCalled(Set<String>)
        /// Committing only while the tester holds something the game has called
        /// a source of fire. `burn`, which is a stub verb: with empty hands it
        /// is a printed refusal that changes nothing, and the nest was only
        /// offered the cell because its description says *branch*.
        case whileCarryingFlame
    }

    /// Words that mean a thing is shut, for ``Commitment/whenCalled(_:)``.
    ///
    /// A `Set` rather than an array, which is the type saying which kind of list
    /// it is: every prefix-matched trigger table below is an array read through
    /// ``matches(_:in:)``, and passing this one to that would put *close-grown*
    /// back. It overlaps ``openable`` on purpose — same idea, two match
    /// strengths, and only one of them is a claim about state.
    private static let shut: Set<String> = ["closed", "shut", "locked", "sealed", "latched"]

    /// What a source of fire is called, prefix-matched like the trigger tables
    /// so that *lit*, *lighted* and *torches* all count. Read only by
    /// ``refreshCarriedFlame()``.
    private static let flame = [
        "torch", "match", "candle", "flame", "fire", "lit", "tinder", "lantern",
    ]

    /// The repertoire, in the order the cells are offered.
    ///
    /// Two of the plan's twenty-one verbs are missing on purpose, because the
    /// engine's grammar folds them into their neighbours and a queue that
    /// offered both would be asking for the same turn twice: `move X` is
    /// ``Intent/push`` (`CoreVerbs.swift`), and `search X` is
    /// ``Intent/lookIn``. `throw` is here only in its two-object form, which
    /// the queue cannot fill in for the tester, so it is left to the tester —
    /// `drop` covers the reachable half.
    private static let repertoire: [Probe] = [
        Probe(.examine, "x"),
        Probe(.take, "take"),
        Probe(.touch, "touch"),
        Probe(.lookIn, "look in", concealing),
        Probe(.open, "open", openable, commits: .whenCalled(shut)),
        Probe(.close, "close", openable),
        Probe(.read, "read", written),
        Probe(.push, "push", movable),
        Probe(.pull, "pull", movable),
        Probe(.turn, "turn", turnable),
        Probe(.climb, "climb", climbable),
        Probe(.board, "enter", enterable),
        Probe(.burn, "burn", burnable, commits: .whileCarryingFlame),
        Probe(.drink, "drink", liquid, commits: .always),
        Probe(.swim, "swim", takesObject: false, swimmable),
        Probe(.eat, "eat", edible, commits: .always),
        Probe(.smell, "smell", fragrant),
        Probe(.listen, "listen to", sonorous),
        Probe(.drop, "drop", needsHolding: true, nil),
    ]

    private static let openable = [
        "clos", "open", "lid", "door", "box", "chest", "case", "cabinet", "drawer", "jar",
        "bottle", "trunk", "coffer", "hatch", "gate", "window", "shut", "latch",
    ]
    private static let concealing = [
        "box", "chest", "case", "cabinet", "drawer", "jar", "bottle", "trunk", "coffer",
        "basket", "sack", "bag", "pocket", "nest", "pile", "heap", "rubble", "sand",
        "leaves", "grass", "bush", "shelf", "inside", "contain", "empty", "full", "hollow",
    ]
    private static let written = [
        "writ", "letter", "note", "book", "page", "sign", "inscri", "label", "engrav",
        "print", "word", "script", "rune", "carv", "scrawl", "read", "map", "paper",
    ]
    private static let movable = [
        "rug", "carpet", "stone", "rock", "boulder", "lever", "block", "slab", "lid",
        "chair", "table", "cart", "loose", "heavy", "panel", "curtain", "grating",
    ]
    private static let turnable = [
        "knob", "dial", "crank", "wheel", "valve", "screw", "handle", "switch",
        "lever", "page", "bolt",
    ]
    private static let climbable = [
        "tree", "ladder", "stair", "rope", "cliff", "hill", "pole", "vine",
        "trunk", "chimney", "slope", "ramp", "branch",
    ]
    private static let enterable = [
        "door", "doorway", "gate", "arch", "passage", "opening", "boat", "raft",
        "chair", "hole", "tunnel", "crack", "cave", "shaft", "hatch", "stairwell",
    ]
    private static let burnable = [
        "wood", "paper", "leaf", "leaves", "cloth", "candle", "torch", "lamp", "match",
        "straw", "book", "rope", "branch", "coal", "kindling", "parchment",
    ]
    private static let liquid = [
        "water", "river", "stream", "brook", "pool", "spring", "fountain", "wine",
        "liquid", "lake", "puddle", "ale", "beer", "milk", "juice",
    ]

    /// Stricter than ``liquid``: a bottle of wine is a drink and not a swim.
    private static let swimmable = [
        "river", "stream", "lake", "pool", "water", "current", "channel", "torrent",
    ]
    private static let edible = [
        "food", "bread", "fruit", "egg", "meat", "cake", "apple", "garlic", "lunch",
        "sandwich", "cheese", "berr", "honey", "soup", "biscuit",
    ]
    private static let fragrant = [
        "smell", "scent", "odor", "odour", "fragran", "stink", "aroma", "smoke",
        "flower", "rotten", "musty", "perfume", "reek",
    ]
    private static let sonorous = [
        "sound", "humming", "noise", "music", "ticking", "whisper", "roar", "rustl",
        "drip", "echo", "creak", "voice", "silence", "quiet", "chime",
    ]

    /// The intents that change a thing, and so owe it a second look.
    ///
    /// `climb` and `enter` are deliberately absent: they move the *player*
    /// relative to the object, not the object.
    private static let changingIntents: Set<Intent> = [
        .take, .drop, .open, .close, .putOn, .putIn, .push, .pull, .turn, .turnOn,
        .turnOff, .burn, .throwAt, .give, .wear, .doff, .lock, .unlock, .eat, .drink,
        .fill, .pour, .empty, .cut, .smash, .attack, .tie, .untie, .shake, .dig,
    ]

    /// The intents that put a held thing down again.
    private static let releasingIntents: Set<Intent> = [
        .drop, .putOn, .putIn, .give, .throwAt, .pour, .empty,
    ]

    // MARK: - Bookkeeping

    /// Recomputes ``carryingFlame`` and, when it has just turned true,
    /// promotes every `burn` cell already on the queue.
    ///
    /// The sweep is the half that matters. A cell is raised the moment the game
    /// describes the thing, which is usually many turns before there is any way
    /// to burn it, so without this an `abstain` tester who picks up a torch is
    /// still offered `burn rope` on twenty things it examined first — and takes
    /// it, because it was told to.
    ///
    /// **Promotion only, in both directions.** It never turns a fork back into
    /// ordinary work: a tester who puts the torch down keeps the precaution,
    /// which is the safe way to be wrong and the one that keeps `abstained`
    /// meaning what ``forks()`` reports it to mean.
    private mutating func refreshCarriedFlame() {
        let carrying = objects.values.contains {
            $0.held && Self.matches(Self.flame, in: $0.vocabulary)
        }
        guard carrying, !carryingFlame else {
            carryingFlame = carrying || carryingFlame
            return
        }
        carryingFlame = true
        let suffix = ":\(Intent.burn.raw)"
        for index in items.indices
        where !items[index].fork && !items[index].discharged
            && items[index].kind == .object && items[index].id.hasSuffix(suffix)
        {
            markFork(at: index)
        }
    }

    /// Flags an item a fork, and applies ``DivergencePolicy/abstain`` to it.
    ///
    /// One function because the decision is one decision, reached from two
    /// directions: a cell raised as a fork, and a cell promoted into one when
    /// the tester picked up a match. Under `abstain` both are recorded and
    /// closed in the same breath — *recorded* rather than dropped, because the
    /// round report has to be able to say that this tester met the egg and was
    /// under orders to leave it. A fork nobody was offered and a fork nobody
    /// took are different gaps, and only the ledger knows which happened.
    private mutating func markFork(at position: Int) {
        items[position].fork = true
        guard divergence == .abstain else { return }
        items[position].abstained = true
        items[position].discharged = true
    }

    /// Adds an item, or leaves an existing one alone.
    ///
    /// A fork raised under ``DivergencePolicy/abstain`` is recorded and closed
    /// in the same breath. It is *recorded* rather than dropped because the
    /// round report has to be able to say that this tester met the egg and was
    /// under orders to leave it — a fork nobody was even offered is a different
    /// gap from a fork nobody took, and only the ledger knows which happened.
    private mutating func raise(_ item: CoverageItem) {
        if let position = positions[item.id] {
            // `refreshMatrix` re-offers every untried cell on every turn, and a
            // cell's fork answer can move under it — the `open` half is fixed
            // once the game has said *closed*, but the `burn` half turns on
            // what the tester is carrying. Left a pure no-op this branch would
            // freeze the first answer, so it reconciles the one field that is
            // allowed to change and freezes the rest: `line`, `room`, `why` and
            // `depth` all still describe where the cell was *found*, which is
            // what they are for.
            if item.fork, !items[position].fork, !items[position].discharged {
                markFork(at: position)
            }
            return
        }
        guard items.count < Self.itemCap else { return }
        positions[item.id] = items.count
        items.append(item)
        if item.fork { markFork(at: items.count - 1) }
    }

    /// Marks an item followed up, if this was the verb that does it.
    ///
    /// - Parameters:
    ///   - id: the item's id.
    ///   - condition: whether the turn qualifies.
    private mutating func close(_ id: String, onlyWhen condition: Bool) {
        guard condition else { return }
        close(id)
    }

    /// Marks an item followed up.
    ///
    /// - Parameters:
    ///   - id: the item's id, or its prefix when `prefixed`.
    ///   - prefixed: match every item whose id starts with `id` — a noun is
    ///     queued per room, and naming the word answers all of them.
    private mutating func close(_ id: String, prefixed: Bool = false) {
        guard prefixed else {
            guard let position = positions[id] else { return }
            items[position].discharged = true
            // A fork closed by a command is a fork the tester *took*, whatever
            // its policy said. `abstained` means only "closed on sight, never
            // asked for", and a session that reached for the thing anyway has
            // tested that branch — so the flag has to come back off, or
            // ``forks()`` reports a branch as untested that somebody tested.
            // A policy is an instruction, not a lock; the record is what has to
            // be true.
            items[position].abstained = false
            return
        }
        for index in items.indices where items[index].id.hasPrefix(id) {
            items[index].discharged = true
        }
    }

    /// Puts a closed item back on the queue, for a `restate:` raised again by a
    /// second change.
    private mutating func reopen(_ id: String) {
        guard let position = positions[id] else { return }
        items[position].discharged = false
        items[position].lookedAgain = false
    }

    /// Notes the room the tester is standing in.
    private mutating func visit(_ room: String) {
        currentRoom = room
        guard !room.isEmpty, !roomsVisited.contains(room) else { return }
        roomsVisited.append(room)
    }

    /// A command with the room prefix an item somewhere else needs.
    ///
    /// One step of routing, and only one, because the session knows the map
    /// only where it has walked it: if the tester has gone from here to there
    /// in one move, the item's `how` is a two-command paste. Otherwise it names
    /// the room, which is a fact the status line printed.
    private func how(_ command: String, in room: String) -> String {
        if room.isEmpty || room == currentRoom { return command }
        if let direction = walked[currentRoom]?.first(where: { $0.value == room })?.key {
            return "\(direction.rawValue), then: \(command)"
        }
        return "in \(room): \(command)"
    }

    // MARK: - Reading text

    /// How many unnamed nouns one block of output may add. A wall of text is
    /// not thirty obligations.
    private static let nounsPerBlock = 12

    /// The most items one session's ledger holds.
    private static let itemCap = 4_000

    /// Every word of a block, lowercased and split on anything that is not a
    /// letter or a digit.
    ///
    /// The ledger's own splitter, not `Vocabulary.words(in:)`, and that is the
    /// point: this file must not touch the game's vocabulary even to tokenize,
    /// because a tester that can ask what the game knows can never discover
    /// that a printed noun has nothing behind it.
    ///
    /// - Parameter text: any text.
    /// - Returns: its words, in order, duplicates included.
    static func words(in text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    /// The words of a block that could plausibly be *referred to*: three
    /// letters or more, not filler, not a direction, not a number.
    ///
    /// Generous on purpose, because this is the discharge side. A word the
    /// tester typed counts as named however loosely it was meant, and a word a
    /// hunch mentions counts as part of the hunch — being over-inclusive there
    /// closes items that might not have been meant, which costs nothing, where
    /// being under-inclusive would leave an item open forever and read as an
    /// obligation the tester had already met.
    ///
    /// - Parameter text: any text.
    /// - Returns: the words, in order, duplicates removed.
    static func contentWords(in text: String) -> [String] {
        var seen: Set<String> = []
        return words(in: text).filter { word in
            guard word.count >= 3, !stopWords.contains(word), directions[word] == nil,
                word.contains(where: \.isLetter), seen.insert(word).inserted
            else { return false }
            return true
        }
    }

    /// The words of a block that are plausibly *things*, for the queue side.
    ///
    /// The discharge side can afford to be generous; the queue cannot. Every
    /// word that reaches it is an obligation, and a queue full of adjectives
    /// and verbs — `x walled`, `x crumbling`, `x stands` — spends a tester's
    /// turns on grammar and teaches it that the queue is noise. That is
    /// mitigation two for the risk this stage names out loud: coverage
    /// degenerating into a checklist burned down mechanically.
    ///
    /// So this reads noun *phrases* rather than words. A determiner opens one;
    /// a preposition, a conjunction, a verb, a punctuation mark or the next
    /// determiner closes it; the word at the end of the run is its head, and
    /// only the head is queued. `of`, `and` and `or` close a run and open
    /// another, which is what makes "a cup of twigs and moss" three things
    /// rather than one.
    ///
    /// It misses a noun no determiner introduces — *"Something pale is tucked
    /// into it"* yields nothing — and that is the right trade. A missed noun
    /// costs coverage the round can still find by other means; a false one
    /// costs a turn and a little of the tester's trust, every time.
    ///
    /// - Parameter text: any text.
    /// - Returns: the head nouns, in order, duplicates removed.
    static func nounCandidates(in text: String) -> [String] {
        let tokens = phraseTokens(in: text)
        var heads: [String] = []
        var seen: Set<String> = []
        var run: [String] = []

        func emit() {
            defer { run = [] }
            guard let head = head(of: run), head.count >= 3, !stopWords.contains(head),
                directions[head] == nil, head.contains(where: \.isLetter),
                seen.insert(head).inserted
            else { return }
            heads.append(head)
        }

        var index = 0
        while index < tokens.count {
            guard determiners.contains(tokens[index]) else {
                index += 1
                continue
            }
            var scan = index + 1
            while scan < tokens.count {
                let token = tokens[scan]
                if softBreaks.contains(token) {
                    emit()
                    scan += 1
                    continue
                }
                if phraseBreaks.contains(token) { break }
                run.append(token)
                scan += 1
            }
            emit()
            index = max(scan, index + 1)
        }
        return heads
    }

    /// A block as words plus a marker for every punctuation mark, so a noun
    /// phrase can end at a comma.
    ///
    /// - Parameter text: any text.
    /// - Returns: the tokens, with ``phraseBreak`` standing in for punctuation.
    private static func phraseTokens(in text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for character in text.lowercased() {
            if character.isLetter || character.isNumber {
                current.append(character)
                continue
            }
            if !current.isEmpty {
                tokens.append(current)
                current = ""
            }
            // A hyphen or an apostrophe divides *words*, not phrases. Dungeon's
            // tree says "a jewel-encrusted egg", and a hyphen that ended the
            // noun phrase would queue `x jewel` and lose the egg — which is the
            // one object this whole stage is named after.
            if !character.isWhitespace && !wordJoiners.contains(character) {
                tokens.append(phraseBreak)
            }
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }

    /// The punctuation that sits *inside* a noun phrase rather than ending one.
    private static let wordJoiners: Set<Character> = ["-", "\u{2010}", "\u{2013}", "'", "\u{2019}"]

    /// The word a run is really about, discounting a trailing past participle.
    ///
    /// *"the ground nestled among some large branches"*, *"the message scrawled
    /// in the sawdust"*: English routinely hangs a participle off the back of a
    /// noun phrase, and taking the last word would queue `x nestled` and
    /// `x scrawled`. A word of six letters or more ending in `-ed`, with a word
    /// in front of it, is that construction almost every time.
    ///
    /// `-ing` gets no such rule and must not: *clearing*, *building*, *opening*,
    /// *carving*, *painting*, *railing* and *ceiling* are all things you examine
    /// in this genre, and a blanket rule would throw every one of them away. The
    /// participles that matter there are named in ``phraseBreaks`` instead, one
    /// at a time, which is the honest cost of not having a tagger.
    ///
    /// - Parameter run: the words of one noun phrase.
    /// - Returns: its head, or `nil` for an empty run.
    private static func head(of run: [String]) -> String? {
        guard let last = run.last else { return nil }
        guard run.count > 1, last.count >= 6, last.hasSuffix("ed") else { return last }
        return run[run.count - 2]
    }

    /// The stand-in for a punctuation mark. Not a word, so it can never be a
    /// token the splitter also produces.
    private static let phraseBreak = "|"

    /// One block split into sentences, for the timer diff.
    ///
    /// - Parameter text: any text.
    /// - Returns: the trimmed, non-empty sentences.
    static func sentences(in text: String) -> [String] {
        text.split(whereSeparator: { ".!?\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// A command reduced to what makes it the same command as another, for the
    /// novelty ratio.
    private static func normalized(_ command: String) -> String {
        words(in: command).joined(separator: " ")
    }

    /// The labels a command's two object slots should be known by: the last
    /// content word before the preposition and the last one after it.
    ///
    /// The word the tester typed, deliberately, rather than the entity's
    /// declared name — a queue item is a command somebody pastes, and "x hook"
    /// is a command where "x smallBrassHook" is a guess at a property name.
    ///
    /// - Parameter command: the raw line.
    /// - Returns: the direct and indirect labels, either of which may be `nil`.
    private static func labels(in command: String) -> (direct: String?, indirect: String?) {
        let tokens = words(in: command)
        guard let split = tokens.firstIndex(where: prepositions.contains) else {
            return (tokens.dropFirst().last(where: isLabel), nil)
        }
        let before = tokens[..<split].dropFirst()
        let after = tokens[(split + 1)...]
        return (before.last(where: isLabel), after.last(where: isLabel))
    }

    /// Whether a typed word can stand as an object's label.
    ///
    /// A label goes into an item id and into a command somebody pastes, so it
    /// has to be a word that means the thing. `it`, `all` and `them` mean
    /// whatever the last line meant, which is not the same claim.
    ///
    /// - Parameter word: a token of the command.
    /// - Returns: whether it can label an object.
    private static func isLabel(_ word: String) -> Bool {
        word.count >= 3 && !stopWords.contains(word) && !pronouns.contains(word)
    }

    /// The words that stand in for a thing rather than naming one.
    ///
    /// Built *on* ``Vocabulary/reservedWords`` rather than restating it. That
    /// set is the engine's own definition of the words the parser claims for
    /// itself — the three this doc names above are three of its four — so a
    /// fifth added there has to reach ``isLabel(_:)`` too. Re-typed, it would
    /// not: `isLabel` would accept the new word as an object label and build an
    /// item id out of a word meaning "whatever the last line meant", which is
    /// the one failure this list exists to prevent.
    ///
    /// The rest are pronouns and quantifiers the parser has no opinion about
    /// but prose uses constantly, so they are named here and only here.
    ///
    /// Reading the static does not breach this file's firewall: `reservedWords`
    /// is engine-wide, not a fact about the game under test — unlike
    /// ``Vocabulary/prepositions``, which the bootstrap fills per game and
    /// which is why ``prepositions`` below stays private.
    private static let pronouns: Set<String> = Vocabulary.reservedWords.union([
        "they", "him", "her", "both", "those", "these", "one", "ones",
    ])

    /// A fragment short enough to quote inside a queue line.
    ///
    /// Named apart from the two `clipped` helpers in ``PlaytestSession`` and
    /// ``PlaytestTools``: those enforce the 12,000-character result cap and keep
    /// a text's *tail*, where this one elides a quotation's *head* down to 90
    /// characters and adds the quotation marks. Same word, opposite end, three
    /// orders of magnitude apart — so it does not share their name.
    private static func quoted(_ text: String) -> String {
        let squeezed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard squeezed.count > 90 else { return "\"\(squeezed)\"" }
        return "\"\(squeezed.prefix(87))…\""
    }

    /// A rate, defined as zero when there is nothing to divide by.
    private static func ratio(_ top: Int, over bottom: Int) -> Double {
        bottom == 0 ? 0 : Double(top) / Double(bottom)
    }

    /// The compass and vertical words a room description can name.
    ///
    /// `in` and `out` are excluded even though the engine has them: they are
    /// far too common in ordinary prose to read as exits, and the false
    /// positives would crowd out the compass directions that carry the signal.
    ///
    /// Derived from ``Direction`` rather than re-typed from it, so the
    /// exclusion above is the only thing this declaration actually says. A
    /// direction added to the engine and not to a hand-written copy here would
    /// stop the ledger raising and discharging `exit:` items for it *silently*,
    /// while ``walked`` went on keying that same direction off the real enum —
    /// so the queue and the walked map would disagree and neither would say so.
    ///
    /// Reading the enum does not breach this file's firewall: `Direction` is an
    /// engine-wide static, not a fact about the game under test.
    private static let directions: [String: Direction] = Dictionary(
        uniqueKeysWithValues: Direction.allCases
            .filter { $0 != .in && $0 != .out }
            .map { ($0.rawValue, $0) })

    /// The words after which the second half of a command names a second thing.
    private static let prepositions: Set<String> = [
        "in", "into", "on", "onto", "at", "to", "with", "under", "behind", "from",
        "through", "over", "against", "inside",
    ]

    /// The words that open a noun phrase.
    private static let determiners: Set<String> = [
        "a", "an", "the", "some", "this", "that", "these", "those", "his", "her", "its",
        "their", "your", "my", "our", "another", "each", "every", "no", "several",
        "many", "few", "both", "one", "two", "three", "four", "five", "six", "seven",
        "eight", "nine", "ten", "dozen",
    ]

    /// The words that close a noun phrase and open the next one — which is what
    /// makes "a cup of twigs and moss" three things rather than one.
    private static let softBreaks: Set<String> = ["of", "and", "or", "nor"]

    /// Everything that closes a noun phrase: punctuation, the prepositions, the
    /// determiners themselves, and the verbs a room description is built out of.
    ///
    /// The verb list is short and unashamedly a list. There is no part-of-speech
    /// tagger in this engine and there is not going to be one; what this has to
    /// do is stop a run at the point where a description stops naming the thing
    /// and starts saying what it does, and forty words of *stands, sits, leads,
    /// hangs, runs* covers nearly all of that in this genre.
    /// It is a heuristic and it stays one. There is no part-of-speech tagger in
    /// this engine and there is not going to be one, so a verb this list has
    /// never heard of will occasionally let a run past its head — *"a bell rings
    /// somewhere behind the wall"* queues `x somewhere` if `rings` is missing.
    /// The cost of that is one turn and a *"you can't see any such thing"*,
    /// which is survivable and is sometimes the finding; the cost of the
    /// opposite error, cutting a run early, is a queue full of adjectives, which
    /// is the failure this whole extraction exists to prevent.
    private static let phraseBreaks: Set<String> = {
        var words: Set<String> = [phraseBreak]
        words.formUnion(prepositions)
        words.formUnion(determiners)
        words.formUnion(softBreaks)
        words.formUnion([
            "about", "above", "across", "after", "along", "among", "around", "before",
            "below", "beneath", "beside", "between", "beyond", "during", "except",
            "near", "outside", "past", "throughout", "toward", "towards", "underneath",
            "until", "upon", "within", "without", "up", "down", "off", "out", "back",
            "for", "as", "like", "per", "via",
        ])
        words.formUnion([
            "rings", "rattles", "clatters", "groans", "sighs", "mutters", "calls",
            "cries", "shouts", "sings", "chirps", "buzzes", "clicks", "snaps",
            "cracks", "thuds", "booms", "wails", "moans", "howls", "screeches",
            "patters", "drums", "throbs", "pulses", "shifts", "wavers", "quivers",
            "shudders", "settles", "gathers", "spills", "seeps", "oozes", "drapes",
            "coils", "leans", "tilts", "sags", "bulges", "gapes", "yawns",
        ])
        words.formUnion([
            "is", "are", "was", "were", "be", "been", "being", "am", "has", "have",
            "had", "can", "cannot", "could", "will", "would", "shall", "should", "may",
            "might", "must", "does", "did", "done", "but", "not", "than", "then",
            "stands", "stand", "standing", "stood", "sits", "sit", "sitting", "sat",
            "lies", "lie", "lying", "lay", "leads", "lead", "leading", "led",
            "hangs", "hang", "hanging", "hung", "runs", "run", "running", "ran",
            "rests", "rest", "resting", "seems", "seem", "seemed", "looks", "look",
            "looked", "appears", "appear", "appeared", "opens", "closes", "extends",
            "continues", "rises", "falls", "goes", "went", "curves", "winds", "blocks",
            "fills", "covers", "holds", "contains", "glows", "shines", "drips",
            "flows", "echoes", "smells", "remains", "marks", "bears", "shows",
            "reveals", "gives", "makes", "allows", "comes", "gets", "takes", "puts",
            "reads", "says", "tells", "begins", "ends", "surrounds", "towers",
            "stretches", "slopes", "descends", "ascends", "emerges", "disappears",
            "waits", "watches", "moves", "turns", "points", "reaches", "touches",
            "hides", "conceals", "protrudes", "juts", "dangles", "sways", "rustles",
            "creaks", "drifts", "floats", "gleams", "glints", "flickers", "burns",
            "steams", "bubbles", "trickles", "splashes", "roars", "hums", "ticks",
            "whispers", "tucked", "here", "there", "where", "which", "who", "what",
            "saying", "reading", "showing", "bearing", "holding", "containing",
            "covering", "leading", "carrying", "sitting", "leaning", "facing",
            "surrounding", "blocking", "guarding", "marking", "pointing", "reaching",
            "stretching", "winding", "sloping", "rising", "falling", "flowing",
            "dripping", "glowing", "shining", "burning", "waiting", "watching",
            "moving", "turning", "wearing", "nestled",
        ])
        words.formUnion([
            "very", "quite", "rather", "almost", "nearly", "barely", "hardly",
            "apparently", "evidently", "clearly", "obviously", "perhaps",
            "however", "though", "although", "because", "since", "while",
        ])
        return words
    }()

    /// Words that are never a thing to examine.
    ///
    /// Function words, the verbs of the standard repertoire, and the handful of
    /// prose words every parser game prints constantly. A word that slips
    /// through costs one wasted turn and a "you can't see any such thing" —
    /// which is *itself* sometimes the finding, so the list is deliberately
    /// conservative rather than exhaustive.
    private static let stopWords: Set<String> = [
        "and", "the", "are", "was", "were", "been", "being", "for", "from", "into",
        "onto", "with", "without", "that", "this", "these", "those", "there", "here",
        "have", "has", "had", "you", "your", "yours", "its", "it's", "not", "but",
        "all", "any", "some", "more", "most", "very", "just", "only", "also", "than",
        "then", "them", "they", "their", "one", "two", "three", "now", "can", "cannot",
        "could", "would", "should", "will", "shall", "may", "might", "must", "does",
        "did", "done", "get", "got", "see", "saw", "seen", "look", "looks", "looking",
        "seem", "seems", "seemed", "appear", "appears", "nothing", "something",
        "anything", "everything", "someone", "anyone", "everyone", "somebody",
        "nobody", "somewhere", "anywhere", "nowhere", "everywhere", "elsewhere",
        "who", "what", "when", "where", "why", "how", "about", "above",
        "below", "under", "over", "across", "around", "through", "between", "before",
        "after", "again", "back", "away", "off", "out", "already", "still", "yet",
        "too", "own", "such", "each", "every", "other", "another", "same", "both",
        "few", "many", "much", "little", "less", "least", "own", "put", "take",
        "taken", "takes", "give", "given", "goes", "going", "gone", "went", "come",
        "comes", "coming", "came", "make", "makes", "made", "know", "knows", "think",
        "want", "wants", "need", "needs", "try", "tries", "tried", "say", "says",
        "said", "tell", "tells", "told", "ask", "asks", "asked", "cant", "dont",
        "doesnt", "isnt", "wont", "youre", "thats", "theres", "way", "ways", "thing",
        "things", "lot", "bit", "sort", "kind", "part", "side", "end", "top", "bottom",
        "left", "right", "front", "next", "last", "first", "second", "little", "big",
        "large", "small", "long", "short", "old", "new", "good", "bad", "best",
        "worst", "sure", "well", "yes", "really", "quite", "rather", "almost",
        "perhaps", "maybe", "probably", "certainly", "indeed", "however", "though",
        "although", "because", "since", "while", "until", "unless", "upon", "toward",
        "towards", "along", "against", "beside", "beyond", "within", "throughout",
    ]
}
