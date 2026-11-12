#!/usr/bin/env python3
"""Fail when the official Homebrew cask lags the latest release.

Reads two JSON documents: GitHub's latest published release
(`gh api repos/<repo>/releases/latest`) and Homebrew's cask record
(`https://formulae.brew.sh/api/cask/kiwidesk.json`). Exits 0 while
the cask names the release's version or the release is younger
than the grace period, 1 once the cask has fallen behind, and 2 on
input it cannot read. Writes nothing: homebrew-cask's autobump is
the cask's one writer (packaging-and-release.md).
"""

from __future__ import annotations

import argparse
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import re
import sys


TAG = re.compile(r"v([0-9]+\.[0-9]+\.[0-9]+)")


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    result.add_argument("--release", type=Path, required=True)
    result.add_argument("--cask", type=Path, required=True)
    result.add_argument(
        "--grace-hours",
        type=float,
        default=24,
        help="how long after publication a lag is still expected",
    )
    result.add_argument(
        "--now",
        help="ISO-8601 instant to judge against (default: now)",
    )
    return result


def instant(text: str) -> datetime:
    value = datetime.fromisoformat(text.replace("Z", "+00:00"))
    if value.tzinfo is None:
        raise ValueError(f"{text!r} carries no time zone")
    return value


def fail(message: str) -> int:
    print(f"check-homebrew-cask: {message}", file=sys.stderr)
    return 2


def main(argv: list[str]) -> int:
    args = parser().parse_args(argv)
    try:
        release = json.loads(args.release.read_text(encoding="utf-8"))
        cask = json.loads(args.cask.read_text(encoding="utf-8"))
        now = (
            instant(args.now) if args.now else datetime.now(timezone.utc)
        )
    except (OSError, ValueError) as error:
        return fail(str(error))

    tag = release.get("tag_name")
    match = TAG.fullmatch(tag) if isinstance(tag, str) else None
    if match is None:
        return fail(f"release tag {tag!r} is not vMAJOR.MINOR.PATCH")
    if release.get("draft") or release.get("prerelease"):
        return fail(f"{tag} is not a published final release")
    published = release.get("published_at")
    if not isinstance(published, str):
        return fail(f"{tag} has no published_at")
    try:
        published_at = instant(published)
    except ValueError as error:
        return fail(str(error))
    version = cask.get("version")
    if not isinstance(version, str) or not version:
        return fail("the cask record has no version")

    expected = match.group(1)
    if version == expected:
        print(f"Homebrew cask is at {expected}.")
        return 0
    age = now - published_at
    hours = age.total_seconds() / 3600
    if age < timedelta(hours=args.grace_hours):
        print(
            f"Homebrew cask is at {version}; {tag} was published "
            f"{hours:.1f} h ago, inside the {args.grace_hours:g} h grace."
        )
        return 0
    print(
        f"::error::Homebrew cask is at {version}, but {tag} was "
        f"published {hours:.1f} h ago. Check homebrew-cask's autobump "
        "PR for kiwidesk, or open the bump PR by hand."
    )
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
