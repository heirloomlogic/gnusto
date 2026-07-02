import Gnusto

/// *Zork I: The Great Underground Empire* — the White House slice. Composes
/// the above-ground region (``ZorkAboveGround``) and the house interior
/// (``ZorkHouse``), and wires the one exit that crosses between them: the
/// kitchen window. Everything else about each region is that region's own
/// concern; the host only owns what genuinely spans both.
@main
struct Zork1: Game, GameMain {
    let title = "Zork I: The Great Underground Empire"
    let tagline = "A placeholder slice: the White House and its grounds."
    let intro = """
        An adventure awaits amid a ruined empire buried underground. This
        slice covers only the White House and its immediate surroundings.
        """

    let aboveGround = ZorkAboveGround()
    let house = ZorkHouse()

    var content: GameContents {
        aboveGround
        house
    }

    var map: WorldMap {
        // The one exit that crosses the bundle boundary: the kitchen window,
        // between `ZorkAboveGround.behindHouse` and `ZorkHouse.kitchen`.
        // Starts closed — the brief's "open window, enter west" transcript
        // exercises exactly this door.
        aboveGround.behindHouse.west(house.kitchen, via: house.window)
        house.kitchen.east(aboveGround.behindHouse, via: house.window)

        player.starts(in: aboveGround.westOfHouse)
    }
}
