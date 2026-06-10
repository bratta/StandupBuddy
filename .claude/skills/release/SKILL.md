---
name: release
description: Cut a Standup Buddy release for a version (e.g. /release v1.1.1). Validates the matching GitHub milestone is fully closed, bumps the version + build number, tags, builds and notarizes the DMG, and publishes a GitHub release with auto-generated changelog. Refuses (and razzes the user) if the milestone still has open issues.
---

# Release Standup Buddy

Automates a full release. Invoked as `/release vX.Y.Z` (e.g. `/release v1.1.1`).
The version's `major.minor` series selects the GitHub milestone — `v1.1.1` maps to
the milestone titled `* - v1.1` (e.g. `Carl - v1.1`).

Helper scripts live in `scripts/release/` and do the deterministic work; this skill
orchestrates them and **stops at two confirmation checkpoints** (before pushing, and
before publishing) since those steps are public and hard to undo.

## Inputs
- `$VERSION` — the argument, normalized to `vX.Y.Z`. If the user omits it or it isn't
  well-formed, ask for it before doing anything.

## Procedure

### 1. Preflight (read-only — never skip)
Run `scripts/release/preflight.sh $VERSION` and read its stdout.

- **Exit 2 / `NOT_READY`** → the milestone still has open issues. **Stop.** Refuse to
  release and give the user good-natured grief about trying to ship with open issues
  (they asked for this). Print the milestone name and how many issues are still open,
  and point them at the milestone. Do **not** proceed.
- **Exit 1 / `ERROR`** → environment/repo problem (gh missing or unauthenticated, dirty
  tree, tag already exists, no matching milestone). Relay the error and stop.
- **Exit 0 / `READY`** → parse and remember the emitted `KEY=VALUE` facts:
  `VERSION TAG SERIES MILESTONE_TITLE MILESTONE_NAME RELEASE_TITLE TAG_MESSAGE NEXT_BUILD`.
  Use these verbatim in later steps — do not re-derive them.

### 2. Clean slate
The tree is already confirmed clean by preflight. Sync main:
```
git checkout main && git pull --rebase
```

### 3. Bump version + build
```
scripts/release/bump-version.sh $VERSION
```
This sets `MARKETING_VERSION` to the release version and increments
`CURRENT_PROJECT_VERSION` (Info.plist inherits both via `$(...)`), then runs
`xcodegen generate`. Note the printed `CURRENT_PROJECT_VERSION` (the new build number).

### 4. Tag the release (local, still reversible)
The version bump produces **no committable change**: `project.yml` (the source of truth
for `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`) is gitignored as it carries signing
identifiers, the generated `*.xcodeproj/project.pbxproj` is gitignored, and `Info.plist`
only references the values via `$(...)`. So there is nothing to `git commit` — the release
is just a tag on the current `main` HEAD. Confirm the tree is still clean, then tag:
```
git status --short          # expect no output — version files are gitignored
git tag -a $TAG -m "$TAG_MESSAGE"
```
`$TAG_MESSAGE` is `Release for Milestone: <MILESTONE_TITLE>` from preflight.
(If `git status` *does* show tracked changes, stop and ask — that's unexpected for a bump.)

### 5. ⛔ CHECKPOINT — confirm before pushing
Show the user `git show --stat $TAG` (the tag and the HEAD commit it points at) and
summarize: version, new build number, milestone, and that the next steps push to origin
and start a notarized build. **Wait for explicit confirmation.** If they decline, tell
them how to undo locally (`git tag -d $TAG`) and stop.

### 6. Push
```
git push && git push origin $TAG
```
The branch push commonly reports `Everything up-to-date` (no release commit exists);
only the tag push is expected to transfer anything. That is normal — do not treat it
as a failure.

### 7. Build, sign, notarize, package
```
./scripts/release.sh
```
This is slow (notarization waits on Apple). If it fails, stop and surface the error —
the tag is already pushed, so a re-run continues from the build step. Confirm
`build/StandupBuddy.dmg` exists when it finishes.

### 8. ⛔ CHECKPOINT — confirm before publishing
Confirm the DMG built and that publishing will create a public GitHub release with the
asset and an auto-generated changelog. **Wait for explicit confirmation.**

### 9. Publish
```
scripts/release/publish.sh $VERSION "$MILESTONE_NAME"
```
This copies the DMG to `build/archive/StandupBuddy-$TAG.dmg`, then runs
`gh release create $TAG --title "$RELEASE_TITLE" --verify-tag --generate-notes <asset>`.
The `--generate-notes` flag produces the same "What's Changed / Full Changelog" format as
prior releases. Report the release URL it prints.

### 10. Wrap up
Summarize: version, build number, milestone, tag, release URL. Optionally suggest closing
the milestone on GitHub if it isn't already.

## Notes
- Never invent the milestone name — it always comes from preflight's output.
- `gh` auth and a working notarization keychain profile (`StandupBuddy`) are prerequisites;
  preflight checks the former, `scripts/release.sh` needs the latter.
- If anything fails mid-way, prefer stopping and explaining over guessing — releases are
  public and tags are awkward to retract.
