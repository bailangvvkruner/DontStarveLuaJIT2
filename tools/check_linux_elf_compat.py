#!/usr/bin/env python3

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import List, Optional, Tuple


GLIBC_RE = re.compile(r"\bGLIBC_(\d+(?:\.\d+)*)\b")
NEEDED_RE = re.compile(r"Shared library: \[([^\]]+)]")


def version_tuple(value: str) -> Tuple[int, ...]:
    return tuple(int(part) for part in value.split("."))


def find_readelf(explicit: Optional[str]) -> str:
    candidates = [explicit, "readelf", "llvm-readelf"]
    for candidate in candidates:
        if candidate and shutil.which(candidate):
            return candidate
    raise RuntimeError("readelf or llvm-readelf is required")


def readelf(readelf_path: str, option: str, path: Path) -> str:
    result = subprocess.run(
        [readelf_path, option, str(path)],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"{readelf_path} failed for {path}: {result.stderr.strip()}")
    return result.stdout


def is_elf(path: Path) -> bool:
    try:
        with path.open("rb") as stream:
            return stream.read(4) == b"\x7fELF"
    except OSError:
        return False


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate the glibc and shared-library baseline of Linux release files."
    )
    parser.add_argument("path", type=Path, help="ELF file or directory to inspect")
    parser.add_argument("--max-glibc", required=True, help="maximum permitted GLIBC version")
    parser.add_argument(
        "--forbid-needed",
        action="append",
        default=[],
        metavar="LIBRARY",
        help="fail when an ELF file has this DT_NEEDED dependency",
    )
    parser.add_argument("--readelf", help="readelf-compatible executable")
    args = parser.parse_args()

    readelf_path = find_readelf(args.readelf)
    files = [args.path] if args.path.is_file() else sorted(args.path.rglob("*"))
    elf_files = [path for path in files if path.is_file() and is_elf(path)]
    if not elf_files:
        print(f"error: no ELF files found under {args.path}", file=sys.stderr)
        return 2

    max_allowed = version_tuple(args.max_glibc)
    failures: List[str] = []

    for path in elf_files:
        version_output = readelf(readelf_path, "--version-info", path)
        dynamic_output = readelf(readelf_path, "--dynamic", path)
        glibc_versions = sorted(
            {match.group(1) for match in GLIBC_RE.finditer(version_output)},
            key=version_tuple,
        )
        needed = sorted(set(NEEDED_RE.findall(dynamic_output)))
        maximum = glibc_versions[-1] if glibc_versions else "none"
        print(f"[compat] {path.name}: max GLIBC={maximum}; needed={','.join(needed)}")

        if glibc_versions and version_tuple(glibc_versions[-1]) > max_allowed:
            failures.append(
                f"{path}: requires GLIBC_{glibc_versions[-1]} (limit is GLIBC_{args.max_glibc})"
            )

        forbidden = sorted(set(needed).intersection(args.forbid_needed))
        if forbidden:
            failures.append(f"{path}: forbidden DT_NEEDED entries: {', '.join(forbidden)}")

    if failures:
        for failure in failures:
            print(f"error: {failure}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
