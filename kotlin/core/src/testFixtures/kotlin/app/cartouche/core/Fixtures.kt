// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core

import arrow.core.getOrElse

/** A content URI written by hand in a test. */
fun uri(text: String): ContentUri = ContentUri.parse(text).getOrElse { error("Not a content URI: $text") }
