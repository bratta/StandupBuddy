#!/usr/bin/env bash
# Archive the freshly built DMG and publish a GitHub release for the tag.
# Run only after ./scripts/release.sh has produced build/StandupBuddy.dmg and
# the tag has been pushed to origin.
#
# Usage:  scripts/release/publish.sh vX.Y.Z "<Milestone Name>"
#   e.g.  scripts/release/publish.sh v1.1.1 "Carl"
set -euo pipefail
cd "$(dirname "$0")/../.."

VERSION="${1:?usage: publish.sh vX.Y.Z \"<Milestone Name>\"}"
MILESTONE_NAME="${2:?usage: publish.sh vX.Y.Z \"<Milestone Name>\"}"
VER="${VERSION#v}"
TAG="v${VER}"

DMG="build/StandupBuddy.dmg"
ASSET="build/archive/StandupBuddy-${TAG}.dmg"
TITLE="StandupBuddy - ${MILESTONE_NAME} - ${TAG}"

[ -f "$DMG" ] || { echo "ERROR: $DMG not found — did ./scripts/release.sh succeed?" >&2; exit 1; }

mkdir -p build/archive
cp "$DMG" "$ASSET"
echo "→ Archived $ASSET"

echo "→ Creating GitHub release $TAG"
gh release create "$TAG" \
  --title "$TITLE" \
  --verify-tag \
  --generate-notes \
  "$ASSET"

echo "→ Released: $(gh release view "$TAG" --json url --jq .url)"
