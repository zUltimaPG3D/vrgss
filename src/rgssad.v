module vrgss

import term
import os

// Checks if the archive is a valid RGSSAD archive file.
// <br>
// You should check this before running `archive.parse()` if you want to handle invalid archives on your own.
// <br>
// Returns `true` if the file is valid, otherwise returns `false`.
pub fn (mut archive RGSS2A) valid() bool {
	archive.reader.seek(0, os.SeekMode.start) or {
		eprintln('${term.red('[ERROR]')} error while jumping to the start of the file! ${err}')
		return false
	}

	magic := archive.reader.read_bytes(7)
	if magic.bytestr() != 'RGSSAD\0' {
		eprintln("${term.red('[ERROR]')} selected archive magic isn't valid!")
		return false
	}

	version := archive.reader.read_le[u8]() or {
		eprintln('${term.red('[ERROR]')} error while reading version byte! ${err}')
		return false
	}

	if version != 1 {
		eprintln('${term.red('[ERROR]')} selected archive version is incorrect! got ${version}, expected 1')
		return false
	}

	return true
}

// "Steps" the reader's current decryption key, by multiplying it by 7 and adding 3.
fn (mut archive RGSS2A) step_key() {
	archive.current_key = archive.current_key * 7 + 3
}

// Helper function to get the current key and step it.
fn (mut archive RGSS2A) get_key() u32 {
	key := archive.current_key
	archive.step_key()
	return key
}

// Decrypts the passed string and returns it.
// <br>
// This is different from `archive.decrypt_string` because it doesn't read the string from the file itself.
// <br>
// Returns a `string`.
fn (mut archive RGSS2A) decrypt_string_internal(str string) string {
	mut bytes := str.bytes()

	for i, _ in bytes {
		bytes[i] ^= u8(archive.get_key() & 0xFF)
	}

	return bytes.bytestr()
}

// Decrypts a string and returns it.
// <br>
// Returns a `string`.
fn (mut archive RGSS2A) decrypt_string(len int) string {
	pos := u64(archive.reader.tell() or {
		eprintln('${term.red('[ERROR]')} error while getting current position! ${err}')
		exit(1)
	})

	mut bytes := archive.reader.read_bytes_at(len, pos)

	return archive.decrypt_string_internal(bytes.bytestr())
}

// Parses the RGSSAD archive file.
// <br>
// Returns `true` if the file was parsed to the end correctly, otherwise returns `false`.
pub fn (mut archive RGSS2A) parse() bool {
	archive.current_key = 0xDEADCAFE

	if !archive.valid() {
		eprintln("${term.red('[ERROR]')} the archive isn't valid!")
		return false
	}

	archive.reader.seek(8, os.SeekMode.start) or {
		eprintln('${term.red('[ERROR]')} error while jumping to the start of the file! ${err}')
		return false
	}

	for {
		if archive.reader.eof() {
			break
		}

		name_len := archive.reader.read_le[u32]() or {
			if archive.reader.eof() {
				return true
			}

			eprintln('${term.red('[ERROR]')} error while reading name length! ${err}')
			return false
		} ^ archive.get_key()

		name := archive.decrypt_string(int(name_len))

		file_size := archive.reader.read_le[u32]() or {
			eprintln("${term.red('[ERROR]')} error while reading file size for file '${name}'! ${err}")
			return false
		} ^ archive.get_key()

		off := archive.reader.tell() or {
			eprintln('${term.red('[ERROR]')} error while getting current position! ${err}')
			return false
		}

		entry := Entry{
			size:   file_size
			key:    archive.current_key
			name:   name
			offset: u64(off)
		}
		archive.entries << entry

		archive.reader.seek(file_size, os.SeekMode.current) or {
			eprintln('${term.red('[ERROR]')} error while skipping to next file! ${err}')
			return false
		}
	}

	return true
}

// Writes an entry to the file.
// <br>
// Entry names are fixed automatically, so forward slashes will always be replaced with backslashes.
// <br>
// Returns `true` if the file was written to the archive successfully, otherwise returns `false`.
pub fn (mut archive RGSS2A) write_entry(entry Entry) bool {
	name_len := u32(entry.name.len) ^ archive.get_key()

	archive.reader.write_le[u32](name_len) or {
		eprintln('${term.red('[ERROR]')} error while writing the file name length for ${entry.name}! ${err}')
		return false
	}

	fixed_name := fix_name(entry.name)
	archive.reader.write_string(archive.decrypt_string_internal(fixed_name)) or {
		eprintln('${term.red('[ERROR]')} error while writing the file name for ${entry.name}! ${err}')
		return false
	}

	file_size := u32(entry.data.len) ^ archive.get_key()

	archive.reader.write_le[u32](file_size) or {
		eprintln('${term.red('[ERROR]')} error while writing the file size for ${entry.name}! ${err}')
		return false
	}

	archive.reader.write(decrypt_bytes(entry.data, archive.current_key)) or {
		eprintln('${term.red('[ERROR]')} error while writing the file bytes of ${entry.name}! ${err}')
		return false
	}

	return true
}

// Writes the current archive to the defined path.
// <br>
// Returns `true` if the archive was successfully created, otherwise returns `false`.
pub fn (mut archive RGSS2A) write(path string) bool {
	archive.reader = os.open_file(path, 'wb') or {
		eprintln("${term.red('[ERROR]')} couldn't open file! ${err}")
		return false
	}

	archive.current_key = 0xDEADCAFE

	archive.reader.write_string('RGSSAD\0\1') or {
		eprintln('${term.red('[ERROR]')} error while writing magic! ${err}')
		return false
	}

	for entry in archive.entries {
		if entry.data.len <= 0 {
			eprintln('${term.yellow('[WARN]')} skipping entry for file ${entry.name} because it has no data attached to it.')
			continue
		}
		archive.write_entry(entry)
	}

	return true
}
