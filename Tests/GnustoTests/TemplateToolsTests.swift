import Foundation
import Testing

/// The tools `Templates/NewGame/bin/` ships, checked against the ones this
/// repository runs.
///
/// A downstream author's package is a copy of that template, so whatever is not in
/// it does not exist for them — which is how `README.md` and <doc:SharingYourGame>
/// came to tell an adopter to run `bin/playtest-replay` and `bin/export-game`, two
/// scripts only this checkout had. The scripts were already written copy-safe; they
/// were simply never copied.
///
/// Copying them buys a second problem, which is the one this suite guards. Four
/// files now exist twice, and a fix applied to `bin/` and not to the template is
/// silent: this repository's own rounds go on passing, and only an adopter meets
/// the old bug. So the two copies must be **byte-identical**, down to the usage
/// lines — which is why none of the four names a game, and why the one that used to
/// say `bin/gnusto-mcp Zork1` now says what the argument is instead.
///
/// `bin/playtest-preflight`, `bin/playtest-routes` and `bin/lib/` stay behind on
/// purpose: each reads `docs/games/`, `.mcp.json` or `.claude/` by hardcoded path,
/// so shipping them would ship a promise the template cannot keep. Making those
/// paths arguments is the rest of #368.
struct TemplateToolsTests {
    private static let ours = PackageDirectory.subdirectory("bin")
    private static let theirs = PackageDirectory.subdirectory("Templates/NewGame/bin")

    /// The tools the documentation promises an adopter. Written out rather than
    /// discovered, because the failure this guards against is one going *missing*,
    /// and a suite that reads its own expectations off the directory would pass an
    /// empty one.
    private static let promised = ["export-game", "gnusto-mcp", "playtest-measure", "playtest-replay"]

    /// What the template actually ships. The tests below run over this rather than
    /// over ``promised``, so a fifth tool copied in is guarded the day it lands
    /// instead of the day somebody remembers to list it.
    private static let shipped =
        ((try? FileManager.default.contentsOfDirectory(atPath: theirs.path)) ?? [])
        .filter { !$0.hasPrefix(".") }
        .sorted()

    @Test func theTemplateShipsEveryToolTheDocumentationPromises() {
        #expect(
            Set(Self.promised).isSubset(of: Set(Self.shipped)),
            """
            Templates/NewGame/bin/ is missing \(Set(Self.promised).subtracting(Self.shipped).sorted()). \
            README.md and the DocC articles tell an adopter to run these against their own game.
            """)
    }

    @Test(arguments: shipped)
    func everyShippedToolIsExecutable(_ tool: String) {
        #expect(
            FileManager.default.isExecutableFile(
                atPath: Self.theirs.appendingPathComponent(tool).path),
            "Templates/NewGame/bin/\(tool) is not executable; git tracks the bit, so this one is committed wrong")
    }

    @Test(arguments: shipped)
    func everyShippedToolIsByteIdenticalToTheOneThisRepositoryRuns(_ tool: String) throws {
        let ours = try Data(contentsOf: Self.ours.appendingPathComponent(tool))
        let theirs = try Data(contentsOf: Self.theirs.appendingPathComponent(tool))
        #expect(
            ours == theirs,
            """
            bin/\(tool) and Templates/NewGame/bin/\(tool) differ. They are one file kept in \
            two places: fix whichever is wrong and copy it over the other. A tool the template \
            ships and this repository does not run has no home here at all.
            """)
    }
}
