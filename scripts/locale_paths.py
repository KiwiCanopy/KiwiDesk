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
argument and the readers it protects. This module owns the
worksheet's **path and name, and the env overrides that move
them** — not the rejection of one found among the catalogs, which
each reader implements against `WORKSHEET_PREFIX`.

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

# What marks a file as a worksheet rather than a catalog. Every
# rejection is written against this — `validate_locale_files` in
# `scripts/extract-keys`, the walkers that must not mangle a stray
# one, the `CFBundleLocalizations` glob in `scripts/build-app.sh`
# (via `AppPlistLocalizationTests`, which derives the needle from
# here rather than typing it again). Renaming it here without the
# bash arm following would leave the packager silently listing
# worksheets as languages.
WORKSHEET_PREFIX = "missing_"

OVERRIDE_ENV = "KIWIDESK_EXTRACT_WORKSHEETS"

# Every override these scripts honour. Site mode honours NONE of
# them (`SITE_LOCALES_DIR` is `__file__`-derived), which is what
# `site_override_conflict` exists to refuse.
OVERRIDE_PREFIX = "KIWIDESK_EXTRACT_"


def worksheet_name(locale: str) -> str:
    """The worksheet's filename for `locale`."""
    return f"{WORKSHEET_PREFIX}{locale}.json"


def _override() -> str | None:
    """The override's value, or None when it is unset **or set to
    an empty string**. Both questions below route through this so
    they cannot disagree: `VAR= ` exported reads as "set" to a
    membership test and as "" to a `.get` default, which would
    refuse a `--site` run while resolving a plain one to
    `Path("")` — writing the worksheet into whatever directory the
    shell happened to be in."""
    value = os.environ.get(OVERRIDE_ENV)
    return value or None


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
    base = Path(_override() or str(root / WORKSHEETS_DIRNAME))
    return base / "site" if site else base


def site_override_conflict(site: bool) -> str | None:
    """Why a `--site` run must not proceed under an override, or
    None. Called by both scripts before either touches a path.

    Refuses on ANY `KIWIDESK_EXTRACT_*`, not just the worksheet
    one. Site mode honours none of them — `main()` reassigns
    `LOCALES_DIR = SITE_LOCALES_DIR`, which is `__file__`-derived
    — so setting `KIWIDESK_EXTRACT_LOCALES` and adding `--site`
    reads, and under `--prune` rewrites, the developer's real
    `site/src/i18n` while the caller believes it is redirected.
    That is the mutating half of the same "half a redirect is
    worse than none" failure, so the predicate is over the family
    rather than over one member of it. An empty value is not
    set (see `_override`), applied here per variable.
    """
    if not site:
        return None
    live = sorted(
        name
        for name, value in os.environ.items()
        if name.startswith(OVERRIDE_PREFIX) and value
    )
    if not live:
        return None
    return (
        f"{', '.join(live)} set, but --site honours no override "
        "— site/src/i18n is derived from the script's own "
        "location. The run would read and rewrite the real site "
        "catalogs while believing it was redirected. Unset "
        "them, or run without --site."
    )
