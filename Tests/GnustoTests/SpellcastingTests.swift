import Foundation
import Gnusto
import GnustoSpellcasting
import GnustoTestSupport
import Testing

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
        [.spark, .mend, .ward, .bolt, .blink, .learnMend, .learnWard]
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
    }

    var map: WorldMap {
        player.starts(in: lab)
        tome.starts(in: lab)
        scroll.starts(in: lab)
    }
}
