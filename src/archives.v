module vrgss

import os

// Struct that represents an RPG Maker archive file entry.
// <br>
// When reading a file, the data for the entry won't be set by default due to it being a time-consuming operation. If you're sure you want the data on each entry after reading, run `archive.prepare()`.
pub struct Entry {
pub:
	name   string // is the path name of the file in the archive.
	size   u32    // is the size of the file.
mut:
	offset u64    // is the position of the entry in the archive.
	key    u32    // is the decryption key the file starts at.
pub mut:
	data []u8 // is the data of the file.
}

// Struct that represents archives in general.
struct Archive {
pub mut:
	entries []Entry // is the list of entries in the archive.
mut:
	reader      os.File // is the file's reader.
	current_key u32     // is the archive's decryption key during reading.
}

// Struct that represents an RGSSAD archive.
// <br>
// Called `RGSS2A` only for convenience, though RGSSAD (RPG Maker XP) archives work with it.
pub struct RGSS2A {
	Archive
}

// Only defined for readability, as RGSSAD and RGSS2A are the exact same format.
pub type RGSSAD = RGSS2A

// Struct that represents an RGSS3A archive, so an encrypted archive used for any RPG Maker VX Ace game.
// <br>
// Due to the way the archive files are formatted, `archive.write_entry` is not an available function, and as such you will have to prepare all of `entries` first before writing a file, **and** you can't manually write files as easily.
// <br>
// Aside from this difference, `RGSSAD`/`RGSS2A` are the exact same.
pub struct RGSS3A {
	Archive
}