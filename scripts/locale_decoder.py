"""Unified JSON object map decoder for localization tools (issue #855).

Both `scripts/extract-keys` and `scripts/merge-keys` decode worksheets
and locale catalogs from disk and must refuse the same three failure
modes:
- unparseable or malformed JSON (`json.JSONDecodeError`),
- bytes that are not valid UTF-8 (`UnicodeDecodeError`),
- I/O failures (`OSError`),
- or a valid JSON document that is not a JSON object (`dict`).

This module owns reading and parsing, returning a structured result:
either the decoded dictionary, or an error classification string
('not a JSON object', or `str(error)`) so each script can phrase the
refusal in its own voice without duplicating the decode arms.
"""

from __future__ import annotations

import json
from pathlib import Path


def decode_json_object(path: Path) -> tuple[dict | None, str | None]:
    """Reads `path` as UTF-8 and parses it as a JSON object (dict).

    Returns:
        `(data, None)` on success.
        `(None, reason)` on failure, where `reason` is `'not a JSON object'`
        if the JSON is valid but not a dictionary, or `str(error)` for I/O,
        encoding, or JSON syntax errors.
    """
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (
        json.JSONDecodeError,
        UnicodeDecodeError,
        OSError,
    ) as error:
        return None, str(error)
    if not isinstance(data, dict):
        return None, "not a JSON object"
    return data, None
