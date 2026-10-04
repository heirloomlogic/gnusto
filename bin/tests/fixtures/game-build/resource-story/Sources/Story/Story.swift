import Foundation
import Gnusto

public let game = PackagedGame { Story() }

struct Story: Game {
    let title = "Packaging Graph Story"
    var intro: String {
        let url = Bundle.module.url(forResource: "opening", withExtension: "txt")!
        return "BuildSourceOne " + (try! String(contentsOf: url, encoding: .utf8))
    }
    let room = Location {
        name("Fixture Room")
        description("A quiet room.")
    }
    var map: WorldMap { player.starts(in: room) }
}
