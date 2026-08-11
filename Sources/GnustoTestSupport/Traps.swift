// `ExitTest` does not exist where Swift Testing is built without exit tests, so
// this file cannot compile there. Which platforms those are, and why the list is
// an allowlist, is stated once in `Package.swift`.
#if GNUSTO_EXIT_TESTS

import Testing

/// Checks the message a deliberately-crashed game printed on its way out.
///
/// The engine answers an authoring mistake with a `fatalError` naming the
/// mistake — a `describe { }` closure that calls back into the describer
/// running it, `proceed()` from an `after` rule, `startFuse` naming a daemon.
/// A `fatalError` cannot be caught, so the only way to assert on one is to run
/// it in a child process and read what it printed. Swift Testing's exit tests
/// do the running; this does the reading:
///
/// ```swift
/// let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
///     _ = try await play(ProceedMisuseGame(), ["take wrench"])
/// }
/// expectTrap(result, says: "proceed() was called twice")
/// ```
///
/// A trap test fails in two very different ways and the message says which:
/// **nothing on stderr** means the process died before it could print, and
/// **a different message** means the trap fired with the wrong wording.
///
/// **What it costs, and when to spend it.** Each call is a child process — some
/// 60 ms, against 1 ms for an in-process assertion. This is the decision point,
/// so the rule lives here and `TestingYourGame.md` points at it. A trap wants
/// one of three shapes, in the order they are worth reaching for; only the last
/// of them is this function:
///
/// 1. **Make the bad message unrepresentable, and write no test at all.** Where
///    a group of traps shares a sentence, fold them into one helper that derives
///    the whole of it — or at least takes the missing half as a *required*
///    argument — so the next call site cannot omit or contradict it. Where a
///    trap guards an argument no caller could sensibly mean, change the
///    signature so the compiler refuses it. `HolderTrait` and
///    `declaredFuse(_:in:else:)` are the first; `oneOf(_:_:)` is the second.
/// 2. **A pure function, asserted in process**, for an ordinary precondition, or
///    one whose message has branches worth checking apiece. Split the message
///    out and test it at a millisecond — the shape `Reentry.diagnostic(depth:entity:)`
///    and `TraitKey.diagnostic(for:of:)` use.
/// 3. **An exit test** — this function — where the trap's *wording* is what an
///    author will read to find their mistake and no pure function can stand in
///    for the run, or where a *margin* only a real run can measure is at stake.
///    An entity built inside a rule body; `command` read on the opening look; a
///    scoring register the award table does not list; a cap that has to fire
///    before the stack does.
///
/// - Parameters:
///   - result: the exit test's result — the value `#expect(processExitsWith:)`
///     returns, which must have been asked to observe `standardErrorContent`.
///   - needles: the fragments the trap's message must contain, in any order.
///   - sourceLocation: the caller's source location, for issue reporting.
public func expectTrap(
    _ result: ExitTest.Result?,
    says needles: String...,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    guard let result else {
        // The macro already recorded why the exit condition didn't match; this
        // says what was being looked for, which that message can't know.
        Issue.record(
            """
            The exit test produced no result, so the trap's message could not be \
            read. Expected it to say: \(needles.joined(separator: ", ")).
            """,
            sourceLocation: sourceLocation)
        return
    }

    let stderr = String(decoding: result.standardErrorContent, as: UTF8.self)
    guard !stderr.isEmpty else {
        Issue.record(
            """
            The process died without printing anything, so no trap was reached. \
            Exit status: \(result.exitStatus). Expected a trap saying: \
            \(needles.joined(separator: ", ")).
            """,
            sourceLocation: sourceLocation)
        return
    }

    // One issue for all the misses rather than one apiece: a wholly wrong
    // message misses every needle, and printing the whole of stderr once per
    // miss buries the thing you need to read.
    let missing = needles.filter { !stderr.contains($0) }
    guard missing.isEmpty else {
        Issue.record(
            """
            The process trapped, but its message did not say \
            \(missing.map { "\"\($0)\"" }.joined(separator: ", ")).
            Standard error:
            \(stderr)
            """,
            sourceLocation: sourceLocation)
        return
    }
}

#endif
