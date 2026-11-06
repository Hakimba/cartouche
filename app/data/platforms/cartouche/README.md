Platform and emulator ("player") definitions written for Cartouche, in the Daijishō format of
`../daijishou/`: for platforms Daijishō has no definition of, for the Switch, whose Daijishō definition lists
emulators no longer maintained and takes a game's content files (`.nca`, `.nso`) for games, and for the Mega Drive,
which Cartouche names by its PAL name where Daijishō uses the American one (Genesis). They are read together with
`../daijishou/`; a file named like one of it replaces it (`SegaGenesis.json`) and keeps its platform id and players,
so libraries and stored choices stay valid. Any other file name or platform id must not repeat one of it.
