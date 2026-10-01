// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.storage

import android.util.AtomicFile
import app.cartouche.core.settings.Settings
import app.cartouche.core.settings.SettingsFormat
import app.cartouche.core.settings.SettingsUnreadable
import arrow.core.Either
import java.io.File

/** The settings file in the app's private storage, written through [AtomicFile] like the library. */
internal class SettingsStore(file: File) {
    private val atomic = AtomicFile(file)

    /** The stored settings, or none set when nothing was stored yet. */
    fun load(): Either<SettingsUnreadable, Settings> = atomic.read(Settings(), ::SettingsUnreadable, SettingsFormat::decode)

    fun save(settings: Settings): Either<StorageFailure, Unit> = atomic.write(SettingsFormat.encode(settings))
}
