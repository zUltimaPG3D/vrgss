module vrgss

import term
import os
import encoding.binary
import rand

// Initializes the archive's reader.
// <br>
// Returns `true` if the reader was initialized correctly, otherwise returns `false`.
pub fn (mut archive RGSS3A) initialize(path string) bool {
	archive.reader = os.open(path) or {
		eprintln("${term.red('[ERROR]')} couldn't open file! ${err}")
		return false
	}

	return true
}

// Checks if the archive is a valid RGSS3A archive file.
// <br>
// You should check this before running `archive.parse()` if you want to handle invalid archives on your own.
// <br>
// Returns `true` if the file is valid, otherwise returns `false`.
pub fn (mut archive RGSS3A) valid() bool {
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

	if version != 3 {
		eprintln('${term.red('[ERROR]')} selected archive version is incorrect! got ${version}, expected 1')
		return false
	}

	return true
}

// Decrypts the passed string and returns it.
// <br>
// This is different from `archive.decrypt_string` because it doesn't read the string from the file itself.
// <br>
// Returns a `string`.
fn (mut archive RGSS3A) decrypt_string_internal(str string) string {
	mut temp_bytes := str.bytes()

	mut temp_key := archive.current_key
	mut j := u8(0)
	mut key_bytes := binary.little_endian_get_u32(temp_key)

	for i := u64(0); i < temp_bytes.len; i++ {
		if j == 4 {
			j = 0
		}

		temp_bytes[i] ^= key_bytes[j]

		j++
	}

	return temp_bytes.bytestr()
}

// Decrypts a string and returns it.
// <br>
// Returns a `string`.
fn (mut archive RGSS3A) decrypt_string(len int) string {
	pos := u64(archive.reader.tell() or {
		eprintln('${term.red('[ERROR]')} error while getting current position! ${err}')
		exit(1)
	})

	mut bytes := archive.reader.read_bytes_at(len, pos)

	return archive.decrypt_string_internal(bytes.bytestr())
}

// Reads a file in the archive, using its position, length and the key it starts with.
// <br>
// Internally, all this does is call `decrypt_bytes` with data dynamically read from the file.
// <br>
// Returns a `[]u8` with all the decrypted bytes of the read file.
fn (mut archive RGSS3A) read_data(pos u64, len u32, key u32) []u8 {
	bytes := archive.reader.read_bytes_at(int(len), pos)

	return decrypt_bytes(bytes, key)
}

// Reads the file associated with the passed entry.
// <br>
// Internally, all this does is call `archive.read_data` with the data from the entry.
// <br>
// Returns a `[]u8` with all the decrypted bytes of the read file.
pub fn (mut archive RGSS3A) read_entry(entry Entry) []u8 {
	pos := entry.offset
	len := entry.size
	key := entry.key

	return archive.read_data(pos, len, key)
}

// Parses the RGSS3A archive file.
// <br>
// Returns `true` if the file was parsed to the end correctly, otherwise returns `false`.
pub fn (mut archive RGSS3A) parse() bool {
	if !archive.valid() {
		eprintln("${term.white('[INFO]')} the archive isn't valid!")
		return false
	}

	archive.reader.seek(8, os.SeekMode.start) or {
		eprintln('${term.red('[ERROR]')} error while jumping to the start of the file! ${err}')
		return false
	}

	archive.current_key = archive.reader.read_le[u32]() or {
		eprintln('${term.red('[ERROR]')} error while getting file decryption key! ${err}')
		return false
	} * 9 + 3

	for {
		if archive.reader.eof() {
			break
		}

		off := archive.reader.read_le[u32]() or {
			if archive.reader.eof() {
				return true
			}

			eprintln('${term.red('[ERROR]')} error while reading file offset! ${err}')
			return false
		} ^ archive.current_key

		file_size := archive.reader.read_le[u32]() or {
			eprintln("${term.red('[ERROR]')} error while reading file size! ${err}")
			return false
		} ^ archive.current_key

		file_key := archive.reader.read_le[u32]() or {
			eprintln("${term.red('[ERROR]')} error while reading file key! ${err}")
			return false
		} ^ archive.current_key

		name_len := archive.reader.read_le[u32]() or {
			if archive.reader.eof() {
				return true
			}

			eprintln('${term.red('[ERROR]')} error while reading name length! ${err}')
			return false
		} ^ archive.current_key

		if off == 0 {
			return true
		}

		name := archive.decrypt_string(int(name_len))

		entry := Entry{
			size:   file_size
			key:    file_key
			name:   name
			offset: u64(off)
		}
		archive.entries << entry
	}

	return true
}

// Updates every read entry to set the `data` field on each one.
// <br>
// **This is a time-consuming operation and you shouldn't use this unless you're sure you want to, or if you need to set every entry's data for writing!**
pub fn (mut archive RGSS3A) prepare() {
	for mut entry in archive.entries {
		entry.data = archive.read_entry(entry)
	}
}

// Writes the current archive to the defined path.
// <br>
// Returns `true` if the archive was successfully created, otherwise returns `false`.
pub fn (mut archive RGSS3A) write(path string) bool {
	archive.reader = os.open_file(path, 'wb') or {
		eprintln("${term.red('[ERROR]')} couldn't open file! ${err}")
		return false
	}

	if archive.current_key == 0 {
		archive.current_key = 9 * rand.u16() + 3
	}

	archive.reader.write_string('RGSSAD\0\3') or {
		eprintln('${term.red('[ERROR]')} error while writing magic! ${err}')
		return false
	}

	archive.reader.write_le[u32]((archive.current_key - 3) / 9) or {
		eprintln('${term.red('[ERROR]')} error while writing the archive decryption key! ${err}')
		return false
	}

	mut pos := u64(12) // RGSSAD\0\3 + archive key
	
	// Preparing
	for entry in archive.entries {
		// offset + size + key + name_len + name
		pos += 4 + 4 + 4 + 4 + u64(entry.name.len)
	}

	pos += 4 + 4 + 4 + 4 // the empty entry

	// Writing file metadata
	for mut entry in archive.entries {
		if entry.data.len <= 0 {
			eprintln('${term.yellow('[WARN]')} skipping entry for file ${entry.name} because it has no data attached to it.')
			continue
		}

		entry.offset = pos
		if entry.key == 0 {
			entry.key = rand.u16()
		}

		off := u32(entry.offset) ^ archive.current_key
		size := u32(entry.data.len) ^ archive.current_key
		key := u32(entry.key) ^ archive.current_key
		name_len := u32(entry.name.len) ^ archive.current_key

		archive.reader.write_le[u32](off) or {
			eprintln('${term.red('[ERROR]')} error while writing the file offset for ${entry.name}! ${err}')
			return false
		}

		archive.reader.write_le[u32](size) or {
			eprintln('${term.red('[ERROR]')} error while writing the file size for ${entry.name}! ${err}')
			return false
		}

		archive.reader.write_le[u32](key) or {
			eprintln('${term.red('[ERROR]')} error while writing the file decryption key for ${entry.name}! ${err}')
			return false
		}

		archive.reader.write_le[u32](name_len) or {
			eprintln('${term.red('[ERROR]')} error while writing the file name length ${entry.name}! ${err}')
			return false
		}
		
		fixed_name := fix_name(entry.name)
		archive.reader.write_string(archive.decrypt_string_internal(fixed_name)) or {
			eprintln('${term.red('[ERROR]')} error while writing the file name for ${entry.name}! ${err}')
			return false
		}

		pos += u64(entry.data.len)
	}

	archive.reader.write_le[u32](0 ^ archive.current_key) or {
		eprintln('${term.red('[ERROR]')} error while writing the empty offset after every file! ${err}')
		return false
	}

	archive.reader.write_le[u32](110850 ^ archive.current_key) or {
		eprintln('${term.red('[ERROR]')} error while writing the empty file size after every file! ${err}')
		return false
	}

	archive.reader.write_le[u32](112357 ^ archive.current_key) or {
		eprintln('${term.red('[ERROR]')} error while writing the empty file key after every file! ${err}')
		return false
	}

	archive.reader.write_le[u32](122206 ^ archive.current_key) or {
		eprintln('${term.red('[ERROR]')} error while writing the empty filename length after every file! ${err}')
		return false
	}

	// Actually writing the files
	for entry in archive.entries {
		if entry.data.len <= 0 {
			eprintln('${term.yellow('[WARN]')} skipping entry for file ${entry.name} because it has no data attached to it.')
			continue
		}

		archive.reader.write(decrypt_bytes(entry.data, entry.key)) or {
			eprintln('${term.red('[ERROR]')} error while writing the file bytes of ${entry.name}! ${err}')
			return false
		}
	}

	return true
}
