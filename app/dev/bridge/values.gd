# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## The checks and conversions the bridge's commands share on the untyped values a message carries.


static func number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float_of(value))


static func float_of(value: Variant) -> float:
	return value


static func error(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}
