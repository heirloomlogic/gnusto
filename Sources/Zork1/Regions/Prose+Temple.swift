/// Original Zork I prose for the Temple & Hades region (``ZorkTemple``): the
/// Engravings Cave and the Dome Room's rope descent, the Torch Room, the Temple
/// and its Altar, the Egyptian Room with the coffin, and the dark way down past
/// a draughty cave to the Entrance to Hades and the Land of the Dead. These are
/// the verbatim Infocom descriptions (see THIRD_PARTY_NOTICES at the repo
/// root). See `Prose.swift` for the names-vs-prose ledger rule.
extension Prose {
    // MARK: - Rooms

    static let engravingsCave = """
        You have entered a low cave with passages leading northwest and east.
        """

    static let domeRoom = """
        You are at the periphery of a large dome, which forms the ceiling
        of another room below. Protecting you from a precipitous drop is a
        wooden railing which circles the dome.
        """

    static let torchRoom = """
        This is a large room with a prominent doorway leading to a down
        staircase. Above you is a large dome. Up around the edge of the
        dome (20 feet up) is a wooden railing. In the center of the room
        sits a white marble pedestal.
        """

    static let temple = """
        This is the north end of a large temple. On the east wall is an
        ancient inscription, probably a prayer in a long-forgotten language.
        Below the prayer is a staircase leading down. The west wall is solid
        granite. The exit to the north end of the room is through huge
        marble pillars.
        """

    static let egyptRoom = """
        This is a room which looks like an Egyptian tomb. There is an
        ascending staircase to the west.
        """

    static let altar = """
        This is the south end of a large temple. In front of you is what
        appears to be an altar. In one corner is a small hole in the floor
        which leads into darkness. You probably could not get back up it.
        """

    static let templeCave = """
        This is a tiny cave with entrances west and north, and a dark,
        forbidding staircase leading down.
        """

    static let entranceToHades = """
        You are outside a large gateway, on which is inscribed

          Abandon every hope
          all ye who enter here!

        The gate is open; through it you can see a desolation, with a pile of
        mangled bodies in one corner. Thousands of voices, lamenting some
        hideous fate, can be heard.
        """

    static let landOfDead = """
        You have entered the Land of the Living Dead. Thousands of lost souls
        can be heard weeping and moaning. In the corner are stacked the remains
        of dozens of previous adventurers less fortunate than yourself.
        A passage exits to the north.
        """

    // MARK: - Items

    static let ivoryTorch = "The torch is burning."

    static let templeRailing = """
        A stone railing runs around the rim of the dome — the kind of thing a
        rope might be made fast to.
        """

    static let bell = """
        A small brass hand-bell, of the sort once rung to call the faithful.
        """

    static let redHotBell = """
        The bell glows a dull, angry red — freshly rung at the gate of Hades,
        it is still far too hot to touch.
        """

    static let book = """
        Commandment #12592

        Oh ye who go about saying unto each:  "Hello sailor":
        Dost thou know the magnitude of thy sin before the gods?
        Yea, verily, thou shalt be ground between two stones.
        Shall the angry gods cast thy body into the whirlpool?
        Surely, thy eye shall be put out with a sharp stick!
        Even unto the ends of the earth shalt thou wander and
        Unto the land of the dead shalt thou be sent at last.
        Surely thou shalt repent of thy cunning.
        """

    static let candles = """
        A pair of white candles, half burned down. Unlit, they are only so
        much cold wax.
        """

    static let coffin = """
        A magnificent coffin of solid gold, worked all over with the likeness
        of a king at rest. It is heavy beyond reason and would tax anyone who
        tried to carry it far.
        """

    static let sceptre = """
        An ornamented sceptre, tapering to a sharp point, is here.
        """

    static let crystalSkull = """
        A skull cut whole from a block of clear crystal, the empty sockets
        catching what little light there is.
        """

    static let burningMatch = "The match is burning."

    // MARK: - First sights

    static let coffinFirstSight = "The solid-gold coffin used for the burial of Ramses II is here."

    static let crystalSkullFirstSight = """
        Lying in one corner of the room is a beautifully carved crystal skull.
        It appears to be grinning at you rather nastily.
        """

    // MARK: - Rope & the dome descent

    static let domeNoRope = """
        You cannot go down without fracturing many bones.
        """

    static let torchNoRope = "You cannot reach the rope."

    static let ropeTied = """
        The rope drops over the side and comes within ten feet of the floor.
        """

    static let ropeUntied = "The rope is now untied."

    static let ropeTakeUnties = "You untie the rope from the railing before taking it."

    static let ropeNeedsRailing = "You can only tie the rope to the railing here."

    static let ropeNothingToTie = "You can't tie the rope to that."

    // MARK: - Torch

    static let torchWontExtinguish = "You nearly burn your hand trying to extinguish the flame."

    // MARK: - The altar & the coffin

    static let coffinTooHeavy = """
        You haven't a prayer of getting the coffin down there.
        """

    static let prayerAnswered = """
        You bow your head at the altar, and the temple dissolves around you.
        When the world settles again you are standing in open forest, whatever
        you carried still in your hands.
        """

    // MARK: - The bell

    static let bellRingsHollow = "Ding, dong."

    static let bellRingRedHot = """
        The bell suddenly becomes red hot and falls to the ground. The
        wraiths, as if paralyzed, stop their jeering and slowly turn to face
        you. On their ashen faces, the expression of a long-forgotten terror
        takes shape.
        """

    static let bellAlreadyRung = "The bell is too hot to reach."

    static let bellCools = "The bell appears to have cooled down."

    static let bellTooHotToTake = "The bell is very hot and cannot be taken."

    // MARK: - The candles

    static let candlesNeedFlame = "You have to light them with something that's burning, you know."

    static let candlesLit = "The candles are lit."

    static let candlesLitForRitual = """
        The flames flicker wildly and appear to dance. The earth beneath
        your feet trembles, and your legs nearly buckle beneath you.
        The spirits cower at your unearthly power.
        """

    static let candlesSpent = """
        Alas, there's not much left of the candles. Certainly not enough to
        burn.
        """

    static let candlesDim = "The candles won't last long now."

    static let candlesDie = "The flame is extinguished."

    static let candlesSnuffedByDraft = "A gust of wind blows out your candles!"

    // MARK: - The exorcism

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

    static let hadesGateBlocked = """
        Some invisible force prevents you from passing through the gate.
        """

    // MARK: - The matches

    static let matchStrikes = "One of the matches starts to burn."

    static let matchesGone = "I'm afraid that you have run out of matches."

    static let matchBurnsOut = "The match has gone out."
}
