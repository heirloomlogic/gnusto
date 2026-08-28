/// Prose for the temple, Hades and the glacier (``DungeonTemple``): the Rocky
/// Crawl and the Dome Room's rope, the Torch Room below it, the Grail Room and
/// the Temple and Altar above it, the Egyptian Room and its coffin, the Glacier
/// Room and the Ruby Room behind it, the Engravings Cave, and the gate of Hades
/// with the Land of the Living Dead beyond.
///
/// The three-way rule, and the rule for which file a line goes in, are stated
/// once on ``Prose``.
extension Prose {
    // MARK: - Rocky Crawl

    /// Written fresh. `CRAW1` has no trilogy counterpart — Zork I cut the crawl
    /// and hung the Dome Room off the Engravings Cave instead. The three
    /// corners it names are the source's three exits.
    static let rockyCrawl = """
        This is a crawlway with a ceiling three feet above the floor, and the
        footing underneath is all loose rock. Passages open at the east, the
        west and the northwest corners.
        """

    static let rockyCrawlRubble = """
        Loose rock, shed from the ceiling over a long time, and nothing under
        it worth the barking of a shin.
        """

    // MARK: - The Dome Room

    /// Verbatim. `DOME` prints from a routine in the mainframe and so has no
    /// line to compare against, but the trilogy's room is the same room — a
    /// gallery around the rim of a dome with a railing and a drop — and its
    /// line names no exit this game does not have.
    static let domeRoom = """
        You are at the periphery of a large dome, which forms the ceiling
        of another room below. Protecting you from a precipitous drop is a
        wooden railing which circles the dome.
        """

    /// Written fresh. The mainframe reports the tied rope as a second
    /// paragraph of the room, which is where a player standing at the rim
    /// would look for it; here it is the railing's listing line, so it shows
    /// on every entry rather than only on a deliberate `look`.
    static let ropeOverTheRailing = """
        Hanging down from the railing is a rope which ends about ten feet from
        the floor below.
        """

    static let railingBare = """
        A wooden railing runs the whole way around the rim of the dome — the
        one thing between you and the room below, and stout enough to make
        something fast to.
        """

    static let railingTied = """
        A wooden railing runs the whole way around the rim of the dome. The
        rope is knotted to it, and hangs away down into the dark.
        """

    static let domeNoRope = "You cannot go down without fracturing many bones."

    static let ropeTiedToRailing = """
        The rope drops over the side and comes within ten feet of the floor.
        """

    static let ropeUntiedFromRailing = "The rope is now untied."

    /// Tying the knot that is already tied. `Prose.ropeAlreadyTied` is the coal
    /// chute's line — *"tied at the other end of it"* — and says the wrong
    /// thing about the end you are standing at. (#286)
    static let ropeAlreadyOnTheRailing = "The rope is already made fast to it."

    static let ropeNeedsRailing = """
        You would have to find something worth tying it to first.
        """

    static let ropeCarriesNothing = """
        The rope is not up to the job, and neither, come to that, is the idea.
        """

    // MARK: - The Torch Room

    /// Adapted. The trilogy's Torch Room is the same room under the same dome,
    /// so its voice and its pedestal stand; but the mainframe's `MTORC` has no
    /// down staircase — it drops to the North-South Crawlway — and it has a
    /// door west that Zork I never built. The exits are the source's.
    static let torchRoom = """
        This is a large room with a doorway on the west wall and a staircase
        descending through the floor. Above you is a large dome. Up around the
        edge of the dome (20 feet up) is a wooden railing. In the center of
        the room sits a white marble pedestal.
        """

    static let torchRoomRope = """
        A large piece of rope descends from the railing above, ending some
        five feet above your head.
        """

    static let torchNoRope = "You cannot reach the rope."

    static let marblePedestal = """
        A pedestal of white marble, worked smooth on every face, standing
        exactly where the light from above would fall on it.
        """

    static let torchRoomDoorway = """
        A doorway in the west wall, and past it a room too small to be worth
        the trouble of a door.
        """

    // MARK: - The Grail Room

    /// Written fresh. `MGRAI` has no trilogy counterpart at all — Zork I never
    /// built the Grail Room, and the temple it does build hangs off the Torch
    /// Room instead. The pedestal, the stairs and the two passages are the
    /// source's.
    static let grailRoom = """
        This is a small round chamber, bare but for a stone pedestal standing
        at its center. A flight of stairs rises from one side, and passages
        lead away east and west.
        """

    static let grailPedestal = """
        A pedestal of plain grey stone, worn shallow at the top where
        something has sat on it a very long time.
        """

    static let grailStairs = """
        A short flight of stairs, cut rather than built, climbing away toward
        the temple above.
        """

    static let grail = """
        A grail of beaten gold, its bowl dulled by centuries and its foot
        still bright where hands have held it.
        """

    static let grailFirstSight = "On the pedestal is a grail."

    // MARK: - The Temple and the Altar

    /// Adapted. The comparison buckets `TEMP1` `substantial`, and the check
    /// that bucket asks for is decisive: the trilogy's temple is the *north*
    /// end of the building, with the inscription east, granite west and a
    /// staircase down. The mainframe's is the *west* end, the inscription is on
    /// the south wall, the granite is north, and there is no staircase at all —
    /// the two ways out are the pillars west and the altar east. Voice kept,
    /// compass and staircase corrected.
    static let temple = """
        This is the west end of a large temple. On the south wall is an
        ancient inscription, probably a prayer in a long-forgotten language.
        The north wall is solid granite. The entrance at the west end of the
        room is through huge marble pillars.
        """

    /// Adapted. `TEMP2` is `substantial` for the same reason: the trilogy's
    /// altar is the south end and has a hole in the floor down to the caves.
    /// The mainframe's is the east end, and its one exit is back west.
    static let altar = """
        This is the east end of a large temple. In front of you is what
        appears to be an altar.
        """

    static let altarStone = """
        A long slab of stone, chest high, with the marks of a great deal of
        use on it and no marks at all of what it was used for.
        """

    static let marblePillars = """
        Pillars of marble, each of them thicker than you are tall, holding up
        a ceiling too dark to see.
        """

    static let graniteWall = "The north wall is solid granite here."

    /// Verbatim. The prayer on the wall is the trilogy's Commandment #12592 —
    /// the same joke, the same sin, and MIT-licensed.
    static let prayerInscription = """
        Commandment #12592

        Oh ye who go about saying unto each: "Hello sailor":
        Dost thou know the magnitude of thy sin before the gods?
        Yea, verily, thou shalt be ground between two stones.
        Shall the angry gods cast thy body into the whirlpool?
        Surely, thy eye shall be put out with a sharp stick!
        Even unto the ends of the earth shalt thou wander and
        Unto the land of the dead shalt thou be sent at last.
        Surely thou shalt repent of thy cunning.
        """

    static let blackBook = """
        A black book, bound in something that was once an animal, and open at
        a page somebody has marked.
        """

    /// Written fresh, and it has to be. `read book` outside the ceremony fell
    /// through to the default action, which printed ``blackBook`` — the cover
    /// of a book the same sentence advertises as *open at a page somebody has
    /// marked*, so the one command that asks what the page says answered with
    /// what the book looks like. Both source families give this book a read
    /// text and in both it is the commandment; this game prints the trilogy's
    /// commandment on the Temple's own wall (``prayerInscription``), so the
    /// page is written fresh rather than repeating it. (#286)
    ///
    /// **It is the words, not the recipe.** The page is what the ceremony reads
    /// aloud — it rhymes forward into ``spiritsBanished``'s "Begone, fiends!" —
    /// and it deliberately names neither the bell, nor the candles, nor the
    /// gate. A first draft of this line spelled the three steps out in order,
    /// which answered the box and turned the hardest puzzle in the game into a
    /// set of instructions. Nothing else in this game states the ritual, and
    /// this page is not the place to start.
    static let blackBookPage = """
        The marked page carries one passage, set apart from the rest by a hand
        that pressed hard enough to go through the paper:

          Commandment #12593

          Ye who are dead and will not lie down,
          Ye who are finished and will not be told so:
          The living have business beyond this place,
          And thou art not the keeper of it.
          Begone.

        The rest of the book is a great deal less specific.
        """

    static let prayerAnswered = """
        You bow your head at the altar, and the temple dissolves around you.
        When the world settles again you are standing in open forest, whatever
        you carried still in your hands.
        """

    // MARK: - The bell

    static let bell = """
        A small brass hand-bell, of the sort once rung to call the faithful.
        """

    static let bellRedHot = """
        The bell glows a dull, angry red — freshly rung at the gate of Hades,
        it is still far too hot to touch.
        """

    static let bellTooHotToReach = "The bell is too hot to reach."

    static let bellRingsHollow = "Ding, dong."

    static let bellCools = "The bell appears to have cooled down."

    // MARK: - The candles

    static let candles = """
        A pair of white candles, half burned down. Whatever else this temple
        has lost, it has not run out of these.
        """

    static let candlesLit = "The candles are lighted."

    static let candlesAlreadyLit = "The candles are already lighted."

    static let candlesNeedFlame = """
        You have to light them with something that's burning, you know.
        """

    /// Written fresh, for a mainframe-only outcome the trilogy dropped: lighting
    /// the candles from the ivory torch does not light them at all.
    static let candlesVaporised = """
        The heat from the torch is so intense that the candles are vaporised.
        """

    static let candlesAlreadyLitNearTorch = """
        You realize, just in time, that the candles are already lighted.
        """

    static let candlesSpent = """
        Alas, there's not much left of the candles. Certainly not enough to
        burn.
        """

    static let candlesNotLit = "The candles are not lighted."

    static let candlesOut = "The flame is extinguished."

    static let candlesShorter = "The candles grow shorter."

    static let candlesVeryShort = "The candles are very short."

    static let candlesGone = """
        I hope you have more light than from a pair of candles.
        """

    // MARK: - The Egyptian Room and the coffin

    /// Adapted. `EGYPT` is `substantial`: the trilogy leaves the Egyptian Room
    /// one ascending staircase to the west and nothing else. The mainframe
    /// gives it a staircase up to the Glacier Room and two doors besides.
    static let egyptianRoom = """
        This is a room which looks like an Egyptian tomb. There is an
        ascending staircase in the room, as well as doors east and south.
        """

    /// Verbatim — the coffin's line is in the comparison's `identical` bucket.
    static let coffin = """
        The solid-gold coffin used for the burial of Ramses II is here.
        """

    static let coffinExamined = """
        A magnificent coffin of solid gold, worked all over with the likeness
        of a king at rest. It is heavy beyond reason and would tax anyone who
        tried to carry it far.
        """

    /// The mainframe's `COFFIN-CURE`: every narrow way out of this quarter of
    /// the map is shut while the coffin is in your hands. Each refusal is the
    /// source's own reason.
    static let coffinTooWideForCrawl = """
        The passage is too narrow to accommodate coffins.
        """

    static let coffinTooWideForRavine = """
        The coffin will not fit through this passage.
        """

    static let coffinTooHeavyForStairs = """
        The stairs are too steep for you with your burden.
        """

    static let coffinTooHeavyForPassage = """
        The passage is too steep for carrying the coffin.
        """

    static let egyptianStaircase = """
        A staircase of dressed stone climbing out of the tomb, and cold air
        coming down it.
        """

    static let egyptianDoors = """
        Two doorways, east and south, cut square into the rock the way
        everything in this room is cut square.
        """

    // MARK: - The Glacier Room

    /// Written fresh. `ICY` prints from a routine in the mainframe and has no
    /// trilogy counterpart — Zork II's Ice Room is a different room with a
    /// different puzzle. The exits and the passage the melt opens are the
    /// source's.
    static let glacierRoom = """
        This is a large chamber cut from ancient rock, and the greater part of
        it is filled by a wall of ice. Passages lead north and east.
        """

    /// The same room once the ice has gone: the chamber is the chamber, but
    /// nothing fills it any more.
    static let glacierRoomThawed = """
        This is a large chamber cut from ancient rock, worn smooth on every
        face by the ice that stood in it for so long. Passages lead north and
        east.
        """

    static let glacierPartlyMelted = "Part of the glacier has been melted."

    static let glacierGone = """
        Where the ice stood, a broad passage now opens westward, and the floor
        under it is still steaming.
        """

    /// Verbatim — `ICE` is in the comparison's `identical` bucket, so the
    /// trilogy's line and the mainframe's are the same sentence.
    static let glacier = "A mass of ice fills the western half of the room."

    static let glacierExamined = """
        A wall of ice, blue-white and old, filling the room from floor to
        ceiling. Nothing you are carrying is going to chip it.
        """

    static let glacierRemains = """
        What is left of the Great Glacier: a rind of ice around a hole big
        enough to walk through.
        """

    /// Written fresh, from the mainframe's `GLACIER` routine.
    static let glacierMeltsAwayTheTorch = """
        The torch hits the glacier and the ice goes up in a roar of steam. When
        it clears there is a passage west where the wall of ice had been, and
        the torch — quenched, and black now — has been carried away on the
        flood.
        """

    static let glacierUnmoved = """
        The glacier is unmoved by your ridiculous attempt.
        """

    static let glacierDrownsYou = """
        Part of the glacier melts, drowning you under a torrent of water.
        """

    static let glacierWontMeltWithThat = "You certainly won't melt it with that."

    // MARK: - The Ruby Room

    /// Written fresh. `RUBYR` has no trilogy counterpart either.
    static let rubyRoom = """
        This is a small chamber that lay for centuries behind the Great
        Glacier, sealed and forgotten. Two narrow passages leave it, south and
        west.
        """

    static let ruby = "There is a ruby here."

    static let rubyExamined = """
        A ruby the size of a hen's egg, cut long ago by somebody who knew
        exactly what they were doing.
        """

    // MARK: - The Engravings Cave

    /// Adapted. The comparison buckets `CAVE4` `minor` — the two lines differ
    /// by a handful of characters — but the check the map demands is not about
    /// the character count: the trilogy's cave has passages northwest and east,
    /// and the mainframe's has them north and southeast. The table wins.
    static let engravingsCave = """
        You have entered a low cave with passages leading north and southeast.
        """

    /// Verbatim — `ENGRA` is in the comparison's `identical` bucket — **except
    /// for one hyphen**, which was never a word of it. The 1977 text file
    /// broke `Unfortunately` across a fixed column, and this engine re-packs a
    /// paragraph, so the break landed mid-line as *"Unfor- tunately"*. The rule
    /// `docs/games/dungeon.md` takes the trilogy line under is *"its typography
    /// is cleaner"*; keeping a column artifact from a teletype nobody is
    /// reading this on would be the one place that rule argues against itself.
    /// Not made a form — this is a description, not an inscription, and the
    /// Hades gate below is what indentation is for.
    static let engravings = """
        The engravings were incised in the living rock of the cave wall by an
        unknown hand. They depict, in symbolic form, the beliefs of the
        ancient Zorkers. Skillfully interwoven with the bas reliefs are
        excerpts illustrating the major religious tenets of that time.
        Unfortunately, a later age seems to have considered them blasphemous
        and just as skillfully excised them.
        """

    // MARK: - The gate of Hades

    /// Verbatim. `LLD1` prints from a routine in the mainframe, so there is no
    /// line to compare; the trilogy's gate is the same gate, with the same
    /// inscription over it and the same corner full of bodies.
    static let entranceToHades = """
        You are outside a large gateway, on which is inscribed

          Abandon every hope
          all ye who enter here!

        The gate is open; through it you can see a desolation, with a pile of
        mangled bodies in one corner. Thousands of voices, lamenting some
        hideous fate, can be heard.
        """

    static let spiritsBarTheGate = """
        The way through the gate is barred by evil spirits, who jeer at your
        attempts to pass.
        """

    /// Stage 1 of the ceremony. The bell has stopped the jeering — see
    /// ``bellRingRedHot`` — and the gate's paragraph went on reporting it for
    /// the whole six turns the ceremony lasts.
    static let spiritsBarTheGateSilent = """
        The way through the gate is barred by evil spirits, silent now, every
        one of them turned to face you.
        """

    /// Stage 2. The candles are lit, the spirits cower — see
    /// ``candlesLitForRitual`` — and the gate is still shut to you.
    static let spiritsBarTheGateCowering = """
        The way through the gate is barred by evil spirits, who cower from the
        candle flames while they bar it.
        """

    static let hadesGateBlocked = """
        Some invisible force prevents you from passing through the gate.
        """

    static let hadesGates = """
        A great iron gate, standing open, and past it nothing you would choose
        to look at twice.
        """

    static let spirits = """
        A wall of spirits, thin as smoke and packed as close as a crowd, and
        every one of them enjoying this.
        """

    /// The same noun once they have gone through the walls. The item stays in
    /// the room because the player may still name it, and what it answers is
    /// that there is nothing there.
    static let spiritsFled = """
        Nothing of them is left to look at, and the cold they were standing in
        is going out of the air.
        """

    static let spiritsUnaffected = "You seem unable to affect these spirits."

    static let spiritsUnaffectedByObject = """
        How can you attack a spirit with material objects?
        """

    static let pileOfCorpses = """
        A pile of mangled bodies in the corner beyond the gate, heaped there
        by whoever keeps this place.
        """

    static let corpsesLeaveThemBe = """
        You have no desire to touch them, and they are past minding.
        """

    // MARK: - The exorcism

    static let bellRingRedHot = """
        The bell suddenly becomes red hot and falls to the ground. The
        wraiths, as if paralyzed, stop their jeering and slowly turn to face
        you. On their ashen faces, the expression of a long-forgotten terror
        takes shape.
        """

    static let candlesDropInConfusion = """
        In your confusion, the candles drop to the ground (and they are out).
        """

    static let candlesLitForRitual = """
        The flames flicker wildly and appear to dance. The earth beneath
        your feet trembles, and your legs nearly buckle beneath you.
        The spirits cower at your unearthly power.
        """

    static let spiritsBanished = """
        Each word of the prayer reverberates through the hall in a deafening
        confusion. As the last word fades, a voice, loud and commanding,
        speaks: "Begone, fiends!" A heart-stopping scream fills the cavern,
        and the spirits, sensing a greater power, flee through the walls.
        """

    static let exorcismLapses = """
        The tension of this ceremony is broken, and the wraiths, amused but
        shaken at your clumsy attempt, resume their hideous jeering.
        """

    static let exorcismNeedsCeremony = "You must perform the ceremony."

    static let exorcismUnequipped = "You are not equipped for an exorcism."

    // MARK: - The Land of the Living Dead

    /// Adapted. The trilogy's Land of the Dead is the same desolation, and its
    /// line stands but for the last sentence: Zork I's room has one passage
    /// north, and the mainframe's has two — west back to the gate and east to
    /// a tomb this milestone does not build.
    static let landOfTheLivingDead = """
        You have entered the Land of the Living Dead. Thousands of lost souls
        can be heard weeping and moaning. In the corner are stacked the remains
        of dozens of previous adventurers less fortunate than yourself.
        Passages exit to the east and to the west.
        """

    static let pileOfBodies = """
        The remains of dozens of adventurers, stacked like cordwood by
        somebody with a tidy mind.
        """

    // MARK: - The ivory torch

    /// Verbatim — the trilogy's torch is the mainframe's torch, down to the
    /// find and case values.
    static let ivoryTorchInPlace = "An ivory torch, burning, is here."

    static let ivoryTorch = "The torch is burning."

    /// The torch read while the reader is under water.
    ///
    /// "The torch is burning." printed on the turn after "The water level here
    /// is now high in your lungs." — two consecutive lines, one of which is a
    /// flame and the other of which is a drowning. The **mechanic** is not the
    /// thing that moves here, and that is a decision rather than an oversight:
    /// dousing the torch would take a fourteen-point treasure out of a game
    /// that has no way to relight it, which is a scoring change, and the room
    /// kills the reader either way one turn later. What the sentence stops
    /// doing is reporting an ordinary flame in a frame where a flame is not
    /// ordinary. The mainframe's torch is a supernatural object — it is the
    /// one light in the game that needs no tending, and only the glacier has
    /// ever touched it — so naming that is fidelity rather than a dodge.
    /// (#329)
    static let ivoryTorchUnderWater = """
        The torch is burning under water, which it has no business doing and
        shows no sign of stopping.
        """

    static let ivoryTorchInPlaceUnderWater = "An ivory torch is burning under the water here."

    static let burnedOutTorch = """
        A burned out ivory torch, black along one side where the ice took it,
        and no more use for light than a stick.
        """

    static let torchWontExtinguish = """
        You burn your hand as you attempt to extinguish the flame.
        """

    static let torchAlreadyOut = """
        There is nothing left in it to put out.
        """
}
