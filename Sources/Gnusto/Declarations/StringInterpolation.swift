extension DefaultStringInterpolation {
    /// Warns when an entity proxy is interpolated instead of its prose name.
    /// Swift skips unavailable overloads, so this must remain callable to diagnose
    /// the interpolation. Preserve the standard library's output if it is used.
    @available(*, deprecated, message: "use item.definiteName or item.indefiniteName")
    public mutating func appendInterpolation(_ item: Item) {
        appendLiteral(String(describing: item))
    }

    /// Use the actor's name with an explicit article form in prose.
    @available(*, deprecated, message: "use actor.definiteName or actor.indefiniteName")
    public mutating func appendInterpolation(_ actor: Actor) {
        appendLiteral(String(describing: actor))
    }

    /// Locations have no article forms; their authored display name is `name`.
    @available(*, deprecated, message: "use location.name")
    public mutating func appendInterpolation(_ location: Location) {
        appendLiteral(String(describing: location))
    }
}
