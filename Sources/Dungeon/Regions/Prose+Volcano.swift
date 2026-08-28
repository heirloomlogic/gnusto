/// Prose for the volcano (``DungeonVolcano``): the shaft and its four levels of
/// open air, the Volcano Bottom and the Lava Room under it, the three ledges,
/// the Library, the Dusty Room, and the balloon that reaches most of them.
///
/// The three-way rule, and the rule for which file a line goes in, are stated
/// once on ``Prose``.
///
/// `VAIR1`, `VAIR2`, `LEDG3`, `HOOK1`, `HOOK2`, `GNOME`, `CARD` and `DBALL` are
/// `identical` entries in `docs/games/dungeon-prose-comparison.md`, and `VLBOT`
/// and `LIBRA` are `minor`, so those ten are the trilogy's lines verbatim.
///
/// Three departures from that, each for a reason the comparison document cannot
/// see:
///
/// - `LAVA` is `minor` and is **adapted anyway**. Zork II's line says the exits
///   are east and south; the mainframe's are **west** and south, because the
///   room the trilogy reached east of here is the Glacier Room and the room the
///   mainframe reaches west of here is the Ruby Room. The room decides, not the
///   bucket. The same trap M3 and M4 both walked into.
/// - `VAIR4` is `substantial`, and the trilogy's version drops the one fact the
///   puzzle turns on: the rim is fifteen feet across, which is why a balloon
///   that rises past this level tears itself open on it. Adapted to put it back
///   — and adapted a second time to say the wide ledge is **east**, which is
///   where the exit table puts it and where both sources' paragraphs do not.
///   That departure is from the prose of both sources at once, so it is filed
///   in `FIDELITY.md` rather than only here.
/// - `VAIR3` is filed with **no trilogy counterpart**, and it has one:
///   `historicalsource-zork2/2dungeon.zil` declares `VAIR-3`, *Volcano by
///   Viewing Ledge*, whose line differs from the mainframe's by two words. The
///   pairing is missed because the display names differ and the room declares no
///   exits at all, so neither the name matcher nor the graph matcher can reach
///   it. Taken as the `minor` entry it would have been.
///
/// `LEDG4` and `SAFE` appear in no bucket because **both sources generate them
/// from code** — `dung.355` gives each an empty description and a room routine,
/// and the trilogy does the same. Their text here is the trilogy's routine's,
/// which is MIT-licensed like any other trilogy line.
///
/// Everything else — the shaft's scenery, what the blue label *says*, the
/// gnome's bargain, the explosion and its aftermath — is written fresh.
///
/// The four **listing lines** this region owed since milestone 6 are here now
/// (#207): the crown's, the card's, the stamp's and the label's. Each is built
/// from its `dung.355` line, and each is adapted to put the thing in the
/// container it is nested in — by name, or by a pronoun the line above it
/// supplies. The mainframe writes a listing line for an object lying loose on a
/// floor, and none of these four is ever on one, except the label after the
/// balloon comes apart — which is the one of the four that keeps the source's
/// sentence untouched. Adapting is the license `FIDELITY.md` grants this game
/// and not `Zork1`.
extension Prose {
    // MARK: - The floor of the volcano

    /// Verbatim; `VLBOT` is `minor`.
    static let volcanoBottom = """
        You are at the bottom of a large dormant volcano. High above you light
        enters from the cone of the volcano. The only exit is to the north.
        """

    static let volcanoCone = """
        The shaft of the volcano opens a long way overhead, and the daylight
        that comes down it dies well before it reaches the floor.
        """

    /// Written fresh, and the near half of a pair the shaft owed at every
    /// level. ``volcanoCone`` is a line about what is overhead, and it used to
    /// answer `x floor` and `x ash` to a player standing on the floor with the
    /// ash over their boots. (#233)
    static let volcanoBottomAsh = """
        Grey ash, cold and deep enough to walk quietly in, banked up against
        the wall that rings the place. The one gap in that wall is north.
        """

    /// Adapted. `LAVA` is `minor`, but the trilogy's line sends its second exit
    /// east and the mainframe's goes west.
    static let lavaRoom = """
        This is a small room, whose walls are formed by an old lava flow. There
        are exits here to the west and the south.
        """

    static let lavaFlow = """
        The flow set centuries ago into ropes and folds, and it is still sharp
        enough to take the skin off a careless hand.
        """

    // MARK: - The shaft

    /// Verbatim; `VAIR1` is `identical`.
    static let volcanoCore = """
        You are about one hundred feet above the bottom of the volcano. The top
        of the volcano is clearly visible here.
        """

    /// Verbatim; `VAIR2` is `identical`.
    static let volcanoNearNarrowLedge = """
        You are about two hundred feet above the volcano floor. Looming above is
        the rim of the volcano. There is a small ledge on the west side.
        """

    /// Taken as `minor` from the trilogy's `VAIR-3`, which the comparison
    /// document does not pair. See the note on this file.
    static let volcanoNearViewingLedge = """
        You are high above the floor of the volcano. The rim of the volcano
        looks very narrow and you are very near it. To the east is what appears
        to be a viewing ledge, too thin to land on.
        """

    /// Adapted twice over. `VAIR4` is `substantial`, and the fifteen feet are
    /// the fact the rim's danger rests on.
    ///
    /// And **the ledge is east, where both sources' paragraphs say west.** This
    /// is not the trilogy rewriting a room the mainframe kept: `dung.355` says
    /// west in the prose and files `VAIR4 EAST -> LEDG4` *and* `VAIR4 LAND ->
    /// LEDG4` in the exit table, so the original contradicts itself and Zork II
    /// copied the paragraph without the table. The table wins, as it does for
    /// `LAVA` — and here nothing else could: `LEDG4 WEST` is the gnome's
    /// chimney down to the volcano floor, so a west-facing landing would put
    /// the ledge on both sides of itself, and
    /// ``DungeonVolcano/ledgeLandings`` reads the bearing three ways. Its
    /// sibling `VAIR2` says west and *is* wired west, and is untouched.
    static let volcanoNearWideLedge = """
        You are near the rim of the volcano, which is only about fifteen feet
        across. Above you it is open to the sky. To the east, there is a place
        to land on a wide ledge.
        """

    static let volcanoWallsFromTheAir = """
        Bare rock on every side, close enough to touch and offering nothing at
        all to hold on to.
        """

    static let volcanoRimFromBelow = """
        The rim closes overhead like the mouth of a bottle, with the sky beyond
        it.
        """

    /// The four lines below are written fresh, one per level of open air, and
    /// they are the far half of the pair each level owed. The rock beside the
    /// basket is ``volcanoWallsFromTheAir``; everything the paragraph *points
    /// at* — the floor, the rim, the ledge waiting on one wall — is a good deal
    /// further off than that, and used to answer "close enough to touch". Each
    /// line says what its own room's paragraph says, from the altitude that
    /// paragraph is written at. (#233)
    static let shaftFromCore = """
        The floor of the volcano lies a hundred feet down, losing its edges in
        the gloom; the top of the shaft is a bright ring a long way further up.
        Nothing in either direction is any use to a man in a basket.
        """

    static let shaftFromNarrowLedgeAir = """
        Two hundred feet of nothing below the basket, and the rim looming over
        it. A shelf of rock juts from the west wall at about this height — the
        one place up here that would take a landing.
        """

    static let shaftFromViewingLedgeAir = """
        The rim is very close now and very narrow, and the floor is lost
        somewhere a long way under you. A thin shelf of rock stands out from the
        east wall, too slight to set anything down on.
        """

    static let shaftFromWideLedgeAir = """
        A broad shelf of rock juts from the east wall, the only thing at this
        height that would take a basket. Below it the volcano falls away
        further than the light goes.
        """

    // MARK: - The Narrow Ledge

    /// Verbatim; `LEDG2` is `substantial`, and the trilogy's line is true of
    /// this room's exit table as it stands.
    static let narrowLedge = """
        You are on a narrow ledge within an old dormant volcano. This ledge is
        about halfway between the floor below and the rim above. There is an
        exit to the south.
        """

    /// Written fresh, and printed only once the gnome has been paid. The line
    /// above is verbatim and true of this room's exit table as it stands — but
    /// the fee opens a chimney west out of the ledge, and `GNOME-DOOR` is
    /// one-way and permanent, so from then on the room had one exit in its
    /// paragraph and two in its map.
    static let narrowLedgeChimneyOpen = """
        A narrow chimney has been opened in the west wall, sloping down out of
        sight.
        """

    /// Reworded. It used to end "with the shaft on one hand and a doorway on
    /// the other" — two nouns nothing in this room answered, and the second of
    /// them not there at all until the gnome has been paid. The shaft belongs
    /// to ``narrowLedgeDistance`` now, which is the line about everything this
    /// ledge is halfway between. (#233)
    static let narrowLedgeRock = """
        A shelf of old rock, wide enough to stand on and not much wider, with
        the volcano dropping away past one edge of it.
        """

    /// Written fresh. The room's own paragraph puts this ledge "halfway between
    /// the floor below and the rim above", and both of those nouns used to
    /// answer with the shelf underfoot. (#233)
    static let narrowLedgeDistance = """
        The floor of the volcano is a couple of hundred feet down and the rim
        about as far again up, the shaft running past this ledge without
        pausing at it.
        """

    static let ledgeNoJumping = "I wouldn't jump from here."

    /// Verbatim; both hooks carry `HOOK-DESC` in the source and both are
    /// `identical`.
    static let hookInPlace = "There is a small hook attached to the rock here."

    /// Verbatim; the source swaps this line in for the one above while the
    /// wire is over the hook, which is how a player standing on a ledge sees
    /// at a glance whether the balloon is going to wait for them.
    static let hookHoldsTheBalloon = """
        The basket is anchored to a small hook by the braided wire.
        """

    static let hook = """
        A small iron hook, driven into the rock and rusted solid there. It would
        hold a good deal more than it looks like it would.
        """

    static let hookIsFixed = "The hook is set into the rock and stays there."

    // MARK: - The zorkmid

    /// Adapted. `COIN` is `substantial`: the trilogy calls it a priceless gold
    /// zorkmid and the mainframe calls it engraved, and the engraving is the
    /// half worth keeping, because reading it is what the coin is for.
    static let zorkmidInPlace = """
        On the floor is an engraved gold zorkmid, a collector's item if ever
        there was one.
        """

    static let zorkmid = """
        A gold zorkmid of ten thousand, struck in the year 722 of the Great
        Underground Empire and worn smooth around the rim. There is writing on
        both faces of it.
        """

    /// Written fresh. The source's coin bears a figure drawn in 1981 mainframe
    /// typography; what it *says* is reported here instead, which keeps the
    /// joke and reproduces none of it.
    static let zorkmidEngraved = """
        Around the face, in letters a hand's breadth apart: TEN THOUSAND
        ZORKMIDS — IN FROBS WE TRUST. The portrait in the middle is Lord Dimwit
        Flathead, Beloved of Zorkers, rendered by somebody who had clearly never
        seen him and was not going to let that stop them.
        """

    // MARK: - The Library

    /// Verbatim; `LIBRA` is `minor`.
    static let library = """
        This must have been a large library, probably for the royal family. All
        of the shelves have been gnawed to pieces by unfriendly gnomes. To the
        north is an exit.
        """

    static let libraryShelves = """
        Rank on rank of shelving, chewed down to splinters at every level a
        small determined jaw could reach.
        """

    /// Verbatim; the trilogy's line for the green book.
    static let greenBookInPlace = """
        A handsome book, bound in green leather, sits in the center of the room.
        """

    /// Verbatim; the trilogy's line for the blue book.
    static let blueBookInPlace = """
        Worn and battered in one corner of the room is a blue book.
        """

    /// Verbatim; the trilogy's line for the purple book.
    static let purpleBookInPlace = """
        Lying in the dust, and covered with mold, is a purple book.
        """

    /// Adapted. The trilogy's line — "Right beside the purple book sits a white
    /// one" — stops being true the moment somebody picks the purple book up,
    /// and a listing line prints until the thing is touched. Same fix M4 made
    /// for the same reason.
    static let whiteBookInPlace = """
        A white book, glossier than the rest, sits among them.
        """

    /// Verbatim; the source's `GREEK-TO-ME`, which the trilogy keeps word for
    /// word for three of the four books.
    static let bookIsUnreadable = """
        This book is written in a tongue with which I am unfamiliar.
        """

    /// Adapted. The line used to say each book survived the gnomes "by being on
    /// a shelf too high for them", which the room's own listing lines
    /// contradict three times over: the green one sits in the centre of the
    /// floor, the blue one in a corner, the purple one in the dust. One examine
    /// text answers for all four wherever they lie, so it says *that* they came
    /// through rather than how.
    static func bookExamined(_ colour: String) -> String {
        """
        A \(colour) book, thick and unlabelled, and whole: whatever the gnomes
        did to the shelving, they left the reading alone.
        """
    }

    /// Written fresh. The stamp's face is 1981 typography in the source; what
    /// is printed on it is reported instead.
    static let stamp = """
        A three-zorkmid stamp, gummed and never used, bearing the profile of
        Lord Dimwit Flathead and the legend OUR EXCESSIVE LEADER.
        """

    /// Adapted from `ODESC1` "There is a Flathead stamp here.", an `identical`
    /// entry. *Loose* because ``purpleBookOpens`` has just said the stamp slid
    /// out of the pages — one stamp, and the two sentences have to agree about
    /// it. *Its* rather than *the purple book's* because the lister prints a
    /// container's contents directly under the container's own line, and the
    /// book's is "Lying in the dust, and covered with mold, is a purple book.",
    /// which this would otherwise follow with two more words of *lying* and
    /// *purple book*.
    static let stampInBook = """
        A Flathead stamp rests loose among its pages.
        """

    static let purpleBookOpens = """
        The pages fall apart at a place somebody kept, and a stamp slides out of
        them into your hand's reach.
        """

    // MARK: - Volcano View

    /// Verbatim; `LEDG3` is `identical`.
    static let volcanoView = """
        You are on a ledge in the middle of a large volcano. Below you the
        volcano bottom can be seen and above is the rim of the volcano. A couple
        of ledges can be seen on the other side of the volcano; it appears that
        this ledge is intermediate in elevation between those on the other side.
        The exit from this room is to the east.
        """

    /// Retargeted and rewritten as the room's *distant view*, the way Canyon
    /// View's is. It answered `rim` and `bottom` as well as the far ledges, and
    /// the rim and the bottom are not the far ledges; now one line covers
    /// everything across the shaft and everything up or down it, which is what
    /// the room's paragraph is about, and ``volcanoViewLedge`` covers the one
    /// thing that is underfoot. (#233)
    static let volcanoViewDistance = """
        Two shelves of rock stand out from the far wall, one a good way below
        this one and one a good way above it. Under them is the floor of the
        volcano and over them its rim, and none of it is anywhere near close
        enough to reach.
        """

    /// Written fresh. The room's paragraph calls the ledge the player is
    /// standing on "this ledge", and nothing in the room answered for it: the
    /// only item here was about the two across the shaft. (#233)
    static let volcanoViewLedge = """
        A shelf of stone about halfway up the volcano's wall, with the way back
        east behind you and a long drop in front.
        """

    static let volcanoViewNoJumping = "I wouldn't try that."

    static let volcanoViewNoCrossing = "It is impossible to cross this distance."

    static let crossNothingHere = "There is nothing here to cross."

    // MARK: - The Wide Ledge

    /// Verbatim, from the trilogy's `LEDGE-FCN`. Both sources print this room
    /// from a routine, so it is in no bucket in the comparison document.
    static let wideLedge = """
        You are on a wide ledge high in the volcano. The rim of the volcano is
        about 200 feet above and there is a precipitous drop to the bottom.
        """

    static let wideLedgeDoor = "There is a small door to the south."

    /// The Narrow Ledge got this repair in the first round and the Wide Ledge,
    /// which nobody had ever stood on, did not. The gnome's fee opens a west
    /// door and a chimney out of *whichever* ledge he was paid on, and this
    /// room's paragraph named only the door to the south — to a player whose
    /// balloon is gone and whose only way off is the exit the paragraph does
    /// not mention. ``Prose/gnomePaid(_:)`` hands them "the west end of the
    /// ledge", so that is the phrase this answers to. (#329)
    static let wideLedgeChimneyOpen = """
        A door stands open at the west end of the ledge, with a narrow chimney
        beyond it sloping steeply down.
        """

    static let wideLedgeRubble = "The way to the south is blocked by rubble."

    static let wideLedgeNoJumping = "It's a long way down."

    /// Reworded to drop its second clause, "with a doorway cut into the wall
    /// behind it". That clause was a claim about ``dustyRoomWrecked`` published
    /// through a channel that cannot branch — it went on describing a doorway
    /// after the blast filled it with rubble. Splitting the door off as
    /// ``DungeonVolcano/wideLedgeDoorway`` puts the branch on a one-purpose
    /// item and leaves this line a constant nothing can falsify. (#233)
    static let wideLedgeRock = """
        A broad apron of rock, sound underfoot and wide enough to set a basket
        down on.
        """

    /// Written fresh. The room's paragraph puts the rim two hundred feet up and
    /// a precipitous drop under the edge, and both used to answer with the
    /// apron the player is standing on. (#233)
    static let wideLedgeDistance = """
        Two hundred feet of rock stand between this ledge and the rim. Rather
        more than that lies the other way, down to a floor the light does not
        reach.
        """

    /// The two states of the small door south, written fresh. The room's own
    /// paragraph has branched on the blast since it was written; the door
    /// itself had no examine text at all, only a clause inside the description
    /// of the rock. (#233)
    static let wideLedgeDoorExamined = """
        A low door cut square into the south wall, with a dusty room beyond it.
        """

    static let wideLedgeDoorBlocked = """
        There is no door there now — only the rubble the blast brought down
        across it, wedged tight from the floor up.
        """

    // MARK: - The Dusty Room

    /// Verbatim, from the trilogy's `SAFE-ROOM-FCN`, for the same reason as the
    /// Wide Ledge.
    static let dustyRoom = """
        You are in a dusty old room which is featureless, except for an exit on
        the north side.
        """

    static let dustyRoomBoxShut = """
        Imbedded in the far wall is a rusty box. It appears to be somewhat
        damaged, since an oblong hole has been chipped out of the front of it.
        """

    static let dustyRoomBoxOpen = """
        On the far wall is a rusty box, whose door has been blown off.
        """

    static let dustyRoomDust = """
        Dust, thick enough to take a footprint, and nothing at all under it.
        """

    static let rustyBox = """
        A steel box set into the stone, rusted through in places and still a
        great deal stronger than anything you are carrying.
        """

    /// The same box after the charge. The Dusty Room's own paragraph has
    /// branched on ``DungeonVolcano/rustyBox``'s `isOpen` since milestone 6,
    /// twelve lines from this constant, and `x safe` went on calling the box
    /// intact and unbeatable while the listing beside it described the hole in
    /// it. (#329)
    static let rustyBoxBlown = """
        A steel box set into the stone, with its front peeled back off the
        stonework and a good deal of the stonework peeled back with it.
        """

    static let safeIsEmbedded = "The box is imbedded in the wall."

    static let safeWillNotOpen = "The box is rusted and will not open."

    static let safeHasNoDoor = "The box has no door!"

    static let safeIsNotOpen = "The box is not open."

    static let oblongHole = """
        The oblong hole has been chipped out of the box, probably by somebody
        who wanted whatever is inside it. The attempt was a pathetic failure.
        """

    /// Adapted from `ODESCO`, which is the field the mainframe prints while the
    /// crown is untouched — "The excessively gaudy crown of Lord Dimwit Flathead
    /// is here." *Here* is written for a crown lying on a floor, and this one is
    /// never on one: it sits in the box until a hand takes it out. So the
    /// sentence places it and keeps the joke, which is the whole of the line.
    ///
    /// *Inside it* rather than *inside the box*, because by the time this line
    /// prints the box has been named twice already — once by the room's own
    /// second paragraph and once by the card's line, which `ContainmentIndex`
    /// sorts ahead of this one. Three sentences running that end in *box* is
    /// what the first draft read like.
    ///
    /// The other field, `ODESC1` "Lord Dimwit's crown is here.", is the
    /// after-touch line, and this engine has no channel for one — after the
    /// touch the stock sentence takes over. It is not reproduced.
    static let crownInBox = """
        Inside it sits the excessively gaudy crown of Lord Dimwit Flathead.
        """

    static let crown = """
        A crown of gold over gold, set with every stone its maker could be
        persuaded to part with, and heavy enough to have given its owner a
        permanent stoop.
        """

    /// Adapted from `ODESC1` "There is a card with writing on it here.", an
    /// `identical` entry, for the same reason as the crown's: the card is in the
    /// box or it is in a hand, and never on the floor of this room.
    static let cardInBox = """
        A card with writing on it lies in the bottom of the box.
        """

    static let card = """
        A plain card, printed on one side and blotched with damp on the other.
        """

    /// Verbatim; the trilogy's text for the card, minus its 1981 line breaks.
    static let cardText = """
        Warning: This room was constructed over very weak rock strata.
        Detonation of explosives in this room is strictly prohibited!

        Frobozz Magic Cave Company, per M. Agrippa, foreman
        """

    // MARK: - The balloon

    /// **The basket, the bag over it and the wire off its side are one
    /// paragraph, not three.** (#302)
    ///
    /// The listing line is the sentence that tells a player *one thing stands
    /// here*, and this room already lists a hook and a zorkmid: broken three
    /// ways, one balloon reads as three more items. The source says the same
    /// thing twice — `ODESC1` (`dung.355:4339`) is a single string holding all
    /// three facts, printed by one `TELL`, and `LEDGE-FUNCTION`
    /// (`act2.92:745`) splices the Wide Ledge's state clause on with a space
    /// rather than a break. The newlines inside `ODESC1` are 1981 hard wrap at
    /// sixty-odd columns, the typography ``cardText`` already strips.
    ///
    /// Where the literals below break is likewise not where the player sees a
    /// break: `TextWrap` folds a paragraph's soft newlines on both channels.
    static func balloonInPlace(inflated: String?, tied: Bool) -> String {
        let bag =
            if let inflated {
                """
                The cloth bag over it is inflated, and a \(inflated) is burning
                in the metal receptacle fastened amidships.
                """
            } else {
                """
                The cloth bag is draped over the side, and a metal receptacle is
                fastened amidships.
                """
            }
        let wire =
            tied
            ? "A piece of wire tied to a hook holds the balloon in place."
            : "Dangling from the basket is a piece of braided wire."
        return """
            There is a large and extremely heavy wicker basket here. \(bag) \(wire)
            """
    }

    /// One paragraph for ``balloonInPlace``'s reason, and for one more: the
    /// source's own examine channel prints its two clauses as two `TELL`s, and
    /// a `TELL` ends in a bare CRLF (`defs.171:233`) — a line break, never a
    /// blank line. That is 1981 line typography, not a paragraph.
    static func balloonExamined(inflated: String?, tied: Bool) -> String {
        let bag =
            if let inflated {
                """
                The cloth bag is inflated, and a \(inflated) is burning in the
                receptacle.
                """
            } else {
                """
                The cloth bag is draped over the side of the basket. Directly in
                the middle of it is a metal receptacle.
                """
            }
        let wire =
            tied
            ? "The balloon is tied to a hook by the braided wire."
            : "A braided wire is dangling over the side of the basket."
        return "\(bag) \(wire)"
    }

    /// The bag with nothing in it, slack over the side of the basket. Paired
    /// with ``clothBagInflated``: neither sentence is the source's, since
    /// `CBAG` carries no description and `BCONTENTS` (`act2.92:574`) answers
    /// TAKE, FIND and EXAMINE alike with *"part of the basket"*. (#332)
    static let clothBagSlack = """
        A great envelope of oiled cloth, big enough to swallow the basket twice
        over when there is anything in it. At the moment it is slack over the
        side.
        """

    static let clothBagInflated = """
        A great envelope of oiled cloth, swollen taut with hot air and pulling
        hard at the basket beneath it.
        """

    static let receptacle = """
        A shallow metal pan, bolted to the floor of the basket, sized for
        something that will burn.
        """

    static let braidedWire = """
        A length of wire braided from a dozen strands, spliced to the basket at
        one end and free at the other.
        """

    /// Verbatim; the trilogy's `BCONTENTS`.
    static func balloonPartIsFixed(_ part: String) -> String {
        """
        The \(part) is an integral part of the basket and cannot be removed.
        """
    }

    /// The same refusal with a second sentence the bag and the receptacle never
    /// earn: `WIRE-FUNCTION` (`act2.92:587`) offers the wire a verb neither of
    /// them has. One line, with the stem interpolated into it, so `BCONTENTS`'s
    /// wording stays in one place and the hint cannot be handed to the wrong
    /// part.
    static func wireIsFixed(_ wire: String) -> String {
        "\(balloonPartIsFixed(wire)) The wire might possibly be tied, though."
    }

    static let clothBagIsEmpty = "It doesn't appear that there's anything inside."

    /// And what it holds when it is holding the balloon up, which the line
    /// above used to be printed for as well. (#332)
    static let clothBagHotAir = "Hot air, and a great deal of it."

    static let clothBagWontOpen = """
        The bag is enormous. The concept of opening it here is ludicrous.
        """

    static let receptacleOccupied = "The receptacle is already occupied."

    static func wontHoldBurning(_ thing: String) -> String {
        "You don't really want to hold a burning \(thing)."
    }

    static func fuelCatches(_ thing: String) -> String {
        "The \(thing) burns inside the receptacle."
    }

    static let bagInflates = """
        The cloth bag inflates as it fills with hot air. A small label drops
        from the bag into the basket.
        """

    static func fuelBurnsOut(_ thing: String) -> String {
        """
        You notice that the \(thing) has burned out, and that the cloth bag
        starts to deflate.
        """
    }

    static let nothingToBurnWith = "You have nothing to set it alight with."

    static func wontBurn(_ thing: String) -> String {
        "You will get nothing out of \(thing) but a bad smell."
    }

    static let alreadyBurning = "It is burning already."

    /// Verbatim; the trilogy's `WIRE-FCN`.
    static let balloonFastened = "The balloon is fastened to the hook."

    static let wireFallsOff = "The wire falls off of the hook."

    static let wireNotTied = "The wire is not tied to anything."

    static let wireNeedsAHook = "There is nothing here to tie the wire to."

    /// Verbatim; the trilogy's `BALLOON-FCN`.
    static let tiedToTheLedge = "You are tied to the ledge."

    static let cantSteerTheBalloon = "You can't control the balloon this way."

    /// Verbatim; the source's own refusal for stepping out over open air.
    static let disembarkWouldBeFatal = """
        You realize, just in time, that disembarking here would probably be
        fatal.
        """

    static let balloonRises = "The balloon rises slowly from the ground."

    static let balloonAscends = "The balloon ascends."

    static let balloonDescends = "The balloon descends."

    static let balloonLeavesTheLedge = "The balloon leaves the ledge."

    static let balloonHasLanded = "The balloon has landed."

    /// The source builds these four from one sentence and a tail. They are
    /// written out whole instead: a line of prose is one literal, and a tail
    /// spliced onto a stem is the spelling `ProseConventionTests` exists to
    /// keep out. Nothing about the rendering turns on it — `TextWrap` folds a
    /// paragraph's soft newlines on both channels either way.
    static let balloonWatchedLiftingOff = "You watch as the balloon slowly lifts off."

    static let balloonWatchedClimbing = "You watch as the balloon slowly ascends."

    static let balloonWatchedSinking = "You watch as the balloon slowly descends."

    static let balloonWatchedLanding = "You watch as the balloon slowly lands."

    static let balloonWatchedFloatingAway = """
        You watch as the balloon slowly floats away. It seems to be
        ascending, due to its light load.
        """

    /// Adapted from the mainframe's ending rather than the trilogy's. Zork II
    /// flies the balloon out of the volcano and into the Flathead Mountains;
    /// the mainframe tears it on the rim and drops it, and the mainframe is the
    /// authority on what a puzzle does.
    static let balloonHitsTheRim = """
        The balloon reaches the neck of the volcano, where the rim is barely
        fifteen feet across, and the cloth goes over the rock with a sound like
        a sail splitting. The floor of the volcano is five hundred feet down and
        arrives very quickly indeed.
        """

    /// True on the floor of the volcano and nowhere else: the wreck lands at
    /// ``DungeonVolcano/volcanoBottom``, so "by your feet" is a claim about
    /// one of the four rooms that can watch it happen. See
    /// ``balloonExplodesSeenFromLedge`` for the other three. (#329)
    static let balloonExplodesWatched = """
        You watch the balloon strike the rim and come apart; what is left of it
        lands on the ground by your feet.
        """

    /// Watched from a ledge, where the wreck goes past you rather than to you.
    /// This is the line the Wide Ledge needed: the room narrated watching the
    /// balloon float away overhead, and three turns later reported the tearing
    /// as a distant sound, because the branch asked whether the player was on
    /// the floor when it had already been handed `watched`. (#329)
    static let balloonExplodesSeenFromLedge = """
        You watch the balloon strike the rim and come apart, and what is left
        of it falls past the ledge on its way to the floor of the volcano.
        """

    static let balloonExplodesHeard = """
        You hear a distant tearing sound, and a moment later something large
        falls a long way.
        """

    static let brokenBalloonInPlace = "There is a balloon here, broken into pieces."

    static let brokenBalloon = """
        Wicker, torn cloth and a bent metal pan. It will not fly anybody
        anywhere again.
        """

    static let balloonDidNotSurvive = """
        You have landed, but the balloon did not survive.
        """

    /// Adapted, and deliberately the tan label's sentence with one word changed:
    /// the two are the same joke by the same fictional company, and the source
    /// gives them the same `ODESC1` shape. The label drops from the bag the
    /// first time it fills, so the basket is where it is read.
    static let blueLabelInBasket = "A blue label is lying inside the basket."

    /// Verbatim `ODESC1`, an `identical` entry — and the frame it was written
    /// for. The rim tears the bag open and `wreckTheBalloon` tips the basket's
    /// cargo onto the volcano floor, which is the one way this label ends up
    /// lying loose in a room with nobody having touched it.
    static let blueLabelOnGround = "There is a blue label here."

    /// Written fresh. The source's label is 1981 typography; what it tells the
    /// player is the three words the balloon answers to, and that is structure.
    static let blueLabel = """
        A small blue label, printed on one side.
        """

    static let blueLabelText = """
        FROBOZZ MAGIC BALLOON COMPANY

        Hello, Aviator!

        To get in, say BOARD. To get out, say DISEMBARK. To come down on a
        ledge, say LAND.

        Beyond that you are on your own. No warranty is expressed and none is
        implied.
        """

    static let balloonTooHeavy = """
        The basket is far too heavy to lift, which is rather the point of the
        bag over it.
        """

    static let launchNowhereFromHere = "There is nowhere here to launch from."

    static let launchTied = "The wire is still on the hook. Untie it first."

    static let landNoLedge = "There is nowhere here to land."

    // MARK: - The gnome

    /// Verbatim; `GNOME` is `identical`.
    static let gnomeInPlace = "There is a nervous Volcano Gnome here."

    static let gnome = """
        A gnome of the volcano: grey as the rock he walked out of, dressed for
        an office somewhere else, and consulting his watch.
        """

    /// Verbatim; the trilogy's `I-GNOME`.
    static let gnomeArrives = """
        A volcano gnome seems to walk straight out of the wall and says "I have
        a busy appointment schedule and little time to waste on trespassers, but
        for a small fee I'll show you the way out." You notice the gnome
        nervously glancing at his watch.
        """

    /// Written fresh. Both of the gnome's own lines end on his watch — he
    /// arrives *nervously glancing* at it and leaves *glancing* at it — and the
    /// word was not in the game's vocabulary at all. (#332)
    static let gnomeWatch = """
        A pocket watch on a chain, which he consults about twice as often as
        anybody with a real appointment would.
        """

    static let gnomeIsNervous = "The gnome appears increasingly nervous."

    /// Verbatim; the trilogy's `I-NERVOUS`.
    static let gnomeLeaves = """
        The gnome glances at his watch. "Oops. I'm late for an appointment!" He
        disappears, leaving you alone on the ledge.
        """

    /// Written fresh. ``gnomeLeaves`` is trilogy-verbatim and ends *leaving you
    /// alone on the ledge*, which is a claim about where the player is standing
    /// — so it cannot simply be hoisted out of the guard that used to remove him
    /// in silence. This is the same departure from the next room along: heard,
    /// not watched. (#332)
    static let gnomeLeavesHeard = """
        Somewhere off along the rock a small voice says something about an
        appointment, and then there is nobody saying anything at all.
        """

    /// Verbatim; the trilogy's `GNOME-FCN`.
    static func gnomePaid(_ treasure: String) -> String {
        """
        "Thank you very much for the \(treasure). I don't believe I've
        ever seen one as beautiful. Follow me," he says, and a door appears
        on the west end of the ledge. Through the door, you can see a narrow
        chimney sloping steeply downward. The gnome moves quickly, and
        disappears from sight.
        """
    }

    static let gnomeRefusesTheBrick = """
        "That certainly wasn't what I had in mind," he says, and disappears.
        """

    static func gnomeCrunches(_ thing: String) -> String {
        """
        "That wasn't quite what I had in mind," he says, crunching the \(thing)
        in his rock-hard hands.
        """
    }

    static let gnomeDoorShut = """
        The west wall is solid rock, and nothing about it suggests a door.
        """

    static let gnomeChimney = """
        A chimney of rock, barely wide enough for one, sloping down out of sight
        toward the floor of the volcano.
        """

    // MARK: - The brick, the wire and the blast

    /// Verbatim; the trilogy's `OTHER-PROPERTIES`, which is the mainframe's
    /// `BRICK-BOOM` word for word.
    static let brickBoom = """
        Now you've done it. It seems that the brick has other properties than
        weight, namely the ability to blow you to smithereens.
        """

    static let wireStartsToBurn = "The wire starts to burn."

    static let wireBurnsToNothing = "The wire rapidly burns into nothingness."

    static let explosionNearby = "There is an explosion nearby."

    /// Verbatim; the trilogy's `I-SAFE`.
    static let roomCollapsesOnYou = """
        The room trembles and 5000 tons of rock fall on you, turning you into a
        pancake.
        """

    static let ominousRumbling = """
        You may recall that recent explosion. Probably as a result of it, you
        hear an ominous rumbling, as if a nearby room had collapsed.
        """

    static let debrisBlocksTheWay = """
        The way is blocked by debris from an explosion.
        """

    /// Verbatim; the trilogy's `I-LEDGE`.
    static let ledgeCollapsesUnderYou = """
        The force of the recent explosion has caused the ledge to collapse.
        """

    static let ledgeCollapsesTiedOn = """
        The ledge collapses, probably as a result of the explosion, and plummets
        to the ground far below. Sadly, you were still attached to it.
        """

    static let ledgeCollapsesNoLanding = """
        The ledge collapses, leaving you with no place to land.
        """

    static let ledgeCollapsesElsewhere = """
        The ledge collapses. (That was a narrow escape!)
        """

    static let ledgeIsGone = """
        The ledge has collapsed and cannot be landed on.
        """
}
