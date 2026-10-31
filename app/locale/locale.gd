# SPDX-License-Identifier: GPL-3.0-or-later
class_name Locale
extends RefCounted
## The language the app's text is written in: the one chosen in the settings, else the device's own.

## Each language Cartouche speaks, named in itself, by the code the plugin sends.
const NAMES := {
	"en": "English",
	"fr": "Français",
	"de": "Deutsch",
	"es": "Español",
	"it": "Italiano",
	"pt": "Português (Portugal)",
	"pt_BR": "Português (Brasil)",
	"ja": "日本語",
}


## How the settings name [param code], one of [constant NAMES] or empty for the device's own.
static func name_of(code: String) -> String:
	return NAMES.get(code, code) if code else TranslationServer.translate("Device language")


## Writes the app's text in [param code] (empty: the device's own language).
static func apply(code: String) -> void:
	TranslationServer.set_locale(code if code else OS.get_locale())
	Diagnostics.trace("locale", TranslationServer.get_locale())
