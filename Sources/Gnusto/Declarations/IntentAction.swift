/// A replacement or new stage-4 default action for one intent — the seam
/// that lets a game or plugin give a custom verb real behavior instead of
/// "I didn't understand", or replace a built-in's default entirely.
///
/// Declared through the `action(_:perform:)` factory and collected in a
/// game's, bundle's, or plugin's `actions` block, exactly like `verbs`:
///
/// ```swift
/// var actions: [IntentAction] {
///     action(Intent("ring")) {
///         say("The bell chimes sweetly.")
///     }
/// }
/// ```
///
/// An override runs at stage 4 exactly like a built-in: before rules have
/// already run, after rules still run, and `refuse`/`reply` inside it behave
/// identically to inside a built-in.
public struct IntentAction: Sendable {
    let intent: Intent
    let body: @Sendable () throws -> Void

    /// Builds a stage-4 default action for `intent`. A row whose intent
    /// matches a built-in reclaims it (last-wins, with a non-fatal warning);
    /// a row whose intent matches no built-in gives that custom intent
    /// default behavior for the first time.
    ///
    /// - Parameters:
    ///   - intent: the intent this action handles.
    ///   - body: the action's behavior.
    public init(_ intent: Intent, perform body: @escaping @Sendable () throws -> Void) {
        self.intent = intent
        self.body = body
    }
}

/// Builds a stage-4 default action for `intent` — shorthand for
/// `IntentAction(_:perform:)` that reads naturally in an `actions` block.
///
/// - Parameters:
///   - intent: the intent this action handles.
///   - body: the action's behavior.
/// - Returns: the intent action.
public func action(
    _ intent: Intent,
    perform body: @escaping @Sendable () throws -> Void
) -> IntentAction {
    IntentAction(intent, perform: body)
}

/// The result builder for `actions` blocks.
public typealias ActionBuilder = GnustoBuilder<IntentAction>
