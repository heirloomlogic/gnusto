import Darwin
import Gnusto

do {
    let world = try GameWorld(game: OperaHouse())
    await REPL(world: world, io: ConsoleIOHandler()).run()
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
