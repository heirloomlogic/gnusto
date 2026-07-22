/// The outer loop: prompt → parse → perform → print, until the game ends or
/// input runs out. Holds the only `await` in a Gnusto game.
public struct REPL: Sendable {
    private let world: GameWorld
    private let io: any IOHandler

    /// Creates a REPL driving the given world through the given IO handler.
    ///
    /// - Parameters:
    ///   - world: the world to drive.
    ///   - io: the IO handler for input and output.
    public init(world: GameWorld, io: any IOHandler) {
        self.world = world
        self.io = io
    }

    /// Runs the prompt/parse/perform/print loop until the game ends.
    public func run() async {
        var result = await world.begin()
        io.write("\(result.output)\n\n")
        io.showStatus(result.status)
        io.updateCompletions(await world.completionCandidates())

        while !result.isFinished, let input = io.readLine(prompt: "> ") {
            switch input {
            case .line(let line): result = await world.perform(line)
            case .quit: result = await world.requestQuit()
            }
            io.write("\(result.output)\n\n")
            io.showStatus(result.status)
            io.updateCompletions(await world.completionCandidates())
        }

        // A reached ending (won/lost/quit) gets a final hand-off so a
        // full-screen front end can keep its last words visible; a bare
        // end-of-input (EOF) just stops.
        if result.isFinished {
            io.finish(result.output)
        }
    }
}
