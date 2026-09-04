/// The status footer's contributed fields, which are a question for the world
/// rather than for the footer: see ``StatusFooter`` for what is done with them.
///
/// Not in `Playtest/`, where the rest of the footer's machinery used to sit.
/// `REPL` asks for these on the ordinary playing path, so a build without the
/// `Playtest` trait needs them.
extension GameWorld {
    /// The extra status-footer fields the game's bundles and plugins
    /// contribute, evaluated now.
    ///
    /// A field reads live state — `Clock`'s hour is a function of the `moves`
    /// counter — so it needs a turn frame, and there is none between turns.
    /// This builds a throwaway one exactly as `begin()` does, and then
    /// **discards** it rather than committing: the scratch's writes go nowhere,
    /// which is the read-only contract stated on `GameContent.statusFields`
    /// made literal. The caller only asks when a footer is in force, so a game
    /// nobody is play-testing never runs an author's closure at all.
    ///
    /// **Which world it reads.** Not the live one, when the last turn cost a
    /// move: the frame is built over the world as that turn stood at its
    /// *close* — after its each-turn rules and its timer tick, before its
    /// counter advanced — which is the instant every word the turn printed was
    /// written at. So `time=` names the minute of the prose above it, while
    /// the `moves=` beside it names the count the turn left behind. The two
    /// are sampled at different instants deliberately; see
    /// ``Scratch/statusFieldState`` and issue #280. A turn that advanced no
    /// counter has no such instant and falls back to live state, which for
    /// that turn is the same world.
    ///
    /// **What the empty check does not mean.** It is not "this game
    /// contributes nothing": `Bootstrap` collects one closure per content
    /// module whether or not the module overrides the protocol's default, so
    /// any game with a bundle gets past this guard and pays for a scratch
    /// frame whose `flatMap` then returns nothing. Only a game with no
    /// bundles and no stored plugin returns here.
    ///
    /// - Returns: the contributed `name`/`value` pairs, in declaration order.
    func statusFields() -> [(String, String)] {
        guard !definition.statusFields.isEmpty else { return [] }
        let scratch = TurnFrame(definition: definition, state: statusFieldState ?? state)
        let fields = Ctx.$frame.withValue(scratch) {
            definition.statusFields.flatMap { $0() }
        }
        _ = scratch.retire()  // discard: a status field is read-only by contract
        return fields
    }
}
