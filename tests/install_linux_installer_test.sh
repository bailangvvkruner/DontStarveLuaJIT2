#!/usr/bin/env bash

set -Eeuo pipefail

repo_root="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT

release_mod="$tmp_dir/release/Mod"
game_dir="$tmp_dir/game with spaces"
bin_dir="$game_dir/bin64"

mkdir -p "$release_mod/bin64/linux/lib64" "$bin_dir"
cp -a -- "$repo_root/Mod/." "$release_mod/"
printf '\177ELFfake-injector\n' > "$release_mod/bin64/linux/lib64/libInjector.so"
printf '\177ELFfake-server\n' > "$bin_dir/dontstarve_dedicated_server_nullrenderer_x64"
chmod +x "$bin_dir/dontstarve_dedicated_server_nullrenderer_x64"

installer="$(find "$tmp_dir/release" -type f -name install_dst_luajit.sh -print -quit)"
[ -n "$installer" ] || {
    printf 'unique installer entry point was not found\n' >&2
    exit 1
}

bash "$installer" --bin-dir "$bin_dir"

launcher="$bin_dir/dontstarve_dedicated_server_nullrenderer_x64"
original="${launcher}_1"
installed_mod="$game_dir/mods/DontStarveLuaJIT2"
resolved_game_dir="$(CDPATH='' cd -- "$game_dir" && pwd -P)"

grep -q '^# DontStarveLuaJIT launcher$' "$launcher"
grep -q 'exec .*dontstarve_dedicated_server_nullrenderer_x64_1.*"\$@"' "$launcher"
grep -Fq 'export LD_PRELOAD="./lib64/libInjector.so${LD_PRELOAD:+ $LD_PRELOAD}"' "$launcher"
[ "$(od -An -tx1 -N4 "$original" | tr -d '[:space:]')" = "7f454c46" ]
[ -f "$bin_dir/lib64/libInjector.so" ]
[ -f "$installed_mod/modmain.lua" ]
[ -f "$installed_mod/install_dst_luajit.sh" ]
grep -Fq '"modmain_path": "'"$resolved_game_dir"'/mods/DontStarveLuaJIT2/modmain.lua"' \
    "$game_dir/data/unsafedata/luajit_config.json"
grep -Fq '"AlwaysEnableMod": true' \
    "$game_dir/data/unsafedata/luajit_config.json"

cp -a "$original" "$tmp_dir/original.before"
config_file="$game_dir/data/unsafedata/luajit_config.json"
printf '{"modmain_path":"/deleted/old/modmain.lua","AlwaysEnableMod":false}\n' > "$config_file"
bash "$installed_mod/install_linux.sh"
cmp "$tmp_dir/original.before" "$original"
grep -Fq '"modmain_path": "'"$resolved_game_dir"'/mods/DontStarveLuaJIT2/modmain.lua"' "$config_file"
grep -Fq '"AlwaysEnableMod": true' "$config_file"
grep -Fq '"modmain_path":"/deleted/old/modmain.lua"' "$config_file.pre-installer"

cat > "$original" <<'EOF'
#!/usr/bin/env bash
printf 'cwd=%s\npreload=%s\narg1=%s\narg2=%s\n' "$PWD" "$LD_PRELOAD" "$1" "$2"
EOF
chmod +x "$original"
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) ;;
    *)
        launcher_output="$(env -u LD_PRELOAD "$launcher" first 'two words' 2>/dev/null)"
        case "$launcher_output" in
            *"cwd=$resolved_game_dir/bin64"*"preload=./lib64/libInjector.so"*"arg1=first"*"arg2=two words"*) ;;
            *)
                printf 'launcher did not preserve its working directory, preload path, or arguments\n%s\n' \
                    "$launcher_output" >&2
                exit 1
                ;;
        esac
        ;;
esac

help_output="$(bash "$installed_mod/install_dst_luajit.sh" --help)"
case "$help_output" in
    *--game-dir*--bin-dir*) ;;
    *)
        printf 'installer help is missing directory options\n' >&2
        exit 1
        ;;
esac

if bash "$installed_mod/install_linux.sh" --unknown >/dev/null 2>&1; then
    printf 'unknown installer arguments must fail\n' >&2
    exit 1
fi

game_dir_option="$tmp_dir/game-dir-option"
bin_dir_option="$game_dir_option/bin64"
foreign_mod="$game_dir_option/mods/OtherMod"
mkdir -p "$bin_dir_option"
printf '\177ELFfake-server\n' > "$bin_dir_option/dontstarve_dedicated_server_nullrenderer_x64"
chmod +x "$bin_dir_option/dontstarve_dedicated_server_nullrenderer_x64"
mkdir -p "$foreign_mod"
cp -a -- "$release_mod/." "$foreign_mod/"

bash "$foreign_mod/install_dst_luajit.sh" --game-dir "$game_dir_option/"

[ -f "$bin_dir_option/dontstarve_dedicated_server_nullrenderer_x64_1" ]
[ -f "$game_dir_option/mods/DontStarveLuaJIT2/modmain.lua" ]
resolved_game_dir_option="$(CDPATH='' cd -- "$game_dir_option" && pwd -P)"
grep -Fq '"modmain_path": "'"$resolved_game_dir_option"'/mods/DontStarveLuaJIT2/modmain.lua"' \
    "$game_dir_option/data/unsafedata/luajit_config.json"

printf 'Linux installer integration test passed\n'
