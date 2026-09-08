extension Player {
    /// Strews everything in the player's hands across `rooms`, one random draw
    /// per item — the classic resurrection scatter, for a ``Game/onDeath()``
    /// that lets the player live and makes them go looking for their things.
    ///
    /// An item listed in `except` goes to the room named for it instead, every
    /// time. Zork keeps the lantern in the living room so a death never costs
    /// the light — a deliberate anti-softlock — and that is what the list is
    /// for.
    ///
    /// ```swift
    /// func onDeath() -> DeathOutcome {
    ///     deaths += 1
    ///     guard deaths < 3 else { return .fallThrough }
    ///     scoring.penalize(10)
    ///     player.scatterInventory(across: forestRooms, except: [lantern: livingRoom])
    ///     player.location = forest
    ///     say(Prose.resurrection)
    ///     describeSurroundings()
    ///     return .consumed
    /// }
    /// ```
    ///
    /// Walks the inventory in its stable order, so only the destinations draw
    /// from the seeded stream, never the order they are drawn in.
    ///
    /// - Parameters:
    ///   - rooms: where the belongings may land. One draw per item.
    ///   - kept: items that always land in one particular room.
    public func scatterInventory(
        across rooms: [Location],
        except kept: KeyValuePairs<Item, Location> = [:]
    ) {
        precondition(!rooms.isEmpty, "Gnusto: scatterInventory needs at least one room to scatter into.")
        for item in inventory {
            if let home = kept.first(where: { $0.key == item })?.value {
                item.move(to: home)
            } else {
                item.move(to: rooms[random(0...(rooms.count - 1))])
            }
        }
    }
}
