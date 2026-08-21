#!/bin/bash
# Cut a release in TWO RUNS (#32). main is protected (#487), so
# the version stamp reaches it through a PR like everything else,
# and the tag is cut once that PR has merged:
#
#   run 1  stamp -> verify -> commit on chore/stamp-<version>
#          -> push the branch -> open its PR              (phase A)
#   run 2  (after the PR merges, on a synced main)
#          verify -> tag -> push the tag                  (phase B)
#
# The same command drives both; the script picks the phase from
# whether the tree already declares the version. Pushing the tag
# is what triggers .github/workflows/release.yml, which
# re-verifies the tag, builds the artifact and drafts the release.
#
# Usage: scripts/release.sh <semantic-version> [options]
#   e.g. scripts/release.sh 0.9.0
#
#   --skip-verify  Skip the build/test/lint gate. Only for
#                  re-cutting a version already verified on this
#                  exact tree.
#   --yes          Do not prompt before pushing. Required when
#                  stdin is not a terminal.
#
# EVERY CHECK RUNS BEFORE ANYTHING IS WRITTEN, and that ordering
# is the point: a tag is the one artifact here that other people
# fetch, so the expensive, mutating half must not start until the
# cheap half has proven it can finish. A half-cut release leaves
# a version bump with no tag, or worse a tag on a tree that never
# passed its gate.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="Sources/KiwiDeskCore/App/KiwiDeskVersion.swift"

VERSION=""
SKIP_VERIFY=0
ASSUME_YES=0

usage() {
    cat <<'EOF'
Cut a release: stamp, verify, commit, tag, push (#32).

Runs twice: the first stamps the version onto a
chore/stamp-<version> branch and opens its PR; the second, on a
synced main after that PR merges, cuts and pushes the tag.

Usage: scripts/release.sh <semantic-version> [options]

  --skip-verify   Skip the build/test/lint gate.
  --yes           Do not prompt before pushing.
  -h, --help      Show this help and exit.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --skip-verify) SKIP_VERIFY=1 ;;
        --yes) ASSUME_YES=1 ;;
        -*) echo "error: unknown option '$1'" >&2; exit 2 ;;
        *)
            if [ -n "$VERSION" ]; then
                echo "error: unexpected argument '$1'" >&2
                exit 2
            fi
            VERSION="$1"
            ;;
    esac
    shift
done

if [ -z "$VERSION" ]; then
    usage >&2
    exit 1
fi

TAG="v$VERSION"
cd "$ROOT"

# A milestone says which release must not ship without those issues, so
# a version whose milestone is not clear must not be cut. Checked here,
# before anything is stamped or tagged, because failing at this point
# costs nothing to undo — release.yml's copy runs after the tag already
# exists and can only withhold the artifacts.
#
# Best effort: without gh the check cannot run, and release.yml is then
# the authority. Missing local tooling must not block a release by itself.
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    MILESTONE_OPEN=$(gh issue list --milestone "$VERSION" --state open \
        --json number --jq 'length' 2>/dev/null || echo "")
    if [ -n "$MILESTONE_OPEN" ] && [ "$MILESTONE_OPEN" -gt 0 ]; then
        echo "✗ milestone $VERSION still has $MILESTONE_OPEN open issue(s):" >&2
        gh issue list --milestone "$VERSION" --state open \
            --json number,title --jq '.[] | "    #\(.number) \(.title)"' >&2
        echo "" >&2
        echo "  The release waits for these. Close them, or move each one" >&2
        echo "  deliberately — moving it records that we shipped without it:" >&2
        echo "    gh issue edit <n> --milestone \"<next>\"" >&2
        echo "    gh issue edit <n> --remove-milestone" >&2
        exit 1
    fi
else
    echo "! gh unavailable — skipping the milestone check (release.yml still enforces it)" >&2
fi

# ---------------------------------------------------------------
# 1. Preconditions — all read-only

# The version string is NOT validated here on purpose. Its regex
# lives in bump-version.sh and a second copy would be one more
# thing to keep in step; nothing below this point writes, so a
# malformed version still fails before any mutation (step 3).

if [ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]; then
    echo "error: releases are cut from main, not" \
         "'$(git rev-parse --abbrev-ref HEAD)'" >&2
    exit 1
fi

# Tracked changes only: an untracked scratch file cannot end up
# in the release commit, so refusing on one would be theatre.
if ! git diff --quiet HEAD; then
    echo "error: working tree has uncommitted changes" >&2
    git status --short >&2
    exit 1
fi

echo "==> fetching origin"
git fetch --quiet --tags origin

# A stale main tags a tree that is not what main means to anyone
# else — and the tag is the thing that cannot be quietly fixed.
LOCAL="$(git rev-parse HEAD)"
REMOTE="$(git rev-parse origin/main)"
if [ "$LOCAL" != "$REMOTE" ]; then
    echo "error: main is not level with origin/main" \
         "(local ${LOCAL:0:7}, remote ${REMOTE:0:7})" >&2
    echo "       pull or push first, then re-run" >&2
    exit 1
fi

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    echo "error: tag $TAG already exists locally" >&2
    exit 1
fi

# Checked separately from the local tag: `git fetch --tags` above
# imports remote tags, so this only differs when the remote grew
# one mid-run — but a tag push that loses that race is rejected
# after the commit is already on main, which is the messy half.
#
# The status is captured rather than tested inline. Inside an
# `if` condition errexit is suppressed, so a transient network
# failure would produce empty output and read as "no such tag" —
# a guard against the messy half that fails open into it.
if ! remote_tag="$(git ls-remote --tags origin "$TAG")"; then
    echo "error: could not reach origin to check whether $TAG" \
         "already exists — refusing to cut a release blind" >&2
    exit 1
fi
if [ -n "$remote_tag" ]; then
    echo "error: tag $TAG already exists on origin" >&2
    exit 1
fi

if [ "$ASSUME_YES" -eq 0 ] && [ ! -t 0 ]; then
    echo "error: stdin is not a terminal — pass --yes" >&2
    exit 1
fi

# ---------------------------------------------------------------
# 2. Stamp

echo "==> stamping $VERSION"
# Revert the stamp on any failure from here until the commit
# exists. Without it a failed gate leaves a modified version file
# in a tree the next run would then refuse as dirty, and the
# operator has to work out whether that edit was theirs.
STAMPED=0
restore_stamp() {
    set +e
    # `git checkout HEAD --`, NOT `git checkout --`. The latter
    # restores the worktree from the INDEX, so from the moment
    # step 4 stages the file it overwrites the stamp with itself
    # and reverts nothing. That window is real: `git commit` runs
    # the pre-commit hook, which lints and can fail — and the
    # residue would be precisely the staged, modified file this
    # handler exists to prevent, with nothing to tell the operator
    # whose edit it was.
    [ "$STAMPED" -eq 1 ] && git checkout HEAD -- "$VERSION_FILE"
    return 0
}
trap restore_stamp EXIT

# Armed BEFORE the write, not after. The handler runs on SIGINT
# too, so a Ctrl-C landing between the sed and the assignment
# would otherwise strand a stamped file. Reverting to HEAD is
# idempotent, so arming early costs nothing when there is nothing
# to undo.
STAMPED=1
"$ROOT/scripts/bump-version.sh" "$VERSION"

# ---------------------------------------------------------------
# 2b. Which phase, and whether phase B's gate is already paid for

# The phase is answerable here, ahead of the gate, because it is
# only a question about the stamp: bump-version.sh either changed
# the version file or the tree already declared this version.
# Asked of git rather than by re-reading the file, which keeps
# bump-version.sh the one owner of its shape.
PHASE="stamp"
if git diff --quiet -- "$VERSION_FILE"; then
    PHASE="tag"
fi

# A release used to run this gate FIVE times: phase A locally, CI
# on the stamp PR, CI again on main after the merge, phase B
# locally, and release.yml on the tag. Phase B's was the one that
# bought nothing — same tree CI had just verified.
#
# So phase A records the tree it verified and phase B skips its
# gate only when the tree it is about to tag hashes identically.
# The tree hash is what makes that safe rather than optimistic: a
# squash merge of nothing but the stamp reproduces phase A's tree
# exactly, and ANY other commit landing in between changes the
# hash, so the gate runs. This is deliberately not "phase B trusts
# CI" — that would skip on a tree nothing had verified.
#
# Fails closed in every direction: no record, an empty or
# unreadable one, a mismatch, or a git that cannot answer, all
# leave the gate running. A stale record is harmless by
# construction, since it can only ever match the one tree it
# attests to.
VERIFIED_RECORD="$(git rev-parse --git-dir)/kiwidesk-release-verified"

if [ "$PHASE" = "tag" ] && [ "$SKIP_VERIFY" -eq 0 ]; then
    if recorded="$(cat "$VERIFIED_RECORD" 2>/dev/null)" \
        && current="$(git rev-parse "HEAD^{tree}" 2>/dev/null)" \
        && [ -n "$recorded" ] \
        && [ "$recorded" = "$current" ]; then
        GATE_ALREADY_PAID=1
        echo "==> gate already passed on this exact tree" \
             "(${current:0:12}) — skipping it"
        echo "    CI verified it on the merge and release.yml" \
             "re-verifies the tag."
    fi
fi
GATE_ALREADY_PAID="${GATE_ALREADY_PAID:-0}"

# ---------------------------------------------------------------
# 3. Verify

if [ "$SKIP_VERIFY" -eq 1 ]; then
    echo "==> skipping the verification gate (--skip-verify)"
elif [ "$GATE_ALREADY_PAID" -eq 1 ]; then
    : # 2b explained it and said so on stdout
else
    # AGENTS.md §3 / the verify-gate skill. The release build is
    # conditional there because CI runs it per PR; it is
    # unconditional here because this tree is what ships and
    # because nothing else will build it in release before a user
    # does. One `swift test`: the old two-command split died
    # with the #494 tail-hang fix — see .claude/rules/tests.md.
    echo "==> swift build"
    swift build
    echo "==> swift test"
    swift test
    echo "==> scripts/lint.sh"
    ./scripts/lint.sh
    echo "==> swift build -c release"
    swift build -c release
fi

# ---------------------------------------------------------------
# 4. Stamp (phase A) or tag (phase B)
#
# WHY THIS IS TWO PHASES. `main` is protected (#487, applied by
# scripts/protect-main.sh) with enforce_admins TRUE, so a direct
# push to it is refused and the owner cannot bypass that. The
# stamp therefore reaches main the only way anything does — a PR
# — and the tag is cut on a later run, once that PR has merged.
#
# The stamps for 0.9.1, 0.9.5 and 0.9.6 each landed through a
# branch opened by hand after this script had already failed at
# the push. Phase A is that rescue, done by the script rather
# than re-derived from memory on release night.

# Which phase this run is, asked of git rather than of the file:
# reading the version back out here would make this a second
# owner of KiwiDeskVersion.swift's shape, and bump-version.sh is
# the one owner of it.
git add "$VERSION_FILE"

if ! git diff --cached --quiet; then
    # -----------------------------------------------------------
    # Phase A — the stamp goes to main through a PR.
    STAMP_BRANCH="chore/stamp-$VERSION"

    # Checked here rather than in step 1 because the phase is not
    # known until the stamp has been attempted. Nothing is lost
    # by the lateness — the trap reverts the stamp on the way out
    # — and a step-1 copy would be wrong: in phase B this branch
    # may still exist on origin, and refusing the tag run for
    # that would strand the release.
    if git rev-parse -q --verify "$STAMP_BRANCH" >/dev/null; then
        echo "error: branch $STAMP_BRANCH already exists" \
             "locally. Delete it, or finish the release it" \
             "belongs to." >&2
        exit 1
    fi

    echo "==> committing on $STAMP_BRANCH"
    git checkout -q -b "$STAMP_BRANCH"
    # No KIWIDESK_ALLOW_MAIN_COMMIT: this commit is on a branch,
    # which is exactly what the pre-commit hook wants.
    git commit -q -m "chore(release): stamp version $VERSION"
    # The commit carries the stamp, so there is nothing to revert
    # and the handler must not run.
    STAMPED=0

    # The tree the gate just passed on, for phase B to match
    # against. Written only when the gate ACTUALLY ran: a
    # --skip-verify run has no verification to attest to, and
    # recording one would let phase B skip on its word.
    if [ "$SKIP_VERIFY" -eq 0 ]; then
        git rev-parse "HEAD^{tree}" > "$VERIFIED_RECORD"
    fi

    if [ "$ASSUME_YES" -eq 0 ]; then
        echo
        echo "About to push $STAMP_BRANCH and open its PR."
        echo "No tag is cut by this phase: $TAG is created on the"
        echo "run after the PR merges, so nothing here is"
        echo "irreversible."
        printf 'Push? [y/N] '
        read -r reply
        case "$reply" in
            [yY]|[yY][eE][sS]) ;;
            *)
                echo "not pushed. The stamp is committed on" \
                     "$STAMP_BRANCH:"
                echo "  git push -u origin $STAMP_BRANCH"
                echo "  git checkout main &&" \
                     "git branch -D $STAMP_BRANCH"
                exit 0
                ;;
        esac
    fi

    echo "==> pushing $STAMP_BRANCH"
    git push -q -u origin "$STAMP_BRANCH"

    # Best effort, the same trade the milestone check makes: gh
    # may be absent or unauthenticated, and that must not strand
    # a branch that is already pushed. The next steps are printed
    # either way, so a failure here costs a click, not the thread.
    if command -v gh >/dev/null 2>&1 \
        && gh auth status >/dev/null 2>&1; then
        echo "==> opening the PR"
        PR_BODY="Version stamp for $VERSION, produced by
scripts/release.sh.

main is protected (#487), so the stamp reaches it through this
PR. The $TAG tag is pushed by re-running the script once this
has merged, which takes its tag phase and creates no second
commit."
        gh pr create --base main --head "$STAMP_BRANCH" \
            --title "chore(release): stamp version $VERSION" \
            --body "$PR_BODY" || true
    else
        echo "! gh unavailable — open the PR by hand" >&2
    fi

    echo
    echo "stamped $VERSION on $STAMP_BRANCH — NOT yet released."
    echo "  1. merge the PR once CI is green"
    echo "  2. git checkout main && git pull"
    echo "  3. scripts/release.sh $VERSION   (cuts $TAG)"
    exit 0
fi

# ---------------------------------------------------------------
# 5. Phase B — the tree already declares this version, so tag it
#
# Reached on the run after phase A's PR merged: step 1 has proven
# HEAD is main and level with origin/main, and the stamp is
# already in that tree. The tag is the only thing left to push,
# and main is deliberately not pushed at all — there is nothing
# to send, and protection would refuse it if there were.

echo "    already stamped $VERSION — tagging HEAD"
# Nothing was written this run, so the handler must not run.
STAMPED=0

echo "==> tagging $TAG"
git tag -a "$TAG" -m "KiwiDesk $VERSION"

if [ "$ASSUME_YES" -eq 0 ]; then
    echo
    echo "About to push to origin:"
    echo "  tag  $TAG -> $(git rev-parse --short HEAD)"
    echo
    echo "Pushing the tag starts the release workflow and cannot"
    echo "be undone cleanly once anyone has fetched it."
    printf 'Push? [y/N] '
    read -r reply
    case "$reply" in
        [yY]|[yY][eE][sS]) ;;
        *)
            echo "not pushed. Only the tag is local:"
            echo "  git push origin $TAG"
            echo "  git tag -d $TAG"
            exit 0
            ;;
    esac
fi

echo "==> pushing $TAG"
# The one partial state this phase can end in, so it names the
# way out. A bare re-run would refuse at the local-tag
# precondition — true and unhelpful, since the fix is to push the
# tag that already exists, not to cut another.
if ! git push origin "$TAG"; then
    echo >&2
    echo "error: $TAG was not pushed. The stamp is already on" \
         "origin/main, so re-running this script refuses at the" \
         "local-tag precondition. Push it directly:" >&2
    echo "  git push origin $TAG" >&2
    exit 1
fi

echo
echo "released $TAG"
echo "  workflow: gh run list --workflow=release.yml"
echo "  draft:    gh release view $TAG"

# ---------------------------------------------------------------
# 6. The notes skeleton — printed here because this is the one
#    place every release passes through (#873).
#
# release.yml drafts the release with --generate-notes, and the
# curated block goes on TOP of that generated list, by hand,
# BEFORE publishing. The form is not decoration: the Changelog
# workflow parses the published body into the site's release-notes
# page and REFUSES one it cannot read, so a body that drifts fails
# the workflow rather than half-rendering.
#
# Printed rather than filed in .github/: GitHub applies no release
# template the way it applies the issue and PR forms, so a
# RELEASE_TEMPLATE.md beside ISSUE_TEMPLATE/ would read as a form
# that runs and never run. And a template nobody is made to open
# drifts on the release someone is in a hurry for; this one is
# unavoidable.
#
# Section titles are the author's own — a fixed
# New/Improved/Fixed triple splits one story across three buckets,
# and a reader notices the story. The parser holds the SHAPE.
cat <<SKELETON

--------------------------------------------------------------
Curate the draft, THEN publish. Paste above the generated
"What's Changed" list, leaving a blank line between the two:

## Highlights

One or two sentences: what this release is about, plainly.

### <A thing a user noticed>

- **The short version.** Then the detail, from the user's side.

### <Another one>

- ...


--------------------------------------------------------------
The rules, in four lines:

  * An entry earns its place by what a USER can observe — never
    by having a commit. This is the whole rule.
  * No issue or PR numbers in the highlights. The generated list
    below them is the complete, linked record.
  * No internal vocabulary (engine, retile, census, seam, main
    actor). Layout names, Space, profile, App Bar are on screen,
    so they are fine.
  * Highlights are highlights. Site fixes, a font bump and
    release plumbing collapse into one closing line.

  Voice:  docs/design-decisions.md
          -> Release notes are written for the person installing
  Form:   .claude/rules/packaging-and-release.md
  Check:  python3 scripts/changelog-sync --release $TAG --check
--------------------------------------------------------------
SKELETON
