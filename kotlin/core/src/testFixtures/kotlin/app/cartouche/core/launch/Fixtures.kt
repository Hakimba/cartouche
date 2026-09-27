// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.launch

import app.cartouche.core.FileName
import app.cartouche.core.FilePath
import app.cartouche.core.uri
import arrow.core.Some

/** The game's URI, as the generated templates also write it by hand. */
const val GAME_URI: String = "content://com.android.externalstorage.documents/tree/1A2B-3C4D%3AROMs%2Fps2/document/game"

/** A game on an SD card, with a filesystem path. */
val sdGame: GameFile =
    GameFile(
        FileName("Burnout 3 - Takedown (Europe).chd"),
        uri(GAME_URI),
        Some(FilePath("/storage/1A2B-3C4D/ROMs/ps2/Burnout 3 - Takedown (Europe).chd")),
    )

/** The same game under another URI. */
val otherGame: GameFile = sdGame.copy(uri = uri("$GAME_URI-other"))
