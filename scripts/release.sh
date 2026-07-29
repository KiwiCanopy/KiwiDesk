#!/bin/bash
# Cut a release: stamp the version, verify, commit, tag, push
# (#32). Pushing the tag is what triggers .github/workflows/
# release.yml, which re-verifies the tag, builds the artifact
# and drafts the release.
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
# 3. Verify

if [ "$SKIP_VERIFY" -eq 1 ]; then
    echo "==> skipping the verification gate (--skip-verify)"
else
    # AGENTS.md §3 / the verify-gate skill. The release build is
    # conditional there because CI runs it per PR; it is
    # unconditional here because this tree is what ships and
    # because nothing else will build it in release before a user
    # does. The two `swift test` calls stay separate — see
    # .claude/rules/tests.md.
    echo "==> swift build"
    swift build
    echo "==> swift test --skip ExecTests"
    swift test --skip ExecTests
    echo "==> swift test --filter ExecTests"
    swift test --filter ExecTests
    echo "==> scripts/lint.sh"
    ./scripts/lint.sh
    echo "==> swift build -c release"
    swift build -c release
fi

# ---------------------------------------------------------------
# 4. Commit & tag

echo "==> committing"
git add "$VERSION_FILE"
# Whether THIS run created a commit. The decline path below prints
# an undo, and `git reset --hard HEAD~1` is destructive in the
# already-stamped case: HEAD is then a commit that is already on
# origin/main, so the undo would discard an unrelated pushed
# commit and leave local main behind the remote.
COMMITTED=0
if git diff --cached --quiet; then
    # The tree already declares this version, so there is nothing
    # to commit and `git commit` would exit 1 on "nothing to
    # commit" — after the whole gate has run, reading like a bug
    # rather than a state. Two ordinary ways to get here: the tag
    # push failed and this is the re-run, or someone deleted the
    # tag and started over. Tag HEAD instead; the workflow's
    # tag-match guard is satisfied either way, because the
    # constant already says $VERSION.
    echo "    already stamped $VERSION — tagging HEAD"
else
    # The pre-commit hook refuses commits on main, and this is
    # the case its override exists for: a release commit belongs
    # on main by definition. Named rather than `--no-verify`,
    # which would also drop the lint and locale checks.
    KIWIDESK_ALLOW_MAIN_COMMIT=1 \
        git commit -m "chore(release): stamp version $VERSION"
    COMMITTED=1
fi
# Either the commit carries the stamp or there was none to make.
# Nothing left to revert, so the handler must not run.
STAMPED=0

echo "==> tagging $TAG"
git tag -a "$TAG" -m "KiwiDesk $VERSION"

# ---------------------------------------------------------------
# 5. Push

if [ "$ASSUME_YES" -eq 0 ]; then
    echo
    echo "About to push to origin:"
    if [ "$COMMITTED" -eq 1 ]; then
        echo "  commit  $(git rev-parse --short HEAD) on main"
    else
        echo "  commit  none (already stamped)"
    fi
    echo "  tag     $TAG"
    echo
    echo "Pushing the tag starts the release workflow and cannot"
    echo "be undone cleanly once anyone has fetched it."
    printf 'Push? [y/N] '
    read -r reply
    case "$reply" in
        [yY]|[yY][eE][sS]) ;;
        *)
            # The undo has to branch on what this run actually did.
            # Printing `reset --hard HEAD~1` when no commit was
            # made would throw away whatever HEAD already was — and
            # in the already-stamped path that is a commit sitting
            # on origin/main.
            if [ "$COMMITTED" -eq 1 ]; then
                echo "not pushed. The commit and tag are local:"
                echo "  git push origin main &&" \
                     "git push origin $TAG"
                echo "  git tag -d $TAG && git reset --hard HEAD~1"
            else
                echo "not pushed. Only the tag is local:"
                echo "  git push origin $TAG"
                echo "  git tag -d $TAG"
            fi
            exit 0
            ;;
    esac
fi

# The commit first, always: a tag pushed ahead of it would point
# at an object that is not on main, and if the branch push were
# then rejected the tag would be the only reference to it.
echo "==> pushing main"
# Same courtesy as the tag push below: a bare re-run after this
# fails dies at the "level with origin/main" precondition, which
# describes the symptom and not the fix.
if ! git push origin main; then
    echo >&2
    echo "error: could not push main, so the tag was not pushed" \
         "either. Both are still local — resolve the push (pull," \
         "or check access) and re-run:" >&2
    echo "  git push origin main && git push origin $TAG" >&2
    exit 1
fi
echo "==> pushing $TAG"
# The one partial state this script can end in, so it names the
# way out. A bare re-run would refuse at the local-tag
# precondition — technically true and unhelpful, since the fix is
# to push the tag that already exists, not to cut another.
if ! git push origin "$TAG"; then
    echo >&2
    echo "error: main was pushed but $TAG was not. The release" \
         "commit is on origin/main; only the tag is missing, so" \
         "re-running this script will refuse. Push it directly:" >&2
    echo "  git push origin $TAG" >&2
    exit 1
fi

echo
echo "released $TAG"
echo "  workflow: gh run list --workflow=release.yml"
echo "  draft:    gh release view $TAG"
