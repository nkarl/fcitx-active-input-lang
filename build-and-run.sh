#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_file="$script_dir/fcitx-state-monitor.c"
binary="$script_dir/fcitx-state-monitor"
compiler=${CC:-cc}

if ! command -v pkg-config >/dev/null 2>&1; then
    echo "error: pkg-config is required to build fcitx-state-monitor" >&2
    exit 1
fi

if ! pkg-config --exists libsystemd; then
    echo "error: libsystemd development files are required" >&2
    exit 1
fi

read -r -a cflags <<< "${CFLAGS:--O2 -Wall -Wextra}"
read -r -a systemd_flags <<< "$(pkg-config --cflags --libs libsystemd)"

if [[ ! -x "$binary" || "$source_file" -nt "$binary" ]]; then
    temporary_binary=$(mktemp "$script_dir/.fcitx-state-monitor.XXXXXX")
    trap 'rm -f -- "$temporary_binary"' EXIT
    "$compiler" "${cflags[@]}" "$source_file" -o "$temporary_binary" "${systemd_flags[@]}"
    chmod +x "$temporary_binary"
    mv -f -- "$temporary_binary" "$binary"
    trap - EXIT
fi

exec "$binary" "$@"
