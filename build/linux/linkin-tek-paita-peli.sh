#!/bin/sh
printf '\033c\033]0;%s\a' Linkin TEK-paita peli
base_path="$(dirname "$(realpath "$0")")"
"$base_path/linkin-tek-paita-peli.x86_64" "$@"
