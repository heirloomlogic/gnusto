import Gnusto

/// The Endgame's exit table and its placements.
///
/// **Why the declared counts are short of the atlas's.** Every row
/// `docs/games/dungeon-atlas.md` marks `conditional (FROBOZZ)` is the
/// mainframe's idiom for "the room function owns this direction" — the same
/// idiom `FCHMP` is in the Royal Puzzle, a `CEXIT` on a flag nothing ever sets.
/// Those directions are ``DungeonEndgame/hallwayRules`` and are not exits here,
/// exactly as `CP`'s nine are not. What is declared below is every row the
/// atlas records as **plain**, **door** or **conditional (`MIRROR-OPEN`)**.
///
/// Split into five sub-builders because thirty-two rooms' worth of exits do not
/// read as one list. See ``DungeonEndgame``.
extension DungeonEndgame {
    @MapBuilder var map: WorldMap {
        tombMap
        hallwayMap
        prisonMap
        endgamePlacements
        boxPlacements
    }

    /// The Tomb, the Crypt, the stairs and the two rooms below them.
    @MapBuilder var tombMap: WorldMap {
        tomb.north(crypt, via: cryptDoor)
        tomb.in(crypt, via: cryptDoor)
        crypt.south(tomb, via: cryptDoor)
        crypt.out(tomb, via: cryptDoor)

        topOfStairs.north(stoneRoom)
        topOfStairs.down(stoneRoom)

        stoneRoom.south(topOfStairs)
        stoneRoom.up(topOfStairs)
        stoneRoom.north(smallRoom)

        smallRoom.south(stoneRoom)
    }

    /// The hallway's plain rows. The narrow rooms flanking `MRD` and `MRG` get
    /// none, which is the nought the atlas records: a player who reaches one is
    /// already dead.
    @MapBuilder var hallwayMap: WorldMap {
        hallwayA.south(smallRoom)

        narrowAEast.north(hallwayB)
        narrowAEast.south(smallRoom)
        narrowAWest.north(hallwayB)
        narrowAWest.south(smallRoom)

        narrowBEast.north(hallwayC)
        narrowBEast.south(hallwayA)
        narrowBWest.north(hallwayC)
        narrowBWest.south(hallwayA)

        narrowCEast.north(hallwayG)
        narrowCEast.south(hallwayB)
        narrowCWest.north(hallwayG)
        narrowCWest.south(hallwayB)

        hallwayD.north(dungeonEntrance)
        hallwayD.northeast(dungeonEntrance)
        hallwayD.northwest(dungeonEntrance)
    }

    /// The wooden door, the four corridors, the parapet and the cells.
    @MapBuilder var prisonMap: WorldMap {
        dungeonEntrance.north(narrowCorridor, via: woodenDoor)
        dungeonEntrance.in(narrowCorridor, via: woodenDoor)
        narrowCorridor.south(dungeonEntrance, via: woodenDoor)
        narrowCorridor.north(southCorridor)

        southCorridor.south(narrowCorridor)
        southCorridor.west(westCorridor)
        southCorridor.east(eastCorridor)
        southCorridor.north(prisonCell, via: bronzeDoor)

        northCorridor.east(eastCorridor)
        northCorridor.west(westCorridor)
        northCorridor.north(parapet)
        northCorridor.south(prisonCell, via: cellDoor)
        northCorridor.in(prisonCell, via: cellDoor)

        eastCorridor.north(northCorridor)
        eastCorridor.south(southCorridor)
        westCorridor.north(northCorridor)
        westCorridor.south(southCorridor)

        parapet.south(northCorridor)

        prisonCell.out(northCorridor, via: cellDoor)
        prisonCell.north(northCorridor, via: cellDoor)
        prisonCell.south(southCorridor, via: bronzeDoor)

        winningCell.out(treasury, via: bronzeDoor)
        winningCell.north(treasury, via: bronzeDoor)
    }

    /// Where everything starts. The player does not start here — the crypt's
    /// transition is the only way in.
    @MapBuilder var endgamePlacements: WorldMap {
        cryptDoor.starts(in: tomb)
        heads.starts(in: tomb)
        cokeBottles.starts(in: tomb)
        listings.starts(in: tomb)

        redBeam.starts(in: smallRoom)
        redButton.starts(in: stoneRoom)
        stairsAtTheTop.starts(in: topOfStairs)
        stairsAtTheBottom.starts(in: stoneRoom)
        stairsToTheParapet.starts(in: parapet)

        channelA.starts(in: hallwayA)
        channelB.starts(in: hallwayB)
        channelC.starts(in: hallwayC)
        channelD.starts(in: hallwayD)
        channelInside.starts(in: insideMirror)

        guardians.starts(in: hallwayC)

        for (box, room) in boxesSeenFromOutside { box.starts(in: room) }

        woodenDoor.starts(in: dungeonEntrance)
        dungeonMaster.starts(in: narrowCorridor)
    }

    /// The box's own furniture, all of it inside the one room that is the
    /// inside of the box, and the prison's.
    @MapBuilder var boxPlacements: WorldMap {
        mahoganyEnd.starts(in: insideMirror)
        pineEnd.starts(in: insideMirror)
        mirrorOne.starts(in: insideMirror)
        mirrorTwo.starts(in: insideMirror)
        redPanel.starts(in: insideMirror)
        yellowPanel.starts(in: insideMirror)
        whitePanel.starts(in: insideMirror)
        blackPanel.starts(in: insideMirror)
        pole.starts(in: insideMirror)
        tBar.starts(in: insideMirror)
        woodenBar.starts(in: insideMirror)
        compassArrow.starts(in: insideMirror)

        southSlot.starts(in: southCorridor)
        northSlot.starts(in: northCorridor)
        cellDoor.starts(in: northCorridor)
        bronzeDoor.starts(in: southCorridor)
        lockedCellDoor.starts(in: winningCell)
        greatPit.starts(in: parapet)
        sundial.starts(in: parapet)
        parapetButton.starts(in: parapet)
        for numeral in numerals { numeral.starts(in: parapet) }

        hoard.starts(in: treasury)
    }

    /// The box as it is seen from each of the nine rooms it can be seen from —
    /// every hallway and narrow room a living player can stand in.
    var boxesSeenFromOutside: [(Item, Location)] {
        [
            (boxSeenFromA, hallwayA), (boxSeenFromB, hallwayB),
            (boxSeenFromC, hallwayC),
            (boxSeenFromAEast, narrowAEast), (boxSeenFromAWest, narrowAWest),
            (boxSeenFromBEast, narrowBEast), (boxSeenFromBWest, narrowBWest),
            (boxSeenFromCEast, narrowCEast), (boxSeenFromCWest, narrowCWest),
        ]
    }
}
