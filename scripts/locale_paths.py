"""Where a translator worksheet lives — the one owner.

`scripts/extract-keys <locale>` mints `missing_<locale>.json` and
`scripts/merge-keys <locale>` reads and unlinks it, so the path
has two users and must have one definition: a second literal
diverges the moment the override below is set, and the symptom is
`merge-keys` reporting "does not exist" for a file that was just
written.

A worksheet is a NESTED `{key: {"source", "translation"}}` map,
which is why it may not sit beside the flat catalogs it was
computed from — `.claude/rules/localization.md` carries that
argument and the readers it protects. This module owns only the
location.

Neither script can import the other (both are hyphenated, so
neither is a module name), which is why this is a third file
rather than a constant in one of them.
"""

# `Path` in a return annotation is evaluated at def time, so
# without this the module will not import on the system python3
# (3.9) — see localization_guards.py.
from __future__ import annotations

import os
from pathlib import Path

# Visible, not a dot-folder: a translator opens the worksheet by
# hand. Gitignored as a whole directory (`.gitignore`), which is
# also why it must not be a name any target ships from.
WORKSHEETS_DIRNAME = "locale-worksheets"

OVERRIDE_ENV = "KIWIDESK_EXTRACT_WORKSHEETS"


def worksheets_dir(root: Path, site: bool = False) -> Path:
    """The directory `missing_<locale>.json` is written to and
    read from. `site` selects the marketing site's sub-tree.

    The override exists so a test spawning these scripts cannot
    write into the developer's own checkout; it is never set for
    a human run. It redirects the app tree only — `--site`'s
    catalogs have no matching override, and redirecting half of
    a mode is worse than redirecting none of it, so
    `extract-keys` refuses the combination outright rather than
    letting it through here.
    """
    base = Path(
        os.environ.get(
            OVERRIDE_ENV, str(root / WORKSHEETS_DIRNAME)
        )
    )
    return base / "site" if site else base


def site_override_conflict(site: bool) -> str | None:
    """Why a `--site` run must not proceed under the override, or
    None. Called by both scripts before either touches a path."""
    if site and OVERRIDE_ENV in os.environ:
        return (
            f"{OVERRIDE_ENV} redirects the worksheet tree but "
            "nothing redirects site/src/i18n, so --site would "
            "read and rewrite the real site catalogs while "
            "writing worksheets elsewhere. Unset it, or run "
            "without --site."
        )
    return None
