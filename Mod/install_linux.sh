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
  bash install_dst_luajit.sh
  bash install_dst_luajit.sh --game-dir /path/to/dst-dedicated-server
  bash install_dst_luajit.sh --bin-dir /path/to/dst-dedicated-server/bin64

With no arguments, the installer detects common dedicated-server, Steam,
dst-admin-go, mods, and ugc_mods locations automatically.
EOF
}

script_dir="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source_dir="$script_dir/bin64/linux"
bin_dir=""
stage_dir=""
config_tmp=""
game_owner=""

cleanup() {
    if [ -n "$stage_dir" ] && [ -d "$stage_dir" ]; then
        rm -rf -- "$stage_dir"
    fi
    if [ -n "$config_tmp" ] && [ -f "$config_tmp" ]; then
        rm -f -- "$config_tmp"
    fi
}
trap cleanup EXIT

while [ "$#" -gt 0 ]; do
    case "$1" in
        --game-dir)
            [ "$#" -ge 2 ] || fail "--game-dir requires a path"
            bin_dir="${2%/}/bin64"
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

is_game_bin_dir() {
    local candidate="$1"
    local executable

    [ -d "$candidate" ] || return 1
    for executable in \
        dontstarve_dedicated_server_nullrenderer_x64 \
        dontstarve_steam_x64
    do
        if [ -f "$candidate/$executable" ] || [ -f "$candidate/${executable}_1" ]; then
            return 0
        fi
    done
    return 1
}

print_candidate() {
    local candidate="$1"

    if is_game_bin_dir "$candidate"; then
        printf '%s\n' "$candidate"
        return 0
    fi
    return 1
}

detect_bin_dir() {
    local candidate

    case "$script_dir" in
        */steamapps/workshop/content/322330/*)
            candidate="${script_dir%%/steamapps/workshop/content/322330/*}/steamapps/common/Don't Starve Together/bin64"
            print_candidate "$candidate" && return 0
            ;;
        */ugc_mods/*/content/322330/*)
            candidate="${script_dir%%/ugc_mods/*}/bin64"
            print_candidate "$candidate" && return 0
            ;;
        */mods/*)
            candidate="${script_dir%%/mods/*}/bin64"
            print_candidate "$candidate" && return 0
            ;;
    esac

    for candidate in \
        "$HOME/dst-dedicated-server/bin64" \
        "$HOME/server_dst/bin64" \
        "$HOME/.steam/steam/steamapps/common/Don't Starve Together/bin64" \
        "$HOME/.local/share/Steam/steamapps/common/Don't Starve Together/bin64" \
        /app/dst-dedicated-server/bin64 \
        /opt/dst-dedicated-server/bin64 \
        /srv/dst-dedicated-server/bin64
    do
        print_candidate "$candidate" && return 0
    done

    return 1
}

[ -d "$source_dir" ] || fail \
    "release files are missing: $source_dir. Use a packaged Linux Release."
[ -f "$source_dir/lib64/libInjector.so" ] || fail \
    "libInjector.so is missing. Use a packaged Linux Release, not source code or an old Workshop copy."

if [ -z "$bin_dir" ]; then
    bin_dir="$(detect_bin_dir)" || fail \
        "could not locate DST. Re-run with --game-dir or --bin-dir."
fi

[ -d "$bin_dir" ] || fail "game bin64 directory does not exist: $bin_dir"
bin_dir="$(CDPATH='' cd -- "$bin_dir" && pwd -P)"
is_game_bin_dir "$bin_dir" || fail \
    "no supported DST executable was found in $bin_dir"
game_dir="$(dirname -- "$bin_dir")"
game_owner="$(stat -c '%u:%g' "$bin_dir")"

if command -v pgrep >/dev/null 2>&1 && \
    pgrep -f '[d]ontstarve_(steam_x64|dedicated_server_nullrenderer_x64)' >/dev/null 2>&1
then
    fail "DST is still running. Stop every Master/Caves process before installing."
fi

host_glibc="$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{ print $2 }' || true)"
required_glibc="$({
    LC_ALL=C grep -ahoE 'GLIBC_[0-9]+(\.[0-9]+)+' "$source_dir"/lib64/* 2>/dev/null || true
} | sed 's/^GLIBC_//' | sort -Vu | tail -n 1)"

if [ -n "$host_glibc" ] && [ -n "$required_glibc" ]; then
    newest="$(printf '%s\n%s\n' "$host_glibc" "$required_glibc" | sort -V | tail -n 1)"
    if [ "$newest" = "$required_glibc" ] && [ "$host_glibc" != "$required_glibc" ]; then
        fail "package requires GLIBC_$required_glibc, but the host provides GLIBC_$host_glibc. Use the Debian-compatible Release; do not replace libc manually."
    fi
fi

install_mod_files() {
    local mod_dir="$game_dir/mods/DontStarveLuaJIT2"

    if [ "$script_dir" = "$mod_dir" ]; then
        chmod -R u+rwX,go+rX -- "$mod_dir"
        if [ "$(id -u)" -eq 0 ]; then
            chown -R -- "$game_owner" "$mod_dir"
        fi
        info "Using Mod files in: $script_dir"
        return 0
    fi

    case "$mod_dir" in
        "$game_dir/mods/"*) ;;
        *) fail "refusing unsafe Mod destination: $mod_dir" ;;
    esac

    (umask 022; mkdir -p -- "$game_dir/mods")
    chmod 0755 -- "$game_dir/mods"
    if [ "$(id -u)" -eq 0 ]; then
        chown -- "$game_owner" "$game_dir/mods"
    fi
    stage_dir="$(mktemp -d "$game_dir/mods/.DontStarveLuaJIT2.XXXXXX")"
    cp -a -- "$script_dir/." "$stage_dir/"
    chmod -R u+rwX,go+rX -- "$stage_dir"
    if [ "$(id -u)" -eq 0 ]; then
        chown -R -- "$game_owner" "$stage_dir"
    fi
    rm -rf -- "$mod_dir"
    mv -- "$stage_dir" "$mod_dir"
    stage_dir=""
    script_dir="$mod_dir"
    source_dir="$script_dir/bin64/linux"
    info "Installed Mod files into: $mod_dir"
}

install_mod_files

json_escape() {
    local text="$1"

    text="${text//\\/\\\\}"
    text="${text//\"/\\\"}"
    text="${text//$'\n'/\\n}"
    text="${text//$'\r'/\\r}"
    text="${text//$'\t'/\\t}"
    printf '%s' "$text"
}

configure_mod_autoload() {
    local config_dir="$game_dir/data/unsafedata"
    local config_file="$config_dir/luajit_config.json"
    local modmain_path="$script_dir/modmain.lua"
    local escaped_modmain
    local config_backup="$config_file.pre-installer"

    [ -f "$modmain_path" ] || fail "Mod main file is missing: $modmain_path"
    [ ! -d "$config_file" ] || fail "LuaJIT configuration path is a directory: $config_file"

    escaped_modmain="$(json_escape "$modmain_path")"
    (umask 022; mkdir -p -- "$config_dir")
    chmod 0755 -- "$config_dir"
    config_tmp="$(mktemp "$config_dir/.luajit_config.json.XXXXXX")"
    printf '{\n  "modmain_path": "%s",\n  "AlwaysEnableMod": true,\n  "DisableJITWhenServer": false\n}\n' \
        "$escaped_modmain" > "$config_tmp"
    chmod 0644 -- "$config_tmp"
    if [ "$(id -u)" -eq 0 ]; then
        chown -- "$game_owner" "$config_dir" "$config_tmp"
    fi

    if [ -e "$config_file" ] && cmp -s -- "$config_tmp" "$config_file"; then
        rm -f -- "$config_tmp"
        config_tmp=""
        chmod 0644 -- "$config_file"
        if [ "$(id -u)" -eq 0 ]; then
            chown -- "$game_owner" "$config_file"
        fi
        info "Automatic LuaJIT Mod loading is already configured: $config_file"
        return 0
    fi

    if [ -e "$config_file" ] && [ ! -e "$config_backup" ]; then
        cp -a -- "$config_file" "$config_backup"
        info "Backed up existing LuaJIT configuration: $config_backup"
    fi

    mv -f -- "$config_tmp" "$config_file"
    config_tmp=""
    info "Configured automatic LuaJIT Mod loading: $config_file"
}

configure_mod_autoload

info "Installing Linux runtime into: $bin_dir"
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
export LD_PRELOAD="./lib64/libInjector.so\${LD_PRELOAD:+ \$LD_PRELOAD}"
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

[ "$installed" -gt 0 ] || fail \
    "no supported DST executable was found in $bin_dir"

info "Installation completed successfully ($installed launcher(s))."
info "Start DST normally; dst-admin-go needs no path or command changes."
