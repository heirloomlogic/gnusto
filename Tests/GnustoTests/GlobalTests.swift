import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto

enum NonFiniteDouble: String, CaseIterable, Codable, Sendable {
    case nan
    case positiveInfinity
    case negativeInfinity

    var value: Double {
        switch self {
        case .nan: .nan
        case .positiveInfinity: .infinity
        case .negativeInfinity: -.infinity
        }
    }

    var diagnosticValue: String {
        switch self {
        case .nan: "value nan"
        case .positiveInfinity: "value inf"
        case .negativeInfinity: "value -inf"
        }
    }
}

struct GlobalTests {
    #if GNUSTO_EXIT_TESTS

    @Test("a non-finite Double default traps during bootstrap", arguments: NonFiniteDouble.allCases)
    func nonFiniteDoubleDefaultTrapsDuringBootstrap(_ invalid: NonFiniteDouble) async {
        let result = await #expect(
            processExitsWith: .failure, observing: [\.standardErrorContent]
        ) {
            [invalid = invalid as NonFiniteDouble] in
            _ = try Bootstrap.build(NonFiniteDefaultGlobalGame(invalid))
        }
        expectTrap(result, says: #"@Global "tide""#, "non-finite Double", invalid.diagnosticValue)
    }

    @Test("a non-finite Double assignment traps immediately", arguments: NonFiniteDouble.allCases)
    func nonFiniteDoubleAssignmentTrapsImmediately(_ invalid: NonFiniteDouble) async {
        let result = await #expect(
            processExitsWith: .failure, observing: [\.standardErrorContent]
        ) {
            [invalid = invalid as NonFiniteDouble] in
            _ = try await play(fresh: NonFiniteAssignmentGlobalGame(invalid), ["poison"])
        }
        expectTrap(result, says: #"@Global "tide""#, "non-finite Double", invalid.diagnosticValue)
    }

    #endif

    @Test("a finite Double global saves and restores")
    func finiteDoubleGlobalSavesAndRestores() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let transcript = try await play(
            FiniteDoubleGlobalGame(),
            ["raise", "save", "finite", "drain", "restore", "finite", "measure"],
            saveDirectory: directory)

        expectInOrder(transcript, ["The tide rises.", "Saved.", "The tide falls.", "Restored.", "The tide is 3.5."])
    }
}
