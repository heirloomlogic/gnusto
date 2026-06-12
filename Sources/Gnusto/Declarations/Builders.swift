/// The one array-collecting result builder behind every Gnusto block.
/// `Location { … }`, `Item { … }`, `map`, and `rules` all use instantiations
/// of this builder, so capabilities (optionals, conditionals, loops) can't
/// drift between them.
@resultBuilder
public enum GnustoBuilder<Element> {
    public static func buildExpression(_ element: Element) -> [Element] {
        [element]
    }

    public static func buildBlock(_ parts: [Element]...) -> [Element] {
        parts.flatMap(\.self)
    }

    public static func buildOptional(_ parts: [Element]?) -> [Element] {
        parts ?? []
    }

    public static func buildEither(first parts: [Element]) -> [Element] {
        parts
    }

    public static func buildEither(second parts: [Element]) -> [Element] {
        parts
    }

    public static func buildArray(_ parts: [[Element]]) -> [Element] {
        parts.flatMap(\.self)
    }

    public static func buildFinalResult(_ parts: [Element]) -> [Element] {
        parts
    }
}

public typealias LocationBuilder = GnustoBuilder<LocationTrait>
public typealias ItemBuilder = GnustoBuilder<ItemTrait>
public typealias RuleBuilder = GnustoBuilder<Rule>
public typealias MapBuilder = GnustoBuilder<MapEntry>

extension GnustoBuilder where Element == Rule {
    /// Lets `rules` blocks compose: `var rules: Rules { cloakRules; barRules }`.
    public static func buildExpression(_ rules: Rules) -> [Rule] {
        rules.rules
    }

    public static func buildFinalResult(_ rules: [Rule]) -> Rules {
        Rules(rules: rules)
    }
}

extension GnustoBuilder where Element == MapEntry {
    /// Lets `map` blocks compose from sub-maps.
    public static func buildExpression(_ map: WorldMap) -> [MapEntry] {
        map.entries
    }

    public static func buildFinalResult(_ entries: [MapEntry]) -> WorldMap {
        WorldMap(entries: entries)
    }
}
