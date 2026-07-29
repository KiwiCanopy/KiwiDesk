#!/bin/bash
# Cut a release: stamp the version, verify, commit, tag, push
# (#32). Pushing the tag is what triggers .github/workflows/
# release.yml, which builds the artifact and drafts the release.
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
if [ -n "$(git ls-remote --tags origin "$TAG")" ]; then
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
    [ "$STAMPED" -eq 1 ] && git checkout -- "$VERSION_FILE"
    return 0
}
trap restore_stamp EXIT

"$ROOT/scripts/bump-version.sh" "$VERSION"
STAMPED=1

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
# The pre-commit hook refuses commits on main, and this is the
# case its override exists for: a release commit belongs on main
# by definition. Named rather than `--no-verify`, which would
# also drop the lint and locale checks.
KIWIDESK_ALLOW_MAIN_COMMIT=1 \
    git commit -m "chore(release): stamp version $VERSION"
# The commit now carries the stamp, so there is nothing left to
# revert and the handler must not run.
STAMPED=0

echo "==> tagging $TAG"
git tag -a "$TAG" -m "KiwiDesk $VERSION"

# ---------------------------------------------------------------
# 5. Push

if [ "$ASSUME_YES" -eq 0 ]; then
    echo
    echo "About to push to origin:"
    echo "  commit  $(git rev-parse --short HEAD) on main"
    echo "  tag     $TAG"
    echo
    echo "Pushing the tag starts the release workflow and cannot"
    echo "be undone cleanly once anyone has fetched it."
    printf 'Push? [y/N] '
    read -r reply
    case "$reply" in
        [yY]|[yY][eE][sS]) ;;
        *)
            echo "not pushed. The commit and tag are local:"
            echo "  git push origin main && git push origin $TAG"
            echo "  git tag -d $TAG && git reset --hard HEAD~1"
            exit 0
            ;;
    esac
fi

# The commit first, always: a tag pushed ahead of it would point
# at an object that is not on main, and if the branch push were
# then rejected the tag would be the only reference to it.
echo "==> pushing main"
git push origin main
echo "==> pushing $TAG"
git push origin "$TAG"

echo
echo "released $TAG"
echo "  workflow: gh run list --workflow=release.yml"
echo "  draft:    gh release view $TAG"
