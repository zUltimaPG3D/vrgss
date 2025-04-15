module vrgss

import os
import term
import encoding.binary

// binary.x_endian_get_u32 method helper
pub fn get_u32(val u32) []u8 {
	$if big_endian {
		return binary.big_endian_get_u32(val)
	} $else $if little_endian {
		return binary.little_endian_get_u32(val)
	} $else { // what?
		return binary.little_endian_get_u32(val)
	}
}

// Decrypts the passed bytes with the starting key and returns them.
// <br>
// Returns a `[]u8`.
fn decrypt_bytes(bytes []u8, key u32) []u8 {
	mut temp_bytes := bytes.clone()

	mut temp_key := key
	mut j := u8(0)
	mut key_bytes := get_u32(temp_key)

	for i := u64(0); i < bytes.len; i++ {
		if j == 4 {
			j = 0
			temp_key = temp_key * 7 + 3
			key_bytes = get_u32(temp_key)
		}

		temp_bytes[i] ^= key_bytes[j]

		j++
	}

	return temp_bytes
}

// Replaces all forward slashes with backslashes to imitate Windows paths.
pub fn fix_name(name string) string {
	return name.replace('/', '\\')
}

// Initializes the archive's reader.
// <br>
// Returns `true` if the reader was initialized correctly, otherwise returns `false`.
pub fn (mut archive Archive) initialize(path string) bool {
	archive.reader = os.open(path) or {
		eprintln("${term.red('[ERROR]')} couldn't open file! ${err}")
		return false
	}

	return true
}

// Returns the entry that has the passed name.
// <br>
// Returns `?Entry`, where the result is `none` if there is no entry called `name`.
pub fn (mut archive Archive) get_entry(name string) ?Entry {
	for entry in archive.entries {
		if entry.name == fix_name(name) {
			return entry
		}
	}
	return none
}

// Checks if the archive has an entry that has the name passed in the argument.
// <br>
// Returns `true` if the entry exists, otherwise returns `false`.
pub fn (mut archive Archive) has_entry(name string) bool {
	for entry in archive.entries {
		if entry.name == fix_name(name) {
			return true
		}
	}
	return false
}

// Reads a file in the archive, using its position, length and the key it starts with.
// <br>
// Internally, all this does is call `decrypt_bytes` with data dynamically read from the file.
// <br>
// Returns a `[]u8` with all the decrypted bytes of the read file.
fn (mut archive Archive) read_data(pos u64, len u32, key u32) []u8 {
	bytes := archive.reader.read_bytes_at(int(len), pos)

	return decrypt_bytes(bytes, key)
}

// Reads the file associated with the passed entry.
// <br>
// Internally, all this does is call `archive.read_data` with the data from the entry.
// <br>
// Returns a `[]u8` with all the decrypted bytes of the read file.
pub fn (mut archive Archive) read_entry(entry Entry) []u8 {
	pos := entry.offset
	len := entry.size
	key := entry.key

	return archive.read_data(pos, len, key)
}

// Updates every read entry to set the `data` field on each one.
// <br>
// **This is a time-consuming operation and you shouldn't use this unless you're sure you want to, or if you need to set every entry's data for writing!**
pub fn (mut archive Archive) prepare() {
	for mut entry in archive.entries {
		entry.data = archive.read_entry(entry)
	}
}