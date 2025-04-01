# vrgss
Module for V that lets you read and write to RPG Maker's RGSS archives.

## RPG Maker Support
| RPG Maker Version  | Supported?              |
| ------------------ | ---------------------   |
| RPG Maker 95       | Doesn't use archives(?) |
| RPG Maker 2000     | Doesn't use archives(?) |
| RPG Maker 2003     | Doesn't use archives(?) |
| RPG Maker XP       | Yes                     |
| RPG Maker VX       | Yes                     |
| RPG Maker VX Ace   | No (planned)            |
| RPG Maker MV       | No                      |
| RPG Maker MZ       | No                      |

# Installation
```sh
v install https://github.com/zUltimaPG3D/vrgss
```

# Usage
## Reading
```v
module main
import vrgss

// list all files in a defined v2 archive file
fn main() {
    mut archive := vrgss.RGSS2A{}
    archive.initialize("Game.rgss2a")
    archive.parse()

    for entry in archive.entries {
        println("${entry.name}")
    }
}
```

## Writing (rewriting the same file)
```v
module main
import vrgss

fn main() {
    mut archive := vrgss.RGSS2A{}
    archive.initialize("Game.rgss2a")
    archive.parse()
    archive.prepare()

    archive.write("GameRewrite.rgss2a")
}
```
`Game.rgss2a` and `GameRewrite.rgss2a` will have the same hashes.

## Writing
```v
fn main() {
    mut archive := vrgss.RGSS2A{}
    
    temp_entry := vrgss.Entry{
        name: "Data/test.txt"
        data: "Hello, RPG Maker!".bytes()
    }
    archive.entries << temp_entry
    
    archive.write("GameRewrite.rgss2a")
}
```