# RomM in Cartouche: what the player can count on (agreed behaviour, draft for the guide)

**Status:** decided with the maintainer, nothing implemented. Each rule below is a promise the player must be told
plainly, in the RomM guide and, where it applies, on screen. Technical background:
[remote-catalogue-plan.md](remote-catalogue-plan.md). Checked against RomM 5.4.1 (and the 5.5 development branch).

## Connecting

- Cartouche connects with a code: it shows a short code, the player approves it on RomM's web page. No password is
  typed on the handheld.
- The access key RomM returns is kept encrypted on the device, sent only to that server, and shown nowhere.
- Any RomM account works, not only the server's administrator. Each account has its own saves and play time; the games
  are the same for everyone.
- If the server refuses the key later, Cartouche says "to pair again" and keeps showing the games it knew.

## The games of the server

- Every console of the server that holds at least one game is listed. Consoles Cartouche does not support yet, and
  supported consoles the player has not added, are shown greyed, each with its own message.
- If the server has two folders for one console (for example `genesis` and `megadrive`), Cartouche shows one console.
- Covers come from RomM, which fetches them itself with the sources its owner configured. Cartouche asks nothing else
  on the internet for them. A game without a cover on the server shows the console's plain box.

## Downloads

- A game is written into the console's own folder, the one the player already uses, after the player allowed
  Cartouche to write there (asked once per console).
- A game in several files arrives as a sub-folder, file by file; a stopped download resumes where it stopped.
- A game only appears on the shelf once every file has arrived and been checked. A half-downloaded file is never a
  game.
- Cartouche never overwrites, renames or deletes a file it did not create.
- BIOS files the server holds can be fetched the same way, into the place the emulator reads them from.

## Saves

### When they move

- When the shelf stops on a game, Cartouche quietly checks its save with the server, so pressing A does not wait.
- When the player comes back from a game, the save is sent once it stops changing. Every return to Cartouche and every
  launch checks again the games played last, so a save the emulator wrote late is still sent.
- Without network the game starts with the save on the handheld, marked "not synced"; it is sent when the network
  comes back.
- Play time and "last played" are sent to RomM.

### When both sides changed: a conflict

- A conflict exists only when the same game was played on two devices without a sync in between (for example
  offline on the handheld while the PC sent its own progress). Playing different games on different devices is never
  a conflict.
- Cartouche decides this itself, from what it last synced; it never trusts the devices' clocks.
- The player sees both saves with their device, date and play time, and picks one.
- Pressing A without choosing plays this handheld's save. The other one is not deleted: it stays on the server and can
  be restored.

### Nothing is ever lost

- Before replacing a save, Cartouche keeps a copy of the old one on the handheld.
- RomM keeps the last 50 versions of each game's save; every one can be restored from the game's card.

### Memory cards (PS1, PS2)

- A memory card holding many games is synced game by game: a game played on the handheld and another on the PC end up
  on both devices, with no question asked. A question comes only when the same game changed on both sides.
- Cartouche writes into a card only while the emulator is closed, keeps a copy of the card first, checks the card
  afterwards and puts the copy back if anything is wrong.

### Saves deleted on RomM's web page

- Deleting the newest save of a game on the web page is read as going back: the handheld takes the previous version
  (its own copy is kept aside).
- Deleting every save of a game is respected: the handheld keeps its save but does not send it back, until the game is
  played again.

### Saves made by another emulator

- A game may be played elsewhere, for example in RomM's browser player or on a PC. When the save format is the same or
  can be converted (Game Boy, Game Boy Advance, NES, SNES, Mega Drive, Master System, PlayStation; a conversion for
  Nintendo 64 and DS), Cartouche converts it.
- When it cannot, it overwrites nothing: the game's card says which emulator made the save and that this emulator
  cannot read it; the save stays on the server.

### Emulators

- The settings list each emulator as "synced", "one folder to choose" or "cannot be synced", with the reason.
- An emulator that keeps its saves where no other app may read them cannot be synced; Cartouche says so and suggests
  one that can (an advanced option may come later).
- RetroArch can sync itself with RomM; Cartouche syncs RetroArch's folder itself, so the two must not both be turned
  on. The settings say which one is active.
- Save states (quick saves) are not synced; only the game's own saves are.
