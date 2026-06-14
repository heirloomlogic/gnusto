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
