import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto

/// Issue #396: `WorldState` decoded with a *synthesized* `init(from:)` over an
/// explicit `CodingKeys` list, which makes every key required — so a save
/// written before a property existed threw `DecodingError.keyNotFound`,
/// `SaveFile.read` swallowed it in a `try?`, and the player was told "Restore
/// failed." in the same words a corrupt file earns. Two properties had been
/// added since `currentFormat` was last touched and it was still `1`, and
/// `file.format == currentFormat` is an equality test, so even a *correct*
/// bump would have refused old saves rather than read them.
///
/// This suite is about the save *format* — what it tolerates, what it refuses,
/// and whether the coder still covers the type. `SaveRestoreTests` is about the
/// save/restore *feature*, and the split is deliberate: the tests below fail for
/// reasons that have nothing to do with whether SAVE and RESTORE work.
///
/// ## The hazard this suite exists to hold
///
/// Hand-writing the coder is what makes an old save readable, and it also
/// introduces a failure the synthesized coder made impossible: a property added
/// later and not wired into `init(from:)`/`encode(to:)` silently vanishes from
/// every save, and nothing says so. `theEncodedKeysAreExactlyTheCodingKeys` and
/// `everyStoredPropertyHasACodingKey` are that guard, and they are the reason
/// the hand-written coder is safe to have.
struct SaveFormatTests {
    // MARK: - Fixtures

    /// Two rooms, a takable coin, a container and a scalar global — enough
    /// state that a real save exercises most of the format.
    private struct LedgerGame: Game {
        let title = "Ledger"
        let intro = "A counting house."

        let office = Location {
            name("Office")
            description("Ledgers to the ceiling.")
        }

        let strongroom = Location {
            name("Strongroom")
            description("Iron and dust.")
        }

        let coin = Item {
            name("gold coin")
        }

        let chest = Item {
            name("banded chest")
            container
            openable
        }

        @Global var audits = 0

        var map: WorldMap {
            player.starts(in: office)
            coin.starts(in: office)
            chest.starts(in: strongroom)
            office.north(strongroom)
            strongroom.south(office)
        }
    }

    /// `SaveRestoreTests` and `TimerTests` each spell this privately too — the
    /// established shape for a throwaway save path in this suite. Lifting the
    /// three into `GnustoTestSupport` is worth doing and is not this change's
    /// business.
    private static func temporarySavePath(_ label: String) -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-fmt-\(label)-\(UUID().uuidString).sav").path
    }

    /// A genuine save of `LedgerGame`, as a JSON object.
    ///
    /// Written through `SaveFile.write` rather than re-deriving its encoder
    /// settings here, so a test that pokes at the format is always poking at
    /// the bytes the engine actually emits.
    private static func genuineSave() throws -> [String: Any] {
        let (_, state) = try Bootstrap.buildCore(LedgerGame())
        let url = URL(fileURLWithPath: Self.temporarySavePath("genuine"))
        defer { try? FileManager.default.removeItem(at: url) }
        try SaveFile.write(state, title: "Ledger", to: url)
        return try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    /// Stages a genuine save on disk, lets `edit` mangle it, and hands back the
    /// path — owning the cleanup, which four call sites otherwise each had to
    /// remember to `defer`.
    private func withStagedSave(
        _ label: String, _ edit: (inout [String: Any]) throws -> Void,
        _ body: (String) async throws -> Void
    ) async throws {
        let path = Self.temporarySavePath(label)
        defer { try? FileManager.default.removeItem(atPath: path) }
        var save = try Self.genuineSave()
        try edit(&save)
        try Self.encode(save).write(to: URL(fileURLWithPath: path))
        try await body(path)
    }

    private static func encode(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// `EntityID` is a struct, so it encodes as an object rather than a bare
    /// string — and a `[EntityID: _]` dictionary therefore encodes as a *flat
    /// array* of alternating keys and values, which is what `Codable` does for
    /// any dictionary whose key isn't a `String` or `Int`. Both spellings are
    /// easy to guess wrong, and guessing wrong makes a save that simply fails
    /// to decode, which several assertions below would then pass on for the
    /// wrong reason.
    private static func id(_ name: String) -> [String: Any] { ["raw": name] }

    // MARK: - The coder still covers the type

    @Test("the encoded keys are exactly the CodingKeys")
    func theEncodedKeysAreExactlyTheCodingKeys() throws {
        let save = try Self.genuineSave()
        let state = try #require(save["state"] as? [String: Any])
        let declared = Set(WorldState.CodingKeys.allCases.map(\.rawValue))

        #expect(
            Set(state.keys) == declared,
            """
            The hand-written encode(to:) and CodingKeys have drifted. Missing \
            from the encoded save: \(declared.subtracting(state.keys).sorted()). \
            Encoded but not declared: \(Set(state.keys).subtracting(declared).sorted()).
            """)
    }

    @Test("every stored property has a coding key")
    func everyStoredPropertyHasACodingKey() throws {
        let (_, state) = try Bootstrap.buildCore(LedgerGame())
        let stored = Mirror(reflecting: state).children.count
        // The one omission is `containmentCache`, which is derived and must
        // never serialize. Any other gap means a property was added to
        // `WorldState` without a `CodingKeys` case, so it is absent from every
        // save and restores as its default — silently, which is the whole
        // failure mode #396 is about.
        #expect(
            stored == WorldState.CodingKeys.allCases.count + 1,
            """
            WorldState has \(stored) stored properties but \
            \(WorldState.CodingKeys.allCases.count) coding keys (+1 for the \
            never-serialized containmentCache). A property was added without a \
            CodingKeys case, an init(from:) line and an encode(to:) line.
            """)
    }

    // MARK: - What an old save may leave out

    @Test("every key but playerLocation may be absent")
    func everyKeyButPlayerLocationMayBeAbsent() throws {
        let save = try Self.genuineSave()
        let state = try #require(save["state"] as? [String: Any])

        for key in WorldState.CodingKeys.allCases where key != .playerLocation {
            var trimmed = state
            trimmed.removeValue(forKey: key.rawValue)
            var file = save
            file["state"] = trimmed

            // Not `#expect(throws: Never.self)`: the point is which key broke.
            do {
                _ = try JSONDecoder().decode(SaveFile.self, from: Self.encode(file))
            } catch {
                Issue.record(
                    """
                    A save omitting "\(key.rawValue)" no longer decodes, so every \
                    save written before that property existed is refused as \
                    "Restore failed." Decode it with decodeIfPresent and the \
                    property's declared default. Underlying: \(error)
                    """)
            }
        }
    }

    @Test("a save without playerLocation is still refused")
    func aSaveWithoutPlayerLocationIsStillRefused() throws {
        // The one property with no declared default: there is no answer to
        // "where is the player" to fall back on, so absence is corruption
        // rather than age.
        let save = try Self.genuineSave()
        var state = try #require(save["state"] as? [String: Any])
        state.removeValue(forKey: "playerLocation")
        var file = save
        file["state"] = state

        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(SaveFile.self, from: Self.encode(file))
        }
    }

    @Test("each set decodes from its own key")
    func eachSetDecodesFromItsOwnKey() throws {
        // Six `Set<EntityID>` properties side by side is exactly where a
        // hand-written decoder gets cross-wired by a copied line, and the
        // types are identical so the compiler cannot say. Give each set a
        // member nothing else has and check it lands where it belongs.
        let setKeys: [WorldState.CodingKeys] = [
            .litRooms, .litItems, .wornItems, .openItems, .lockedItems,
            .revealedItems, .unconsciousActors, .touched, .visited, .metActors,
        ]
        let save = try Self.genuineSave()
        var state = try #require(save["state"] as? [String: Any])
        for key in setKeys {
            state[key.rawValue] = [Self.id("marker-\(key.rawValue)")]
        }
        var file = save
        file["state"] = state

        let decoded = try JSONDecoder().decode(SaveFile.self, from: Self.encode(file)).state
        let readBack: [WorldState.CodingKeys: Set<EntityID>] = [
            .litRooms: decoded.litRooms,
            .litItems: decoded.litItems,
            .wornItems: decoded.wornItems,
            .openItems: decoded.openItems,
            .lockedItems: decoded.lockedItems,
            .revealedItems: decoded.revealedItems,
            .unconsciousActors: decoded.unconsciousActors,
            .touched: decoded.touched,
            .visited: decoded.visited,
            .metActors: decoded.metActors,
        ]
        for key in setKeys {
            #expect(
                readBack[key] == [EntityID("marker-\(key.rawValue)")],
                "\(key.rawValue) decoded from the wrong key: got \(readBack[key] ?? [])")
        }
    }

    @Test("each counter decodes from its own key")
    func eachCounterDecodesFromItsOwnKey() throws {
        // The other place a copied line goes unnoticed: three `Int`s in a row,
        // where the compiler has nothing to say either. Give each a value no
        // other holds.
        //
        // Not a byte-for-byte round trip, which is the obvious test and the
        // wrong one here: `placements`, `globals` and `descriptionOverrides`
        // are keyed by `EntityID`, so they encode as flat arrays whose order is
        // the dictionary's, and re-encoding a decoded save reorders them
        // legitimately. Byte-identity would fail on a coder that is perfectly
        // correct.
        let save = try Self.genuineSave()
        var state = try #require(save["state"] as? [String: Any])
        state["score"] = 11
        state["moves"] = 22
        state["rngState"] = 33
        var file = save
        file["state"] = state

        let decoded = try JSONDecoder().decode(SaveFile.self, from: Self.encode(file)).state

        #expect(decoded.score == 11)
        #expect(decoded.moves == 22)
        #expect(decoded.rngState == 33)
    }

    // MARK: - The frozen format-1 fixture

    /// A real format-1 save of `LedgerGame` as it was written *before*
    /// `unconsciousActors` (`ad2f340`, 2026-08-06) and `metActors` (`666f738`,
    /// 2026-08-28) were added to `WorldState`: both keys are absent, exactly as
    /// they were on disk. Frozen on purpose — regenerating it would defeat the
    /// test, which is that a file written by an *older build* still reads.
    ///
    /// The player has walked north to the Strongroom carrying the coin, so the
    /// restore has something to prove beyond not throwing.
    private static let formatOneSave = """
        {
          "format" : 1,
          "title" : "Ledger",
          "state" : {
            "activeDaemons" : [],
            "activeFuses" : {},
            "descriptionOverrides" : [],
            "globals" : [
              { "raw" : "audits" },
              { "int" : { "_0" : 3 } }
            ],
            "litItems" : [],
            "litRooms" : [ { "raw" : "office" }, { "raw" : "strongroom" } ],
            "lockedItems" : [],
            "moves" : 4,
            "openItems" : [],
            "placements" : [
              { "raw" : "coin" },
              { "heldBy" : { "_0" : { "raw" : "player" } } },
              { "raw" : "chest" },
              { "room" : { "_0" : { "raw" : "strongroom" } } },
              { "raw" : "player" },
              { "nowhere" : {} }
            ],
            "playerLocation" : { "raw" : "strongroom" },
            "playerVehicle" : null,
            "pronounIt" : { "raw" : "coin" },
            "pronounThem" : [],
            "revealedItems" : [],
            "rngState" : 99,
            "score" : 0,
            "status" : { "playing" : {} },
            "touched" : [ { "raw" : "coin" } ],
            "visited" : [ { "raw" : "office" }, { "raw" : "strongroom" } ],
            "wornItems" : []
          }
        }
        """

    @Test("a format-1 save missing the later fields still restores")
    func aFormatOneSaveMissingTheLaterFieldsStillRestores() async throws {
        let path = Self.temporarySavePath("format1")
        defer { try? FileManager.default.removeItem(atPath: path) }
        try Data(Self.formatOneSave.utf8).write(to: URL(fileURLWithPath: path))

        let transcript = try await play(LedgerGame(), ["restore", path, "look", "inventory"])

        #expect(transcript.contains("Restored."))
        // Where the save says, not where the game starts.
        #expect(turnOutput(of: "look", in: transcript).contains("Strongroom"))
        #expect(turnOutput(of: "inventory", in: transcript).contains("gold coin"))
        // The absent properties came back as their declared defaults rather
        // than refusing the file.
        #expect(!transcript.contains("Restore failed."))
    }

    @Test("the frozen fixture really is missing the later fields")
    func theFrozenFixtureReallyIsMissingTheLaterFields() throws {
        // Guards the test above against a well-meaning regeneration: if the
        // fixture is refreshed from a current save it stops testing anything,
        // and it would still pass.
        let object = try #require(
            JSONSerialization.jsonObject(with: Data(Self.formatOneSave.utf8))
                as? [String: Any])
        let state = try #require(object["state"] as? [String: Any])
        #expect(state["unconsciousActors"] == nil)
        #expect(state["metActors"] == nil)
    }

    // MARK: - A format we cannot read says so

    @Test("a newer format is reported as a version mismatch, not a failure")
    func aNewerFormatIsReportedAsAVersionMismatch() async throws {
        try await withStagedSave("future") { save in
            save["format"] = SaveFile.currentFormat + 1
            // A shape this build has never seen, so the state cannot decode
            // either — the case that forces the format to be read first.
            save["state"] = ["somethingNew": true]
        } _: { path in
            let transcript = try await play(LedgerGame(), ["restore", path, "look"])

            #expect(!transcript.contains("Restore failed."))
            #expect(transcript.contains(GameText().saveVersionMismatch()))
            // Refused whole: the game keeps running from where it was.
            #expect(turnOutput(of: "look", in: transcript).contains("Office"))
        }
    }

    @Test("another game's save says so even when its state cannot decode")
    func anotherGamesSaveSaysSoEvenWhenItsStateCannotDecode() async throws {
        try await withStagedSave("othergame") { save in
            save["title"] = "Some Other Game"
            save["state"] = ["nothing": "recognizable"]
        } _: { path in
            let transcript = try await play(LedgerGame(), ["restore", path])

            // Reading the envelope before the state is what makes this
            // reachable: the title is knowable without decoding a `WorldState`
            // this build cannot parse.
            #expect(transcript.contains(GameText().wrongGameSave()))
        }
    }

    @Test("the readable range is a range, not an equality")
    func theReadableRangeIsARangeNotAnEquality() {
        // The bug in miniature: `format == currentFormat` refuses every older
        // save by construction, so bumping the constant to signal a change
        // would void every save on disk. A floor and a ceiling is the shape
        // that lets a bump mean "the shape moved" instead of "start again".
        #expect(SaveFile.minimumReadableFormat <= SaveFile.currentFormat)
    }

    // MARK: - One policy for names this build no longer declares

    /// Writes a save of `LedgerGame` whose globals are `mutate`d as typed
    /// state, so these tests poke `StateValue`s rather than hand-rolled JSON —
    /// a hand-rolled box that stopped matching `StateValue`'s encoding would
    /// turn them into no-ops that still pass.
    private func stagedLedgerSave(
        _ label: String, mutate: (inout [EntityID: StateValue]) -> Void
    ) throws -> String {
        let path = Self.temporarySavePath(label)
        var (_, state) = try Bootstrap.buildCore(LedgerGame())
        mutate(&state.globals)
        try SaveFile.write(state, title: "Ledger", to: URL(fileURLWithPath: path))
        return path
    }

    @Test("an unknown global is dropped, like an unknown timer")
    func anUnknownGlobalIsDroppedLikeAnUnknownTimer() async throws {
        let path = try stagedLedgerSave("staleglobal") {
            $0[EntityID("audits")] = .int(7)
            // A global an older build declared and this one does not — the same
            // situation `SaveFile` already accepts for a stale timer name, since
            // the title-only fingerprint cannot tell two builds of one game
            // apart.
            $0[EntityID("retiredCounter")] = .int(1)
        }
        defer { try? FileManager.default.removeItem(atPath: path) }

        let transcript = try await play(LedgerGame(), ["restore", path, "look"])

        #expect(transcript.contains("Restored."))
        #expect(!transcript.contains("Restore failed."))
        #expect(turnOutput(of: "look", in: transcript).contains("Office"))
    }

    // The other half of the policy — a global this build *does* declare, holding
    // a value it cannot hold, refuses the whole file — is
    // `SaveRestoreTests.tamperedMistypedGlobalIsRejected`. It lives there
    // because it is one of a family of crafted-file tests that share a forge,
    // and duplicating it here would only mean two tests that always fail
    // together.

    // MARK: - A `.data` global is validated at restore, not on first read

    @Test("a boxed global whose shape changed is refused at restore")
    func aBoxedGlobalWhoseShapeChangedIsRefusedAtRestore() throws {
        // `StateValue.sameCase` matched any `.data` against any other `.data`,
        // so a struct global whose `Codable` shape changed restored cleanly and
        // then trapped in `Global.wrappedValue` the first time a rule read it —
        // the one case that should refuse being the one that got through.
        // Comparing `typeName` would not have caught it either: the type is
        // still called the same thing, it just holds different fields now.
        let path = Self.temporarySavePath("reshaped")
        defer { try? FileManager.default.removeItem(atPath: path) }
        var (definition, state) = try Bootstrap.buildCore(ShopGame())
        // Same type name, bytes for a shape it can no longer decode — an author
        // who renamed a field between builds.
        state.globals[EntityID("purse")] = .data(
            typeName: String(reflecting: Purse.self),
            bytes: try JSONEncoder().encode(["pennies": 2]))
        try SaveFile.write(state, title: ShopGame().title, to: URL(fileURLWithPath: path))

        // `.inconsistent` specifically, not merely "some error": a mis-staged
        // fixture also throws, as `.unreadable`, and would let this pass while
        // proving nothing.
        do {
            _ = try SaveFile.read(from: URL(fileURLWithPath: path), matching: definition)
            Issue.record("a global the game can no longer read was accepted")
        } catch {
            #expect(error == .inconsistent, "expected .inconsistent, got \(error)")
        }
    }

    @Test("an untouched boxed global still restores")
    func anUntouchedBoxedGlobalStillRestores() throws {
        // The positive control, and the reason the test above can be trusted:
        // the validator runs the author's own decode, so this says it accepts
        // the ordinary case rather than refusing every `.data` global.
        let path = Self.temporarySavePath("boxedok")
        defer { try? FileManager.default.removeItem(atPath: path) }
        var (definition, state) = try Bootstrap.buildCore(ShopGame())
        // A global only enters `globals` once something writes it; until then
        // the `@Global` reads its declared default and the save carries nothing.
        state.globals[EntityID("purse")] = Purse(coins: 9).stateValue
        try SaveFile.write(state, title: ShopGame().title, to: URL(fileURLWithPath: path))

        let restored = try SaveFile.read(
            from: URL(fileURLWithPath: path), matching: definition)

        let stored = try #require(restored.globals[EntityID("purse")])
        #expect(Purse(stateValue: stored) == Purse(coins: 9))
    }
}
