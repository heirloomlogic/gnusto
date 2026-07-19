import Gnusto

/// How a spell becomes available to cast, and what casting it costs — the axis
/// that lets one spellcasting system express the common RPG magic paradigms
/// without changing how a spell's *effect* is written.
///
/// A spell's identity is always its own `Intent` (declared with `#verb`, like a
/// magic word); `SpellCost` is layered on top to decide availability and cost:
///
/// - ``cantrip`` — an at-will spell: always castable, free, never used up.
/// - ``prepared(book:)`` — a memorized ("Vancian") spell: it must be committed
///   to a finite memory first (from a spellbook, or freely when `book` is nil)
///   and is spent when cast, so it must be re-memorized to cast again.
/// - ``energy(_:)`` — a points-based spell: casting draws from a shared magical
///   energy pool that `rest` refills.
/// - ``scroll(_:)`` — a one-shot spell read from a scroll item, which is
///   consumed by the casting.
public enum SpellCost: Sendable {
    /// Always castable, free, never consumed.
    case cantrip

    /// Must be memorized into the caster's finite spell memory before casting,
    /// and is spent on cast. `learnVia` is the memorize/learn intent that
    /// commits it to memory. When `book` is set, memorizing requires that
    /// spellbook be in hand; when nil, the spell can be memorized anywhere.
    case prepared(book: Item?, learnVia: Intent)

    /// Draws the given amount from the shared magical-energy pool; refused when
    /// the pool is too low. `rest` restores the pool to full.
    case energy(Int)

    /// Read from the given scroll item, which is consumed when the spell is
    /// cast. Refused unless the scroll is in hand.
    case scroll(Item)
}
