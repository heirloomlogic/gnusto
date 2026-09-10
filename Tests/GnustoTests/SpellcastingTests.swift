import Foundation
import GnustoSpellcasting
import GnustoTestSupport
import Testing

@testable import Gnusto

/// Library-level behavior of `GnustoSpellcasting`, exercised through a tiny
/// synthetic game whose spell effects always succeed — so each test isolates
/// one casting paradigm's availability, cost, and consumption rules without a
/// puzzle in the way.
struct SpellcastingTests {
    // MARK: - Cantrip

    @Test func aCantripIsFreeAndCastableEveryTurn() async throws {
        let transcript = try await play(SpellLab(), ["cast spark", "cast spark", "cast spark"])
        #expect(transcript.components(separatedBy: "A spark leaps.").count == 4)
    }

    @Test func spellIsANoiseWordTheLayerContributes() async throws {
        // "the" is a built-in article and "spell" comes from the layer, so
        // `cast the spark spell` parses as `cast spark`.
        let transcript = try await play(SpellLab(), ["cast the spark spell"])
        #expect(transcript.contains("A spark leaps."))
    }

    // MARK: - Prepared / memorized

    @Test func aPreparedSpellIsRefusedUntilMemorizedAndSpentOnCast() async throws {
        let transcript = try await play(
            SpellLab(),
            ["cast mend", "take tome", "memorize mend", "cast mend", "cast mend"])
        expectInOrder(
            transcript,
            [
                "You don't have the mend spell prepared.",
                "You fix the mend spell in your memory.",
                "The mend takes hold.",  // first cast succeeds
                "You don't have the mend spell prepared.",  // consumed — refused again
            ])
    }

    @Test func memorizingRequiresTheSpellbookInHandWhenConfigured() async throws {
        let transcript = try await play(
            SpellLab(),
            ["memorize mend", "take tome", "memorize mend"])
        expectInOrder(
            transcript,
            [
                "You need your spellbook in hand to memorize mend.",
                "You fix the mend spell in your memory.",
            ])
    }

    @Test func aSpellWithNoBookRequirementMemorizesAnywhere() async throws {
        // `ward` is declared `.prepared(book: nil)`, so no spellbook is needed.
        let transcript = try await play(SpellLab(), ["memorize ward", "cast ward"])
        expectInOrder(
            transcript,
            ["You fix the ward spell in your memory.", "A ward shimmers up."])
    }

    @Test func spellMemoryIsFiniteAndACastFreesASlot() async throws {
        // SpellLab has a single memory slot.
        let transcript = try await play(
            SpellLab(),
            ["take tome", "memorize mend", "memorize ward", "cast mend", "memorize ward"])
        expectInOrder(
            transcript,
            [
                "You fix the mend spell in your memory.",
                "Your mind can hold no more spells; cast one before learning another.",
                "The mend takes hold.",  // frees the slot
                "You fix the ward spell in your memory.",
            ])
    }

    // MARK: - Energy / mana

    @Test func anEnergySpellDrainsThePoolAndIsRefusedWhenTooLow() async throws {
        // maxMana 6, bolt costs 4: one cast, then the pool is too low.
        let transcript = try await play(SpellLab(), ["cast bolt", "cast bolt"])
        expectInOrder(
            transcript,
            ["The bolt streaks out.", "You lack the magical energy to cast bolt."])
    }

    @Test func restRefillsTheEnergyPool() async throws {
        let transcript = try await play(SpellLab(), ["cast bolt", "cast bolt", "rest", "cast bolt"])
        expectInOrder(
            transcript,
            [
                "The bolt streaks out.",
                "You lack the magical energy to cast bolt.",
                "your magical energy wells back up to full",
                "The bolt streaks out.",
            ])
    }

    @Test func restIsRefusedWhenEnergyIsAlreadyFull() async throws {
        let transcript = try await play(SpellLab(), ["rest"])
        #expect(transcript.contains("Your magical energy is already at its peak."))
    }

    // MARK: - Status

    @Test func spellsReportsMemorizedSpellsAndRemainingEnergy() async throws {
        let transcript = try await play(
            SpellLab(),
            ["spells", "take tome", "memorize mend", "cast bolt", "spells"])
        expectInOrder(
            transcript,
            [
                "You hold no spells in mind.",
                "Your magical energy stands at 6 of 6.",
                "You hold in mind: mend.",
                "Your magical energy stands at 2 of 6.",
            ])
    }

    // MARK: - Scroll

    @Test func aScrollSpellNeedsTheScrollAndConsumesItOnCast() async throws {
        let transcript = try await play(
            SpellLab(),
            ["cast blink", "take scroll", "cast blink", "cast blink"])
        expectInOrder(
            transcript,
            [
                "You have no scroll of blink to read from.",
                "The world blinks.",  // cast with scroll in hand
                "You have no scroll of blink to read from.",  // scroll consumed
            ])
    }

    // MARK: - Save-safety

    /// Every line about a spell names it by its word, which is `called:` when
    /// the intent's own name is not one a player reads — so "the seal spell",
    /// never "the castSeal spell", in the refusal, the memorizing and the
    /// report alike.
    @Test func aSpellIsNamedByItsWordNotItsIntent() async throws {
        let transcript = try await play(
            SpellLab(), ["seal", "memorize seal", "spells", "memorize seal", "cast seal"])
        expectInOrder(
            transcript,
            [
                "You don't have the seal spell prepared.",
                "You fix the seal spell in your memory.",
                "You hold in mind: seal.",
                "You already have seal firmly in mind.",
                "The seal sets.",
            ])
        #expect(!transcript.contains("castSeal"))
    }

    /// Two prepared spells on one memorize verb are two actions on one intent;
    /// the bootstrap keeps the later and says so.
    @Test func twoSpellsSharingAMemorizeVerbWarn() throws {
        let (definition, _) = try Bootstrap.build(SharedLearnVerbLab())
        #expect(
            definition.warnings.contains {
                $0.contains("custom action for intent \"learnMend\" overrides an earlier custom action")
            })
    }

    /// The word is display and the intent is identity, so two spells `called:`
    /// the same thing are memorized, cast and spent one at a time. Keying
    /// memory on the word made memorizing either arm both, cast either spend
    /// both, and the second memorize answer `alreadyMemorized`.
    @Test func twoSpellsSharingAWordDoNotShareAMemorySlot() async throws {
        let transcript = try await play(
            SharedWordLab(),
            [
                "memorize kindle",
                "cast quench",  // the other spell is still unprepared
                "memorize quench",  // and can be memorized in its own right
                "spells",
                "cast kindle",
                "cast kindle",  // spent
                "cast quench",  // untouched by spending the first
            ])
        expectInOrder(
            transcript,
            [
                "You fix the fire spell in your memory.",
                "You don't have the fire spell prepared.",
                "You fix the fire spell in your memory.",
                "You hold in mind: fire and fire.",
                "The kindling takes.",
                "You don't have the fire spell prepared.",
                "The quenching takes.",
            ])
    }

    @Test func preparedSpellsAndManaSurviveSaveAndRestore() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-spell-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let transcript = try await play(
            SpellLab(),
            [
                "take tome", "memorize mend",  // memory: [mend]
                "cast bolt",  // mana 6 -> 2
                "save", "slot",
                "restore", "slot",
                "cast bolt",  // mana still 2 -> refused (pool survived)
                "cast mend",  // still prepared (memory survived)
            ],
            saveDirectory: dir)
        expectInOrder(
            transcript,
            [
                "Restored.",
                "You lack the magical energy to cast bolt.",  // mana round-tripped
                "The mend takes hold.",  // prepared round-tripped
            ])
    }
}

// MARK: - Synthetic fixture

extension Intent {
    #verb("spark", ["spark"], ["cast", "spark"])
    #verb("mend", ["mend"], ["cast", "mend"])
    #verb("ward", ["ward"], ["cast", "ward"])
    #verb("bolt", ["bolt"], ["cast", "bolt"])
    #verb("blink", ["blink"], ["cast", "blink"])
    #verb("learnMend", ["memorize", "mend"], ["learn", "mend"])
    #verb("learnWard", ["memorize", "ward"], ["learn", "ward"])
    /// An intent whose name is not a word a player reads, so the spell is
    /// `called:` something that is.
    #verb("castSeal", ["seal"], ["cast", "seal"])
    #verb("learnSeal", ["memorize", "seal"], ["learn", "seal"])
    /// Two spells a game deliberately calls the same thing.
    #verb("kindleFire", ["kindle"], ["cast", "kindle"])
    #verb("quenchFire", ["quench"], ["cast", "quench"])
    #verb("learnKindle", ["memorize", "kindle"])
    #verb("learnQuench", ["memorize", "quench"])
}

/// Two prepared spells that share a display word and nothing else — the
/// `castFire`/`burnFire` shape, both `called: "fire"` so every line about
/// either reads as a player would say it.
struct SharedWordLab: Game {
    let title = "Shared Word"
    let intro = ""

    let magic = Spellcasting(memorySlots: 2, maxMana: 6)

    let lab = Location {
        name("Lab")
        description("A bare stone cell.")
    }

    var content: GameContents { magic }

    var verbs: [SyntaxRule] {
        [.kindleFire, .quenchFire, .learnKindle, .learnQuench]
    }

    var actions: [IntentAction] {
        magic.spell(
            .kindleFire, called: "fire", cost: .prepared(book: nil, learnVia: .learnKindle)
        ) {
            say("The kindling takes.")
        }
        magic.spell(
            .quenchFire, called: "fire", cost: .prepared(book: nil, learnVia: .learnQuench)
        ) {
            say("The quenching takes.")
        }
    }

    var map: WorldMap { player.starts(in: lab) }
}

/// One room, one of every spell paradigm, effects that always succeed — a rig
/// for exercising the casting rules in isolation. A single memory slot and a
/// small mana pool make the finite-memory and energy limits easy to hit.
struct SpellLab: Game {
    let title = "Spell Lab"
    let intro = "A bare testing cell."

    let magic = Spellcasting(memorySlots: 1, maxMana: 6)

    let lab = Location {
        name("Lab")
        description("A bare stone cell.")
    }

    let tome = Item {
        name("tome")
        synonyms("spellbook", "book")
        description("A practice spellbook.")
    }

    let scroll = Item {
        name("scroll")
        synonyms("parchment")
        description("A one-shot scroll.")
    }

    var content: GameContents {
        magic
    }

    var verbs: [SyntaxRule] {
        [.spark, .mend, .ward, .bolt, .blink, .learnMend, .learnWard, .castSeal, .learnSeal]
    }

    var actions: [IntentAction] {
        magic.spell(.spark, cost: .cantrip) { say("A spark leaps.") }
        magic.spell(.mend, cost: .prepared(book: tome, learnVia: .learnMend)) {
            say("The mend takes hold.")
        }
        magic.spell(.ward, cost: .prepared(book: nil, learnVia: .learnWard)) {
            say("A ward shimmers up.")
        }
        magic.spell(.bolt, cost: .energy(4)) { say("The bolt streaks out.") }
        magic.spell(.blink, cost: .scroll(scroll)) { say("The world blinks.") }
        magic.spell(.castSeal, called: "seal", cost: .prepared(book: nil, learnVia: .learnSeal)) {
            say("The seal sets.")
        }
    }

    var map: WorldMap {
        player.starts(in: lab)
        tome.starts(in: lab)
        scroll.starts(in: lab)
    }
}

/// Two prepared spells wired to one memorize verb — the collision the
/// bootstrap warns about.
struct SharedLearnVerbLab: Game {
    let title = "Shared Verb"
    let intro = ""

    let magic = Spellcasting()

    let lab = Location {
        name("Lab")
        description("A bare stone cell.")
    }

    var content: GameContents { magic }

    var verbs: [SyntaxRule] {
        [.mend, .ward, .learnMend]
    }

    var actions: [IntentAction] {
        magic.spell(.mend, cost: .prepared(book: nil, learnVia: .learnMend)) { say("Mended.") }
        magic.spell(.ward, cost: .prepared(book: nil, learnVia: .learnMend)) { say("Warded.") }
    }

    var map: WorldMap {
        player.starts(in: lab)
    }
}
