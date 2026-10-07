"""Snapshot uncommitted work before a git command that discards it.

Imported by `scripts/gate-hook`, so the net costs no second process
on every shell command (owner ruling 2026-10-07). It never blocks:
`git stash create` writes a commit without touching the tree or the
stash list, pinned under `refs/discard-backups/`; the untracked
files a `git clean` would delete are copied to a tarball in the
common git dir. Restore with `git checkout <ref> -- <path>`.

The command is read as shell words, so the snapshot is taken in the
repo the git command acts on — after a `cd`, or at `-C` — rather
than in the hook's own cwd. Python 3.9: macOS ships no newer one.
`DiscardGuardHookTests` pins the spellings.
"""

import os
import re
import shlex
import subprocess
import time
from typing import Iterator, List, Optional, Tuple

KEEP_DAYS = 7
BUDGET = 20.0  # seconds, well under Claude Code's hook timeout
OPERATORS = set("();<>|&")
PREFIXES = {
    "!", "{", "}", "then", "do", "else", "if", "while", "until",
    "time", "command", "exec", "nice", "xargs", "sudo", "env",
}
ASSIGN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*=")
OPTIONS_WITH_ARG = {"-C", "-c", "--git-dir", "--work-tree",
                    "--namespace", "--exec-path"}
CHECKOUT_DISCARDS = {"--", ".", "-f", "--force", "-p", "--patch",
                     "--theirs", "--ours"}
CHECKOUT_BRANCHES = {"-b", "-B", "--orphan"}
STASH_KEEPS = {"list", "show", "drop", "pop", "apply", "branch",
               "clear", "create", "store"}


class Deadline:
    def __init__(self) -> None:
        self.end = time.monotonic() + BUDGET

    def left(self) -> float:
        left = self.end - time.monotonic()
        if left <= 0:
            raise TimeoutError("discard-guard budget spent")
        return left


def run(cwd: str, clock: Deadline, *args: str,
        stdin: Optional[bytes] = None) -> subprocess.CompletedProcess:
    return subprocess.run(
        list(args), cwd=cwd, input=stdin, capture_output=True,
        timeout=clock.left(),
    )


def git(cwd: str, clock: Deadline, *args: str) -> str:
    out = run(cwd, clock, "git", *args).stdout
    return out.decode("utf-8", "replace").strip()


def segments(command: str) -> Iterator[List[str]]:
    """The command's simple commands as word lists; a line that
    will not tokenize (a heredoc body, say) is skipped alone."""
    for line in command.replace("\\\n", " ").split("\n"):
        lex = shlex.shlex(line, posix=True, punctuation_chars=True)
        lex.whitespace_split = True
        words: List[str] = []
        try:
            for token in lex:
                if token and set(token) <= OPERATORS:
                    yield words
                    words = []
                else:
                    words.append(token)
        except ValueError:
            continue
        yield words


def short_flags(args: List[str]) -> str:
    return "".join(
        a[1:] for a in args if a.startswith("-")
        and not a.startswith("--")
    )


def discards(sub: str, args: List[str], where: str) -> bool:
    if sub == "checkout":
        if CHECKOUT_BRANCHES & set(args):
            return False
        if CHECKOUT_DISCARDS & set(args) or set("fp") & set(
            short_flags(args)
        ):
            return True
        return any(
            not a.startswith("-")
            and os.path.exists(os.path.join(where, a))
            for a in args
        )
    if sub == "switch":
        return bool({"-f", "--force", "--discard-changes"} & set(args))
    if sub == "restore":
        flags = short_flags(args)
        staged = "--staged" in args or "S" in flags
        worktree = "--worktree" in args or "W" in flags
        return not staged or worktree
    if sub == "reset":
        return "--hard" in args
    if sub == "clean":
        flags = short_flags(args)
        force = "--force" in args or "f" in flags
        dry = "--dry-run" in args or "n" in flags
        return force and not dry
    if sub == "stash":
        words = [a for a in args if not a.startswith("-")]
        return not words or words[0] not in STASH_KEEPS
    return False


def targets(command: str, cwd: str) -> List[Tuple[str, bool]]:
    """(directory, is a clean) for each discarding git command."""
    here, found = cwd, []
    for words in segments(command):
        while words and (words[0] in PREFIXES or ASSIGN.match(words[0])):
            words = words[1:]
        if not words:
            continue
        if words[0] in ("cd", "pushd"):
            dest = words[1] if len(words) > 1 else "~"
            if dest != "-":
                here = os.path.normpath(os.path.join(
                    here, os.path.expanduser(os.path.expandvars(dest))
                ))
            continue
        if os.path.basename(words[0]) != "git":
            continue
        where, rest = here, words[1:]
        while rest and rest[0].startswith("-"):
            option = rest.pop(0)
            if option in OPTIONS_WITH_ARG and rest:
                value = rest.pop(0)
                if option == "-C":
                    where = os.path.normpath(os.path.join(
                        where,
                        os.path.expanduser(os.path.expandvars(value)),
                    ))
        if rest and discards(rest[0], rest[1:], where):
            found.append((where, rest[0] == "clean"))
    return found


def keep_untracked(where: str, stamp: str, clock: Deadline) -> str:
    """Tars what a clean would delete; the tarball path, or ''."""
    listing = run(
        where, clock, "git", "ls-files", "-z", "--others",
        "--exclude-standard",
    ).stdout
    if not listing:
        return ""
    common = git(where, clock, "rev-parse", "--git-common-dir")
    folder = os.path.join(where, common, "discard-backups")
    os.makedirs(folder, exist_ok=True)
    tarball = os.path.join(folder, f"{stamp}.tar")
    made = run(
        where, clock, "tar", "-cf", tarball, "--null", "-T", "-",
        stdin=listing,
    )
    return tarball if made.returncode == 0 else ""


def prune(where: str, clock: Deadline) -> None:
    """Drops refs and tarballs older than KEEP_DAYS."""
    cutoff = time.time() - KEEP_DAYS * 86400
    listing = git(
        where, clock, "for-each-ref",
        "--format=%(refname) %(creatordate:unix)",
        "refs/discard-backups/",
    )
    stale = [
        name for name, _, when in
        (line.partition(" ") for line in listing.splitlines())
        if when.isdigit() and int(when) < cutoff
    ]
    if stale:
        batch = "".join(f"delete {name}\n" for name in stale)
        run(where, clock, "git", "update-ref", "--stdin",
            stdin=batch.encode())
    common = git(where, clock, "rev-parse", "--git-common-dir")
    folder = os.path.join(where, common, "discard-backups")
    if os.path.isdir(folder):
        for entry in os.scandir(folder):
            if entry.stat().st_mtime < cutoff:
                os.remove(entry.path)


def snapshot(command: str, cwd: str) -> Optional[str]:
    """Pins the work a discarding command would lose; returns the
    recovery line, or None when there was nothing to keep."""
    found = targets(command, cwd)
    if not found:
        return None
    dirs: dict = {}
    for where, cleans in found:
        dirs[where] = dirs.get(where, False) or cleans
    clock = Deadline()
    notes: List[str] = []
    for index, (where, cleans) in enumerate(dirs.items()):
        if not os.path.isdir(where):
            notes.append(f"NO snapshot, cannot resolve {where}")
            continue
        if not git(where, clock, "status", "--porcelain"):
            continue
        # The index keeps two worktrees of one repo apart: they
        # share the refs and the common dir.
        stamp = time.strftime("%Y%m%d-%H%M%S") + (
            f"-{os.getpid()}-{index}"
        )
        sha = git(where, clock, "stash", "create", "discard-guard")
        if sha:
            ref = f"refs/discard-backups/{stamp}"
            git(where, clock, "update-ref", "-m", "discard-guard",
                ref, sha)
            notes.append(f"git checkout {ref} -- <path>")
        if cleans:
            tarball = keep_untracked(where, stamp, clock)
            if tarball:
                notes.append(f"untracked files in {tarball}")
        try:
            prune(where, clock)
        except Exception:  # the snapshot stands; never lose its note
            pass
    if not notes:
        return None
    return "discard-guard: snapshot before discard — " + "; ".join(
        notes
    )
