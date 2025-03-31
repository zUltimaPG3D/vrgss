// vrgss
//
// CLI tool for vrgss
module main

import vrgss
import os

enum ActMode {
	list
	extract
}

fn exec_info(err string) {
	println('usage: vrgss [-h] [-x] [-l] [-v] [RGSS ARCHIVE]\n')
	println('options:')
	println('  -h        show this message and exit')
	println('  -l        list the files from the chosen archive (DEFAULT)')
	println('  -x        extract files from the chosen archive into the current directory')
	println('  -v        enable verbose logging')
	if err != '' {
		println('\nERROR: ${err}')
	}
}

fn main() {
	args := os.args

	if args.len < 2 || args.contains('-h') {
		exec_info('')
		return
	}

	if args.contains('-x') && args.contains('-l') {
		println("ERROR: You can't extract an archive and list its files at the same time!")
		return
	}

	target_files := args.filter(!it.starts_with('-') && it != args[0])
	if target_files.len != 1 {
		if target_files.len == 0 {
			exec_info("You haven't inputted any file name!")
		} else {
			println("ERROR: You're trying to load multiple files! Multi-archive management is not supported yet.")
		}
		return
	}

	verbose := args.contains('-v')

	target_file := target_files[0]
	file_exists := os.exists(target_file)

	if !file_exists {
		exec_info("The passed file doesn't exist!")
		return
	}

	mut archive := vrgss.RGSS2A{}
	archive.initialize(target_file)

	if !archive.valid() {
		println('ERROR: The passed archive file is invalid! Info should be above.')
		return
	}

	act_mode := if args.contains('-x') { ActMode.extract } else { ActMode.list }

	if !archive.parse() {
		println('ERROR: Failed to parse the passed archive file! Info should be above.')
		return
	}

	if act_mode == .list {
		for entry in archive.entries {
			println(entry.name)
		}

		println('INFO: Done listing files.')
		return
	}

	if act_mode == .extract {
		file_ext := os.file_ext(target_file)
		file_name := os.file_name(target_file).all_before_last(file_ext)

		os.mkdir('./${file_name}') or {
			println('ERROR: Failed to create the folder for the export with the name ${file_name}! Reason: ${err}')
			return
		}

		for entry in archive.entries {
			if verbose {
				println('Decrypting file ${entry.name}...')
			}

			full_path := os.join_path('./${file_name}', entry.name)
			full_dir := os.join_path('./${file_name}', os.dir(entry.name))

			os.mkdir_all(full_dir) or {
				println('ERROR: Failed to create the folder for the file ${entry.name}! Reason: ${err}')
				return
			}

			os.write_file_array(full_path, archive.read_entry(entry)) or {
				println('ERROR: Failed to write the file ${entry.name}! Reason: ${err}')
				continue
			}
		}

		println('INFO: Done extracting.')
		return
	}
}
