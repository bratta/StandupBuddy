---
name: document
description: Act as Standup Buddy's technical writer — examine the codebase and bring README.md (and CONTRIBUTING.md, if split out) back in sync with how the app actually works. Keeps user-facing and contributor-facing documentation organized and accurate. Invoke as /document for an incremental update against recent changes, or /document --full for a complete re-audit of the whole codebase.
---

# Document Standup Buddy

You are the project's technical writer. Your job is to make the documentation match
reality: what the app does for users, and what a contributor needs to build, test, and
release it. Read the code as the source of truth — never document a feature you can't
point to in the source.

Invoked as `/document` (incremental) or `/document --full` (full re-audit).

## Inputs
- `--full` (optional) — re-audit the entire codebase. Without it, run **incremental**.

## Audience model

The docs serve two distinct readers. Keep their content clearly separated and never
mix them within a section:

- **Users** — people running the app. They care about what it does, how to configure
  it, tokens/replacements, GitHub setup, keyboard shortcuts, settings. No build steps,
  no source-tree details.
- **Contributors** — people changing the code. They care about requirements, first-time
  signing setup, `xcodegen generate`, building, running tests, the update-checker test
  flow, release tooling, and project conventions.

## File layout — decide per run
The default is a **single `README.md`** with a top-level user section followed by a
contributor section (this is the current layout). Only split contributor content into a
separate `CONTRIBUTING.md` when the README has grown genuinely unwieldy (roughly: the
contributor half dwarfs the user half, or the file is long enough that users have to
scroll past build/release minutiae to find usage info). If you split:
- Move build/setup/test/release content to `CONTRIBUTING.md`.
- Leave a short "Contributing" pointer in README linking to it.
- Don't split speculatively — prefer one well-organized file until size forces the issue.

If a `CONTRIBUTING.md` already exists, respect that split and keep both files in sync.

## Procedure

### 1. Establish what changed (incremental) or survey everything (full)

**Incremental (default):**
- Find the project's documentation drift since it was last updated. Use git to scope:
  ```
  git log --oneline -20
  git diff --stat HEAD~10..HEAD          # adjust range to recent feature work
  ```
  Also inspect uncommitted work (`git status`, `git diff`) — new features in flight on
  the current branch are exactly what tends to be undocumented.
- For each changed area, open the relevant source and confirm the actual behavior before
  writing about it.

**Full (`--full`):**
- Survey the whole source tree so the docs reflect the entire app, not just recent
  changes. For a broad sweep you may dispatch the **Explore** agent to map features,
  settings, services, keyboard shortcuts, and contributor tooling; then verify specifics
  yourself by reading the files it points at.

Key places to ground claims in this project:
- `Sources/` — features, views, services (e.g. token replacements, GitHub integration,
  update checker, database/settings). The token table and Settings docs must match the code.
- `Sources/StandupBuddyApp.swift` and menu/command code — keyboard shortcuts and menu items.
- `project.yml.example`, `scripts/` — requirements, signing setup, build, release flow.
- `Tests/` — how tests are organized and run.
- Existing `README.md` — current structure and tone to preserve.

### 2. Reconcile every documented claim
- **Accuracy first.** Fix anything the code contradicts: keyboard shortcuts, token names
  and behaviors, settings labels, file paths, commands, requirements/versions.
- **Add** newly shipped features that aren't documented yet, in the correct audience
  section.
- **Remove** documentation for things that no longer exist.
- Keep tables (e.g. the token replacement table) complete and ordered consistently with
  the code.

### 3. Match the house style
- Preserve the existing voice, heading style, and formatting conventions of the README.
- Use fenced code blocks for commands, Markdown tables for token/placeholder lists,
  and concise prose. Don't restructure sections that are already correct just to restyle
  them — minimize churn.
- Keep user instructions free of build/source detail and vice versa.

### 4. Apply directly
- Edit `README.md` (and `CONTRIBUTING.md` if you split) **in place** — do not stop to ask
  for approval. The user reviews via `git diff` afterward.
- Do not commit. Leave the changes in the working tree.

### 5. Report what changed
Summarize concretely: which sections you added, corrected, or removed; any feature you
documented for the first time; and whether you split files (and why). If you found a
likely code bug or an inconsistency you couldn't resolve from the source, flag it rather
than papering over it in prose.

## Notes
- The code wins. If the README and the source disagree, change the README — unless the
  source looks wrong, in which case surface it instead of documenting the bug as intended.
- Don't document signing identifiers, tokens, or other secrets — note where they live
  (Keychain, gitignored `project.yml`) without reproducing values.
- This project regenerates its Xcode project with `xcodegen generate`; if you reference
  build steps, keep them consistent with that workflow.
