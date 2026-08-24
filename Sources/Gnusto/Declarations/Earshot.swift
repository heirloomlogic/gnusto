/// The neighbourhood a sound carries to: the rooms a sentence about something
/// *heard* is true in, named once and used wherever that sound is reported.
///
/// ``say(_:from:)-(String,Location...)`` settles a sentence whose subject is one
/// room or one thing. A **noise** is neither: an explosion, a rockfall, a
/// telephone, a knock at a door is audible across some neighbourhood and
/// inaudible outside it, and the neighbourhood is usually the same one for every
/// line about that source. `Earshot` is that list, given a name and written once
/// per source rather than once per line:
///
/// ```swift
/// /// Everywhere inside the volcano hears what happens inside the volcano.
/// var insideTheVolcano: Earshot {
///     Earshot(shaft + [narrowLedge, library, volcanoView, wideLedge, dustyRoom])
/// }
///
/// fuse("dustyRoomFalls", after: 5) {
///     dustyRoomWrecked = true                              // the world moves…
///     say(Prose.ominousRumbling, from: insideTheVolcano)   // …the telling does not
/// }
/// ```
///
/// It is a list and never a computed radius, and darkness does not gate it. The
/// argument for both, and for ``contains(_:)``, is in
/// <doc:DarknessTimeAndDeath>, under *Say it only where it is true*.
public struct Earshot: Sendable {
    /// The rooms the sound reaches.
    let rooms: [Location]

    /// Names the rooms a sound is heard in.
    ///
    /// - Parameter rooms: every room the sound reaches, the room it happens in
    ///   included.
    public init(_ rooms: Location...) {
        self.rooms = rooms
    }

    /// Names the rooms a sound is heard in, from a list already in hand — a
    /// region's own roster of rooms, plus the few that are not on it.
    ///
    /// - Parameter rooms: every room the sound reaches, the room it happens in
    ///   included.
    public init(_ rooms: [Location]) {
        self.rooms = rooms
    }

    /// Whether a room is inside this neighbourhood.
    ///
    /// The gate ``say(_:from:)-(String,Earshot)`` applies, exposed for a body
    /// that has to ask before it speaks — one that would otherwise draw
    /// randomness, move state, or start a fuse on the strength of a line nobody
    /// is there to read.
    ///
    /// - Parameter room: the room to test, usually `player.location`.
    /// - Returns: true when the sound reaches that room.
    public func contains(_ room: Location) -> Bool {
        rooms.contains(room)
    }
}
