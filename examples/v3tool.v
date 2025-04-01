module main

import vrgss
import os

fn main() {
	mut archive := vrgss.RGSS3A{}
	archive.initialize("Game.rgss3a")
	archive.parse()
	archive.prepare()

	for entry in archive.entries {
		println(entry.name)
	}

	os.mkdir('./exp') or {
		println('ERROR: Failed to create the folder for the export! Reason: ${err}')
		return
	}

	for entry in archive.entries {
		println('Decrypting file ${entry.name}...')

		full_path := os.join_path('./exp', entry.name)
		full_dir := os.join_path('./exp', os.dir(entry.name))
		
		os.mkdir_all(full_dir) or {
			println('ERROR: Failed to create the folder for the file ${entry.name}! Reason: ${err}')
			return
		}

		os.write_file_array(full_path, entry.data) or {
			println('ERROR: Failed to write the file ${entry.name}! Reason: ${err}')
			continue
		}
	}

	println('INFO: Done extracting.')

	archive.write("GameRewrite.rgss3a")
}