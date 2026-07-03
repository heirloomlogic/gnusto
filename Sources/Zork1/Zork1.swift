import Gnusto
import GnustoDangerousDark

/// *Zork I: The Great Underground Empire* — the White House slice. Composes
/// the above-ground region (``ZorkAboveGround``), the house interior
/// (``ZorkHouse``), and the cellar region (``ZorkCellar``), and wires the
/// exits that cross between them: the kitchen window, the cellar's south
/// crawlway, and the studio's chimney. Everything else about each region is
/// that region's own concern; the host only owns what genuinely spans two.
@main
struct Zork1: Game, GameMain {
    let title = "Zork I: The Great Underground Empire"
    let tagline = "A placeholder slice: the White House, its grounds, and the cellar."
    let intro = """
        An adventure awaits amid a ruined empire buried underground. This
        slice covers only the White House, its immediate surroundings, and
        the first rooms below.
        """

    let aboveGround = ZorkAboveGround()
    let house = ZorkHouse()
    let cellar = ZorkCellar()

    /// The grue. Zork's prose, the plugin's stock warn-then-kill schedule.
    let dangerousDark = DangerousDark(
        warning: Prose.grueWarning,
        death: Prose.grueDeath
    )

    var content: GameContents {
        aboveGround
        house
        cellar
        dangerousDark
    }

    var map: WorldMap {
        // The one exit that crosses the ZorkAboveGround/ZorkHouse boundary:
        // the kitchen window. Starts closed — the "open window, enter west"
        // transcript exercises exactly this door.
        aboveGround.behindHouse.west(house.kitchen, via: house.window)
        house.kitchen.east(aboveGround.behindHouse, via: house.window)

        // Where ZorkHouse meets ZorkCellar: the crawlway south of the
        // cellar, and the chimney — climbable only from below, so no
        // matching `kitchen.down` (FIDELITY.md).
        house.cellar.south(cellar.eastOfChasm)
        cellar.eastOfChasm.north(house.cellar)
        cellar.studio.up(house.kitchen)

        player.starts(in: aboveGround.westOfHouse)
    }
}
