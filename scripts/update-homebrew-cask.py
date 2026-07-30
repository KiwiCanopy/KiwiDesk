#!/usr/bin/env python3
"""Update KiwiDesk's Homebrew cask version and archive digest."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import stat
import tempfile


VERSION = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+")
SHA256 = re.compile(r"[0-9a-f]{64}")
CASK = re.compile(r'^cask "kiwidesk" do$', re.MULTILINE)
VERSION_LINE = re.compile(
    r'^(?P<indent>\s*)version "(?P<value>[^"]+)"$', re.MULTILINE
)
SHA_LINE = re.compile(
    r'^(?P<indent>\s*)sha256 "[^"]+"$', re.MULTILINE
)


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(
        description="Update Casks/kiwidesk.rb without rewriting it."
    )
    result.add_argument("version", help="three-part release version")
    result.add_argument("sha256", help="lowercase SHA-256 digest")
    result.add_argument(
        "--cask",
        type=Path,
        default=Path("Casks/kiwidesk.rb"),
        help="cask file to update",
    )
    return result


def replace_one(
    source: str,
    pattern: re.Pattern[str],
    value: str,
    label: str,
) -> str:
    matches = list(pattern.finditer(source))
    if len(matches) != 1:
        raise ValueError(
            f"expected exactly one {label} line, found {len(matches)}"
        )
    return pattern.sub(
        lambda match: f'{match.group("indent")}{label} "{value}"',
        source,
        count=1,
    )


def write_atomically(path: Path, contents: str) -> None:
    mode = stat.S_IMODE(path.stat().st_mode)
    temporary: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=path.parent,
            prefix=f".{path.name}.",
            delete=False,
        ) as handle:
            handle.write(contents)
            temporary = Path(handle.name)
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()


def main() -> int:
    arguments = parser().parse_args()
    if VERSION.fullmatch(arguments.version) is None:
        raise SystemExit("error: version must be MAJOR.MINOR.PATCH")
    if SHA256.fullmatch(arguments.sha256) is None:
        raise SystemExit("error: sha256 must be 64 lowercase hex digits")

    path: Path = arguments.cask
    try:
        source = path.read_text(encoding="utf-8")
    except OSError as error:
        raise SystemExit(f"error: cannot read {path}: {error}") from error

    if len(CASK.findall(source)) != 1:
        raise SystemExit(
            'error: expected exactly one `cask "kiwidesk" do` declaration'
        )

    current_versions = list(VERSION_LINE.finditer(source))
    if len(current_versions) != 1:
        raise SystemExit(
            "error: expected exactly one version line, "
            f"found {len(current_versions)}"
        )
    current = current_versions[0].group("value")
    if VERSION.fullmatch(current) is None:
        raise SystemExit(f"error: current cask version is invalid: {current}")
    requested_parts = tuple(map(int, arguments.version.split(".")))
    current_parts = tuple(map(int, current.split(".")))
    if requested_parts < current_parts:
        raise SystemExit(
            f"error: refusing to downgrade {current} to {arguments.version}"
        )

    try:
        updated = replace_one(
            source, VERSION_LINE, arguments.version, "version"
        )
        updated = replace_one(
            updated, SHA_LINE, arguments.sha256, "sha256"
        )
    except ValueError as error:
        raise SystemExit(f"error: {error}") from error

    if updated == source:
        print(f"kiwidesk cask is already at {arguments.version}")
        return 0

    try:
        write_atomically(path, updated)
    except OSError as error:
        raise SystemExit(f"error: cannot write {path}: {error}") from error
    print(f"updated kiwidesk cask to {arguments.version}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
