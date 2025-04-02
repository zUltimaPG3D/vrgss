module vrgss

import encoding.binary

// Decrypts the passed bytes with the starting key and returns them.
// <br>
// Returns a `[]u8`.
fn decrypt_bytes(bytes []u8, key u32) []u8 {
	mut temp_bytes := bytes.clone()

	mut temp_key := key
	mut j := u8(0)
	mut key_bytes := binary.little_endian_get_u32(temp_key)

	for i := u64(0); i < bytes.len; i++ {
		if j == 4 {
			j = 0
			temp_key = temp_key * 7 + 3
			key_bytes = binary.little_endian_get_u32(temp_key)
		}

		temp_bytes[i] ^= key_bytes[j]

		j++
	}

	return temp_bytes
}

// Replaces all forward slashes with backslashes to imitate Windows paths.
fn fix_name(name string) string {
	return name.replace('/', '\\')
}