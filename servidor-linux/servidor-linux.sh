#!/bin/sh
echo -ne '\033c\033]0;game-godot-platformer-io\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/servidor-linux.x86_64" "$@"
