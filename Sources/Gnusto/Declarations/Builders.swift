/// The one array-collecting result builder behind every Gnusto block.
/// `Location { … }`, `Item { … }`, `map`, and `rules` all use instantiations
/// of this builder, so capabilities (optionals, conditionals, loops) can't
/// drift between them.
@resultBuilder
public enum GnustoBuilder<Element> {
    /// Wraps a single element into a one-element block.
    public static func buildExpression(_ element: Element) -> [Element] {
        [element]
    }

    /// Concatenates the blocks in a builder body.
    public static func buildBlock(_ parts: [Element]...) -> [Element] {
        parts.flatMap(\.self)
    }

    /// Yields the elements of an `if` without `else`, or an empty block.
    public static func buildOptional(_ parts: [Element]?) -> [Element] {
        parts ?? []
    }

    /// Yields the elements from the first branch of an `if`/`else`.
    public static func buildEither(first parts: [Element]) -> [Element] {
        parts
    }

    /// Yields the elements from the second branch of an `if`/`else`.
    public static func buildEither(second parts: [Element]) -> [Element] {
        parts
    }

    /// Flattens the per-iteration blocks of a `for` loop.
    public static func buildArray(_ parts: [[Element]]) -> [Element] {
        parts.flatMap(\.self)
    }

    /// Returns the collected elements unchanged.
    public static func buildFinalResult(_ parts: [Element]) -> [Element] {
        parts
    }
}

/// The result builder for `Location { … }` trait blocks.
public typealias LocationBuilder = GnustoBuilder<LocationTrait>
/// The result builder for `Item { … }` trait blocks.
public typealias ItemBuilder = GnustoBuilder<ItemTrait>
/// The result builder for `rules` blocks.
public typealias RuleBuilder = GnustoBuilder<Rule>
/// The result builder for `map` blocks.
public typealias MapBuilder = GnustoBuilder<MapEntry>
/// The result builder for `verbs` blocks.
public typealias VerbBuilder = GnustoBuilder<SyntaxRule>
/// The result builder for `content` blocks.
public typealias ContentBuilder = GnustoBuilder<any GameContent>
/// The result builder for `timers` blocks.
public typealias TimerBuilder = GnustoBuilder<TimedEvent>

extension GnustoBuilder where Element == Rule {
    /// Lets `rules` blocks compose: `var rules: Rules { cloakRules; barRules }`.
    public static func buildExpression(_ rules: Rules) -> [Rule] {
        rules.rules
    }

    /// Packages the collected rules into a `Rules` value.
    public static func buildFinalResult(_ rules: [Rule]) -> Rules {
        Rules(rules: rules)
    }
}

extension GnustoBuilder where Element == SyntaxRule {
    /// Lets `verbs` blocks splice a whole table at once — e.g. a plugin's
    /// `combat.verbs` — alongside individual `SyntaxRule` rows.
    public static func buildExpression(_ table: [SyntaxRule]) -> [SyntaxRule] {
        table
    }

    /// Lets a `verbs` block list a `#verb`-declared intent — `.ring` — and
    /// splice the rows the intent carries.
    public static func buildExpression(_ intent: Intent) -> [SyntaxRule] {
        intent.syntax
    }

    /// Lets a `verbs` block list several `#verb`-declared intents at once —
    /// `[.ring, .polish, .sing]`. The array form isn't just taste: bare
    /// leading-dot statements on consecutive lines parse as one chained
    /// member access (`.ring.polish`), so multiple intents need either this
    /// or an `Intent.` prefix per line.
    public static func buildExpression(_ intents: [Intent]) -> [SyntaxRule] {
        intents.flatMap(\.syntax)
    }
}

extension GnustoBuilder where Element == IntentAction {
    /// Lets `actions` blocks splice a whole table at once — e.g. a plugin's
    /// `combat.actions` — alongside individual `IntentAction` rows.
    public static func buildExpression(_ table: [IntentAction]) -> [IntentAction] {
        table
    }
}

extension GnustoBuilder where Element == TimedEvent {
    /// Lets `timers` blocks splice a whole table at once — e.g. a plugin's
    /// `combat.timers` — alongside individual `fuse`/`daemon` rows.
    public static func buildExpression(_ table: [TimedEvent]) -> [TimedEvent] {
        table
    }
}

extension GnustoBuilder where Element == MapEntry {
    /// Lets `map` blocks compose from sub-maps.
    public static func buildExpression(_ map: WorldMap) -> [MapEntry] {
        map.entries
    }

    /// Packages the collected entries into a `WorldMap` value.
    public static func buildFinalResult(_ entries: [MapEntry]) -> WorldMap {
        WorldMap(entries: entries)
    }
}

extension GnustoBuilder where Element == any GameContent {
    /// Packages the collected bundles into a `GameContents` value.
    public static func buildFinalResult(_ modules: [any GameContent]) -> GameContents {
        GameContents(modules: modules)
    }
}
