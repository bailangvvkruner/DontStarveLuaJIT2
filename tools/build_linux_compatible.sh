#!/usr/bin/env bash

set -Eeuo pipefail

repo_root="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
image="${MANYLINUX_IMAGE:-quay.io/pypa/manylinux_2_28_x86_64:latest}"

command -v docker >/dev/null 2>&1 || {
    printf 'error: Docker is required to build the portable Linux release.\n' >&2
    exit 1
}

docker run --rm \
    --volume "$repo_root:/workspace" \
    --workdir /workspace \
    --env "CI=${CI:-}" \
    --env "GITHUB_ACTIONS=${GITHUB_ACTIONS:-}" \
    "$image" \
    bash -lc '
        set -euo pipefail
        owner="$(stat -c "%u:%g" /workspace)"
        cleanup() {
            chown -R "$owner" /workspace/builds /workspace/Mod /workspace/.vcpkg-bincache 2>/dev/null || true
        }
        trap cleanup EXIT

        git config --global --add safe.directory /workspace
        git config --global --add safe.directory /workspace/luajit
        git config --global --add safe.directory /workspace/vcpkg

        dnf install -y ninja-build pkgconf-pkg-config zip kernel-headers perl-IPC-Cmd
        export PATH="/opt/python/cp313-cp313/bin:$PATH"
        if ! command -v ninja >/dev/null 2>&1; then
            ninja_build="$(command -v ninja-build || true)"
            [ -n "$ninja_build" ] || {
                printf "error: ninja executable was not installed.\n" >&2
                exit 1
            }
            ln -sf "$ninja_build" /usr/local/bin/ninja
        fi

        export CC=gcc
        export CXX=g++
        export VCPKG_DEFAULT_BINARY_CACHE=/workspace/.vcpkg-bincache
        export VCPKG_BINARY_SOURCES="clear;files,/workspace/.vcpkg-bincache,readwrite"
        mkdir -p "$VCPKG_DEFAULT_BINARY_CACHE"

        cmake --version
        ninja --version
        "$CXX" --version

        bash ./vcpkg/bootstrap-vcpkg.sh -disableMetrics
        cmake --preset ninja-multi-vcpkg -DGAME_DIR=OFF -DDONTSTARVE_STATIC_LIBSTDCXX=ON
        cmake --build ./builds/ninja-multi-vcpkg --config RelWithDebInfo
        cmake --build ./builds/ninja-multi-vcpkg --config RelWithDebInfo --target install
        python3 tools/check_linux_elf_compat.py \
            Mod/bin64/linux/lib64 \
            --max-glibc 2.28 \
            --forbid-needed libstdc++.so.6
        timeout 10s env \
            LD_LIBRARY_PATH="$PWD/Mod/bin64/linux/lib64:$PWD/3rd/steam/redistributable_bin/linux64" \
            LD_PRELOAD="$PWD/Mod/bin64/linux/lib64/libInjector.so" \
            /bin/true
        cp /bin/true /tmp/dontstarve_preload_smoke
        timeout 10s env \
            LD_LIBRARY_PATH="$PWD/Mod/bin64/linux/lib64:$PWD/3rd/steam/redistributable_bin/linux64" \
            LD_PRELOAD="$PWD/Mod/bin64/linux/lib64/libInjector.so" \
            /tmp/dontstarve_preload_smoke
    '
