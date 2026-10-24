import Gnusto
import Testing

/// ``TextWrap/isPreformatted(_:)`` through the public API only: `Gnusto` is
/// imported without `@testable`, so this file compiles only while a front end
/// can call it.
struct TextWrapPublicTests {
    @Test(
        "Two spaces or a tab is a form, one space or none is prose, and wrap() agrees",
        arguments: [
            ("  two spaces", true), ("\ttab", true), ("   three", true),
            (" one space", false), ("none", false),
        ])
    func classifiesTheWayWrapDoes(line: String, isForm: Bool) {
        #expect(TextWrap.isPreformatted(line) == isForm)
        // A form never folds into the prose above it; anything else does.
        #expect((TextWrap.wrap("above\n\(line)", width: 80).count == 2) == isForm)
    }
}
