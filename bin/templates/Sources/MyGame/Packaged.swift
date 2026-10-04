import Gnusto

/// Creates a fresh game for a front end without exposing the concrete game type.
public let game = PackagedGame { MyGame() }
