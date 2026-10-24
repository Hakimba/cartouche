# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## The project's files the Studio tests look through.


## The files under [param folder] with one of [param extensions], the folders named in [param left_out] not
## looked into.
static func under(folder: String, extensions: Array[String], left_out: Array[String]) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(folder):
		if file.get_extension() in extensions:
			found.append(folder.path_join(file))
	for sub in DirAccess.get_directories_at(folder):
		if sub not in left_out:
			found.append_array(under(folder.path_join(sub), extensions, left_out))
	return found
