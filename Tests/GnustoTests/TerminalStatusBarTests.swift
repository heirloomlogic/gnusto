import Testing

@testable import Gnusto

@Suite("TerminalIOHandler.statusBar")
struct TerminalStatusBarTests {
    @Test("Pads to the full width with the score flush right")
    func padsAsciiToWidth() {
        let bar = TerminalIOHandler.statusBar(
            StatusLine(locationName: "West of House", score: 0, moves: 0), cols: 40)
        #expect(DisplayWidth.columns(of: bar) == 40)
        #expect(bar.hasPrefix(" West of House"))
        #expect(bar.hasSuffix("Score: 0   Moves: 0 "))
    }

    @Test("A wide location name still fills exactly to the column width")
    func padsWideNameToWidth() {
        // A CJK location name is narrower in characters than in columns; the
        // padding must measure columns so the right-hand score stays aligned.
        let bar = TerminalIOHandler.statusBar(
            StatusLine(locationName: "西の家", score: 10, moves: 3), cols: 40)
        #expect(DisplayWidth.columns(of: bar) == 40)
        #expect(bar.hasSuffix("Score: 10   Moves: 3 "))
    }

    @Test("Clips by column when the content can't fit")
    func clipsByColumn() {
        let bar = TerminalIOHandler.statusBar(
            StatusLine(locationName: "A Very Long Room Name Indeed", score: 999, moves: 999),
            cols: 20)
        #expect(DisplayWidth.columns(of: bar) <= 20)
    }

    @Test("A wide name never clips to more columns than the width allows")
    func clipsWideNameByColumn() {
        let bar = TerminalIOHandler.statusBar(
            StatusLine(locationName: "西の家西の家西の家西の家", score: 999, moves: 999),
            cols: 10)
        #expect(DisplayWidth.columns(of: bar) <= 10)
    }

    @Test("A nil status yields a blank, full-width bar")
    func nilStatusIsBlank() {
        let bar = TerminalIOHandler.statusBar(nil, cols: 30)
        #expect(DisplayWidth.columns(of: bar) == 30)
        #expect(bar.allSatisfy { $0 == " " })
    }
}
