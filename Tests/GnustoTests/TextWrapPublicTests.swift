import Gnusto
import Testing

/// ``TextWrap/isPreformatted(_:)`` through the public API only: `Gnusto` is
/// imported without `@testable`, so this file compiles only while a front end
/// can call it.
struct TextWrapPublicTests {
    @Test(
        "Two spaces or a tab is a form, one space, none or a blank line is not, and wrap() agrees",
        arguments: [
            ("  two spaces", true), ("\ttab", true), ("   three", true),
            (" one space", false), ("none", false), ("  ", false), ("\t", false),
        ])
    func classifiesTheWayWrapDoes(line: String, isForm: Bool) {
        #expect(TextWrap.isPreformatted(line) == isForm)
        // wrap() puts a form on its own line under the prose, folds a prose
        // line into it, and drops a blank line at the end of the text.
        #expect((TextWrap.wrap("above\n\(line)", width: 80).count == 2) == isForm)
    }
}
