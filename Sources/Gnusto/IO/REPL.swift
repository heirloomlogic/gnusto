/// The outer loop: prompt → parse → perform → print, until the game ends or
/// input runs out. Holds the only `await` in a Gnusto game.
public struct REPL: Sendable {
    private let world: GameWorld
    private let io: any IOHandler

    public init(world: GameWorld, io: any IOHandler) {
        self.world = world
        self.io = io
    }

    public func run() async {
        var result = await world.begin()
        io.write("\(result.output)\n\n")
        io.showStatus(result.status)

        while !result.isFinished, let line = io.readLine(prompt: "> ") {
            result = await world.perform(line)
            io.write("\(result.output)\n\n")
            io.showStatus(result.status)
        }
    }
}
