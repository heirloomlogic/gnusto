extension Item {
    /// Declares named scenery that the player can examine but cannot take.
    ///
    /// Store the result on a game or content bundle and place it in `map`, as
    /// with any other item. Its name and synonyms use the usual parser rules.
    /// Additional traits can make it a container, surface, or other fixture.
    ///
    /// ```swift
    /// let wall = Item.backdrop("stone wall", synonyms: ["masonry"],
    ///                          description: "Mortar fills the cracks.")
    /// let niche = Item.backdrop("shadowed niche") { container }
    /// ```
    ///
    /// - Parameters:
    ///   - name: the item's display name.
    ///   - adjectives: additional words accepted before the item's noun.
    ///   - synonyms: alternative noun phrases for the item.
    ///   - description: optional examine text; omit it when using a `describe` rule.
    ///   - traits: additional item traits.
    /// - Returns: an ordinary item with the `scenery` trait.
    public static func backdrop(
        _ name: String,
        adjectives: [String] = [],
        synonyms: [String] = [],
        description: String? = nil,
        @ItemBuilder _ traits: () -> [ItemTrait] = { [] }
    ) -> Item {
        Item {
            ItemTrait(kind: .name(name))
            if !adjectives.isEmpty {
                ItemTrait(kind: .adjectives(adjectives))
            }
            if !synonyms.isEmpty {
                ItemTrait(kind: .synonyms(synonyms))
            }
            if let description {
                ItemTrait(kind: .description(description))
            }
            scenery
            for trait in traits() {
                trait
            }
        }
    }
}
