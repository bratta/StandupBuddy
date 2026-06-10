#!/usr/bin/env bash
# Validate that a release can proceed and emit the facts the /release skill needs.
#
# Usage:  scripts/release/preflight.sh vX.Y.Z
#
# Exit codes:
#   0  READY      — everything checks out; key=value facts printed to stdout
#   1  ERROR      — environment/repo problem (gh missing, dirty tree, tag exists, ...)
#   2  NOT_READY  — milestone still has open issues (the skill should refuse + razz the user)
set -euo pipefail
cd "$(dirname "$0")/../.."

VERSION="${1:?usage: preflight.sh vX.Y.Z}"
VER="${VERSION#v}"
TAG="v${VER}"
SERIES="$(printf '%s' "$VER" | cut -d. -f1-2)"   # e.g. 1.1.1 -> 1.1

fail()      { echo "ERROR: $*" >&2; exit 1; }
not_ready() { echo "NOT_READY: $*" >&2; exit 2; }

# --- version sanity ---------------------------------------------------------
[[ "$VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "version '$VERSION' must look like vX.Y.Z"

# --- tooling ----------------------------------------------------------------
command -v gh       >/dev/null 2>&1 || fail "gh (GitHub CLI) is not installed"
command -v xcodegen >/dev/null 2>&1 || fail "xcodegen is not installed"
gh auth status >/dev/null 2>&1      || fail "gh is not authenticated (run: gh auth login)"

# --- clean repo state -------------------------------------------------------
[ -z "$(git status --porcelain)" ] || fail "working tree is not clean; commit or stash first"

# --- tag must not already exist ---------------------------------------------
git fetch --tags --quiet || true
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  fail "tag $TAG already exists locally"
fi
if git ls-remote --tags origin "$TAG" | grep -q "$TAG"; then
  fail "tag $TAG already exists on origin"
fi

# --- locate the milestone for this series -----------------------------------
# Milestone titles follow the convention "<Name> - vX.Y" (e.g. "Carl - v1.1").
MILESTONE_TITLE="$(gh api "repos/{owner}/{repo}/milestones?state=all&per_page=100" \
  --jq "map(select(.title | endswith(\"- v$SERIES\"))) | .[0].title // empty")"
[ -n "$MILESTONE_TITLE" ] || fail "no milestone matching '* - v$SERIES' found on GitHub"

MILESTONE_OPEN="$(gh api "repos/{owner}/{repo}/milestones?state=all&per_page=100" \
  --jq "map(select(.title | endswith(\"- v$SERIES\"))) | .[0].open_issues")"
MILESTONE_NUMBER="$(gh api "repos/{owner}/{repo}/milestones?state=all&per_page=100" \
  --jq "map(select(.title | endswith(\"- v$SERIES\"))) | .[0].number")"

# Friendly name is everything before the " - v" suffix ("Carl - v1.1" -> "Carl").
MILESTONE_NAME="${MILESTONE_TITLE%% - v*}"

if [ "$MILESTONE_OPEN" != "0" ]; then
  not_ready "milestone '$MILESTONE_TITLE' still has $MILESTONE_OPEN open issue(s)"
fi

# --- current build number (single source of truth: project.yml) -------------
CURRENT_BUILD="$(grep -E '^[[:space:]]*CURRENT_PROJECT_VERSION:' project.yml \
  | head -1 | sed -E 's/.*"([0-9]+)".*/\1/')"
[[ "$CURRENT_BUILD" =~ ^[0-9]+$ ]] || fail "could not read CURRENT_PROJECT_VERSION from project.yml"

# --- all good: emit facts ---------------------------------------------------
cat <<EOF
READY
VERSION=$VER
TAG=$TAG
SERIES=$SERIES
MILESTONE_TITLE=$MILESTONE_TITLE
MILESTONE_NAME=$MILESTONE_NAME
MILESTONE_NUMBER=$MILESTONE_NUMBER
RELEASE_TITLE=StandupBuddy - $MILESTONE_NAME - $TAG
TAG_MESSAGE=Release for Milestone: $MILESTONE_TITLE
CURRENT_BUILD=$CURRENT_BUILD
NEXT_BUILD=$((CURRENT_BUILD + 1))
EOF
