#!/usr/bin/env bash

set -Eeuo pipefail

info() {
    printf '[INFO] %s\n' "$*"
}

fail() {
    printf '[ERROR] %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage:
  ./install_linux.sh
  ./install_linux.sh --game-dir "/path/to/Don't Starve Together"
  ./install_linux.sh --bin-dir "/path/to/Don't Starve Together/bin64"

The automatic mode supports mods installed below the game's mods directory,
Steam Workshop, and the default Steam or dedicated-server locations.
EOF
}

script_dir="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source_dir="$script_dir/bin64/linux"
bin_dir=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --game-dir)
            [ "$#" -ge 2 ] || fail "--game-dir requires a path"
            bin_dir="$2/bin64"
            shift 2
            ;;
        --bin-dir)
            [ "$#" -ge 2 ] || fail "--bin-dir requires a path"
            bin_dir="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "unknown argument: $1 (use --help for usage)"
            ;;
    esac
done

detect_bin_dir() {
    local candidate

    case "$script_dir" in
        */steamapps/workshop/content/322330/*)
            candidate="${script_dir%%/steamapps/workshop/content/322330/*}/steamapps/common/Don't Starve Together/bin64"
            if [ -d "$candidate" ]; then
                printf '%s\n' "$candidate"
                return 0
            fi
            ;;
        */mods/*)
            candidate="${script_dir%%/mods/*}/bin64"
            if [ -d "$candidate" ]; then
                printf '%s\n' "$candidate"
                return 0
            fi
            ;;
    esac

    for candidate in \
        "$HOME/.steam/steam/steamapps/common/Don't Starve Together/bin64" \
        "$HOME/.local/share/Steam/steamapps/common/Don't Starve Together/bin64" \
        "$HOME/server_dst/bin64"
    do
        if [ -d "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

if [ -z "$bin_dir" ]; then
    bin_dir="$(detect_bin_dir)" || fail \
        "could not locate the game. Re-run with --game-dir or --bin-dir."
fi

[ -d "$source_dir" ] || fail "release files are missing: $source_dir"
[ -f "$source_dir/lib64/libInjector.so" ] || fail \
    "libInjector.so is missing. Use a packaged Linux release or build the install target first."
[ -d "$bin_dir" ] || fail "game bin64 directory does not exist: $bin_dir"

bin_dir="$(CDPATH='' cd -- "$bin_dir" && pwd -P)"

host_glibc="$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{ print $2 }' || true)"
required_glibc="$({
    LC_ALL=C grep -ahoE 'GLIBC_[0-9]+(\.[0-9]+)+' "$source_dir"/lib64/* 2>/dev/null || true
} | sed 's/^GLIBC_//' | sort -Vu | tail -n 1)"

if [ -n "$host_glibc" ] && [ -n "$required_glibc" ]; then
    newest="$(printf '%s\n%s\n' "$host_glibc" "$required_glibc" | sort -V | tail -n 1)"
    if [ "$newest" = "$required_glibc" ] && [ "$host_glibc" != "$required_glibc" ]; then
        fail "this package requires GLIBC_$required_glibc, but the host provides GLIBC_$host_glibc. Use the Debian-compatible release; do not replace Debian's libc manually."
    fi
fi

info "Installing Linux files into: $bin_dir"
cp -a -- "$source_dir/." "$bin_dir/"

is_elf() {
    [ "$(od -An -tx1 -N4 "$1" 2>/dev/null | tr -d '[:space:]')" = "7f454c46" ]
}

write_launcher() {
    local name="$1"
    local launcher="$bin_dir/$name"
    local original="$bin_dir/${name}_1"

    if [ -f "$launcher" ] && is_elf "$launcher"; then
        mv -f -- "$launcher" "$original"
        info "Backed up the game executable as ${name}_1"
    elif [ -f "$launcher" ] && grep -q '^# DontStarveLuaJIT launcher$' "$launcher"; then
        [ -f "$original" ] || fail "launcher backup is missing: $original"
    elif [ -f "$launcher" ] && head -n 1 "$launcher" | grep -q '^#!' && [ -f "$original" ]; then
        info "Updating an existing launcher: $name"
    elif [ ! -f "$launcher" ] && [ -f "$original" ]; then
        info "Restoring launcher for existing backup: ${name}_1"
    elif [ ! -f "$launcher" ]; then
        return 1
    else
        fail "refusing to replace an unknown launcher: $launcher"
    fi

    cat > "$launcher" <<EOF
#!/usr/bin/env bash
# DontStarveLuaJIT launcher
set -e
SCRIPT_DIR="\$(CDPATH='' cd -- "\$(dirname -- "\$0")" && pwd -P)"
cd "\$SCRIPT_DIR"
export LD_LIBRARY_PATH="\$SCRIPT_DIR/lib64\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
export LD_PRELOAD="\$SCRIPT_DIR/lib64/libInjector.so\${LD_PRELOAD:+ \$LD_PRELOAD}"
exec "\$SCRIPT_DIR/${name}_1" "\$@"
EOF

    chmod +x -- "$launcher" "$original"
    return 0
}

installed=0
for executable in \
    dontstarve_steam_x64 \
    dontstarve_dedicated_server_nullrenderer_x64
do
    if write_launcher "$executable"; then
        installed=$((installed + 1))
    fi
done

[ "$installed" -gt 0 ] || fail "no supported Don't Starve Together executable was found in $bin_dir"

info "Installation completed successfully ($installed launcher(s) installed)."
