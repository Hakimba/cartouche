// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.storage

import app.cartouche.core.FilePath
import arrow.core.Option
import arrow.core.getOrNone
import arrow.core.raise.ensure
import arrow.core.raise.option

/** A document id of Android's documents providers, such as `1A2B-3C4D:ROMs/ps2`. */
@JvmInline public value class DocumentId(public val value: String)

/** A storage volume as named in document ids: [VolumeId.PRIMARY] or the volume UUID (`1A2B-3C4D`). */
@JvmInline public value class VolumeId(public val value: String) {
    public companion object {
        public val PRIMARY: VolumeId = VolumeId("primary")
    }
}

/** The storage volume a folder is on, as the user knows it. */
public enum class Volume { INTERNAL, CARD }

/** Where a folder is, as the user reads it: its volume, then the folders down to it (none for the volume itself). */
public data class FolderPlace(public val volume: Volume, public val folders: List<String>)

/**
 * Maps documents of Android's external storage provider to filesystem paths.
 *
 * Folders picked through the system picker are identified by document ids such as `primary:ROMs/ps2`
 * (internal storage) or `1A2B-3C4D:ROMs/ps2` (SD card). Templates using `{file.path}` need the real
 * path (`/storage/1A2B-3C4D/ROMs/ps2`); documents of any other provider (Downloads, cloud storage)
 * have no stable path.
 */
public object DocumentPaths {
    public const val EXTERNAL_STORAGE_AUTHORITY: String = "com.android.externalstorage.documents"

    /** Root exposed by the provider for the primary volume's Documents folder. */
    private const val HOME_ROOT = "home"

    public fun pathOf(authority: String, documentId: DocumentId, volumeRoots: Map<VolumeId, FilePath>): Option<FilePath> = option {
        ensure(authority == EXTERNAL_STORAGE_AUTHORITY)
        val volume = documentId.value.substringBefore(':', missingDelimiterValue = "")
        ensure(volume.isNotEmpty())
        val relative = documentId.value.substringAfter(':')
        val home = volume == HOME_ROOT
        val root = volumeRoots.getOrNone(if (home) VolumeId.PRIMARY else VolumeId(volume)).bind().value + if (home) "/Documents" else ""
        FilePath(if (relative.isEmpty()) root else "$root/$relative")
    }

    /** Where [documentId] of the external storage provider is; none for any other provider. */
    public fun placeOf(authority: String, documentId: DocumentId): Option<FolderPlace> = option {
        ensure(authority == EXTERNAL_STORAGE_AUTHORITY)
        val volume = documentId.value.substringBefore(':', missingDelimiterValue = "")
        ensure(volume.isNotEmpty())
        val relative = documentId.value.substringAfter(':').split('/').filter(String::isNotEmpty)
        when (volume) {
            VolumeId.PRIMARY.value -> FolderPlace(Volume.INTERNAL, relative)
            HOME_ROOT -> FolderPlace(Volume.INTERNAL, listOf("Documents") + relative)
            else -> FolderPlace(Volume.CARD, relative)
        }
    }

    /** Last segment of a document id, used when the provider reports no display name. */
    public fun fallbackName(documentId: DocumentId): String =
        documentId.value.substringAfterLast('/').substringAfterLast(':').ifEmpty { documentId.value }
}
