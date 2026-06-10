#!/usr/bin/env bash
# Bump the marketing version and increment the build number, then regenerate
# the Xcode project. project.yml is the single source of truth — Info.plist
# pulls CFBundleShortVersionString/CFBundleVersion from these build settings.
#
# Usage:  scripts/release/bump-version.sh vX.Y.Z
#
# Prints the resulting MARKETING_VERSION and CURRENT_PROJECT_VERSION.
set -euo pipefail
cd "$(dirname "$0")/../.."

VERSION="${1:?usage: bump-version.sh vX.Y.Z}"
VER="${VERSION#v}"
[[ "$VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "ERROR: bad version '$VERSION'" >&2; exit 1; }

CURRENT_BUILD="$(grep -E '^[[:space:]]*CURRENT_PROJECT_VERSION:' project.yml \
  | head -1 | sed -E 's/.*"([0-9]+)".*/\1/')"
[[ "$CURRENT_BUILD" =~ ^[0-9]+$ ]] || { echo "ERROR: cannot read current build" >&2; exit 1; }
NEXT_BUILD=$((CURRENT_BUILD + 1))

# In-place edits (BSD sed). These keys each appear once in project.yml.
sed -i '' -E "s/(MARKETING_VERSION: )\"[^\"]*\"/\1\"$VER\"/" project.yml
sed -i '' -E "s/(CURRENT_PROJECT_VERSION: )\"[^\"]*\"/\1\"$NEXT_BUILD\"/" project.yml

# Verify the edits took.
grep -qE "MARKETING_VERSION: \"$VER\""        project.yml || { echo "ERROR: MARKETING_VERSION not updated" >&2; exit 1; }
grep -qE "CURRENT_PROJECT_VERSION: \"$NEXT_BUILD\"" project.yml || { echo "ERROR: CURRENT_PROJECT_VERSION not updated" >&2; exit 1; }

echo "→ Regenerating Xcode project"
xcodegen generate >/dev/null

echo "MARKETING_VERSION=$VER"
echo "CURRENT_PROJECT_VERSION=$NEXT_BUILD"
