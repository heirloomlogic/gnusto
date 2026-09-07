extension Item {
    /// Declares named scenery that the player can examine but cannot take.
    ///
    /// Store the result on a game or content bundle and place it in `map`, as
    /// with any other item. Its name and synonyms use the usual parser rules.
    /// Additional traits can make it a container, surface, or other fixture.
    ///
    /// ```swift
    /// let wall = Item.scenery("stone wall", synonyms: "masonry",
    ///                         description: "Mortar fills the cracks.")
    /// let niche = Item.scenery("shadowed niche") { container }
    /// ```
    ///
    /// The traits are spelled `ItemTrait(kind:)` rather than through the
    /// `name(_:)` / `adjectives(_:)` / `synonyms(_:)` directives because two of
    /// them cannot be reached from here: the directives are variadic and Swift
    /// has no splat, and inside `extension Item` the bare `scenery` resolves to
    /// this function rather than to the trait.
    ///
    /// - Parameters:
    ///   - name: the item's display name.
    ///   - adjectives: additional words accepted before the item's noun.
    ///   - synonyms: alternative noun phrases for the item.
    ///   - description: optional examine text; omit it when using a `describe` rule.
    ///   - traits: additional item traits.
    /// - Returns: an ordinary item with the `scenery` trait.
    public static func scenery(
        _ name: String,
        adjectives: String...,
        synonyms: String...,
        description: String? = nil,
        @ItemBuilder _ traits: () -> [ItemTrait] = { [] }
    ) -> Item {
        Item {
            ItemTrait(kind: .name(name))
            ItemTrait(kind: .adjectives(adjectives))
            ItemTrait(kind: .synonyms(synonyms))
            if let description {
                ItemTrait(kind: .description(description))
            }
            ItemTrait(kind: .scenery)
            for trait in traits() {
                trait
            }
        }
    }
}
