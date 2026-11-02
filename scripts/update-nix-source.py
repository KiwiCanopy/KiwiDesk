#!/usr/bin/env python3
"""Update KiwiDesk's Nix source pin in KiwiCanopy/nix (#2909)."""

from __future__ import annotations

import argparse
import base64
import json
import os
from pathlib import Path
import re
import stat
import tempfile


VERSION = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+")
SHA256 = re.compile(r"[0-9a-f]{64}")
SRI = re.compile(r"sha256-[A-Za-z0-9+/]{43}=")
KEYS = {"version", "url", "hash"}
URL = (
    "https://github.com/KiwiCanopy/KiwiDesk/releases/download/"
    "v{version}/KiwiDesk-{version}.zip"
)


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(
        description="Point pkgs/kiwidesk/source.json at a release."
    )
    result.add_argument("version", help="three-part release version")
    result.add_argument("sha256", help="lowercase SHA-256 digest")
    result.add_argument(
        "--source",
        type=Path,
        default=Path("pkgs/kiwidesk/source.json"),
        help="source pin to update",
    )
    return result


def sri(digest: str) -> str:
    """Nix's SRI form of a hex SHA-256 digest."""
    raw = bytes.fromhex(digest)
    return "sha256-" + base64.b64encode(raw).decode("ascii")


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

    path: Path = arguments.source
    try:
        pin = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise SystemExit(f"error: cannot read {path}: {error}") from error

    if not isinstance(pin, dict) or set(pin) != KEYS:
        raise SystemExit(
            f"error: expected exactly the keys {sorted(KEYS)} in {path}"
        )
    current = pin["version"]
    if not isinstance(current, str) or VERSION.fullmatch(current) is None:
        raise SystemExit(
            f"error: current pinned version is invalid: {current}"
        )
    current_hash = pin["hash"]
    if not isinstance(current_hash, str) or not SRI.fullmatch(current_hash):
        raise SystemExit(f"error: current pinned hash is invalid in {path}")

    wanted = sri(arguments.sha256)
    requested_parts = tuple(map(int, arguments.version.split(".")))
    current_parts = tuple(map(int, current.split(".")))
    if requested_parts < current_parts:
        raise SystemExit(
            f"error: refusing to downgrade {current} to {arguments.version}"
        )
    if requested_parts == current_parts:
        if wanted != current_hash:
            raise SystemExit(
                "error: refusing to replace hash for existing version "
                f"{current}"
            )
        print(f"kiwidesk source is already at {arguments.version}")
        return 0

    updated = {
        "version": arguments.version,
        "url": URL.format(version=arguments.version),
        "hash": wanted,
    }
    try:
        write_atomically(path, json.dumps(updated, indent=2) + "\n")
    except OSError as error:
        raise SystemExit(f"error: cannot write {path}: {error}") from error
    print(f"updated kiwidesk source to {arguments.version}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
