# Standup Buddy

A macOS app for writing daily standups. Log what you worked on, track blockers and gratitude items, pull in your calendar and GitHub pull requests, and generate a formatted standup message with one keystroke.

![Standup Buddy](standup-buddy-goose.jpg)

---

# For users

## What it does

Standup Buddy keeps a running log of work entries organized into three categories:

- **Standup** — tasks worked on each day; automatically split into *Previous* (last workday) and *Today* sections when generating
- **Blocker** — open items that stay in the output until manually closed
- **Gratitude/Joy/Others** — open items similar to blockers

The main window has two tabs:

- **Entries** — add, edit, and complete your log entries
- **Quick Preview** — a read-only look at your current sections

The window toolbar holds three actions:

- **Import from Calendar** — pull today's calendar events in as entries (see [Calendars](#calendars))
- **Generate** (`⌘⇧G`) — open the standup output window
- **Settings** (gear) — open Settings

## Generating a standup

When you generate a standup (`⌘⇧G`), the app produces a Markdown-formatted message and opens it in the **Standup Output** window:

```
*Previous:*
* Fixed the login bug

*Today:*
* Reviewing the auth PR

*Blockers:*
* None

*Open Pull Requests:*
* My Repo: [Fix login flow](https://github.com/...)

*Gratitude/Joy/Others:*
* Great team retro today
```

The output window has two tabs:

- **Preview** — the rendered result, with clickable links
- **Text** — the editable Markdown source. A formatting toolbar lets you apply **bold**, *italic*, underline, ~~strikethrough~~, links, inline code, and code blocks; insert an emoji (via the macOS character palette); and insert any built-in or custom replacement token. Underline is disabled when the Slack flavor is selected, since Slack has no underline.

Edits you make in the Text tab are reflected in the Preview. When you're happy with it, click **Copy to Clipboard**. The current [Markdown flavor](#markdown-flavor) is shown in the top-right corner of the window.

## Markdown flavor

Standup Buddy can emit two Markdown dialects, selected under **Settings → General → Markdown Engine**:

- **Slack mrkdwn** (default) — single-asterisk `*bold*`, underscore `_italics_`, single-tilde `~strikethrough~`, and no underline. Links use `[text](url)`, which the Slack message composer auto-links.
- **GitHub-Flavored Markdown** — the familiar `**bold**`, `*italics*`, `~~strikethrough~~`, and `<u>underline</u>`.

The chosen flavor drives the section headers (`*Today:*` vs `**Today:**`), the editor toolbar, and how the preview is rendered, so the formatting buttons always insert the tokens that match where you'll paste the result.

## Text replacements

Entry text can include special tokens that are expanded at generate time:

| Token | Expands to |
|---|---|
| `{dad_joke}` | A random dad joke from [icanhazdadjoke.com](https://icanhazdadjoke.com). |
| `{today}` | The current workday name (e.g. `Friday`). Accepts an optional strftime format: `{today('%A')}`. |
| `{format_date}` | A synonym for `{today}`. |
| `{previous}` | The previous workday name (e.g. `Friday`). Accepts an optional strftime format: `{previous('%Y-%m-%d')}`. |
| `{yesterday}` | A synonym for `{previous}`. |
| `{fun_fact}` | A random fun fact from [uselessfacts.jsph.pl](https://uselessfacts.jsph.pl). |
| `{affirmation}` | A random positive affirmation from [affirmations.dev](https://www.affirmations.dev). |
| `{emoji_of_day}` | A consistent emoji for today's date — changes each day, the same for everyone. |
| `{entry_date}` | The date of the entry the token appears in (e.g. `2025-06-02`). Accepts an optional strftime format: `{entry_date('%A')}`. |

Each built-in token can be toggled on or off, and custom regex-based replacements can be configured — see [Settings](#settings) below.

## Settings

Settings is organized into tabs.

### General

- **Markdown Engine** — choose the [Markdown flavor](#markdown-flavor).
- **Built-in Text Replacements** — toggle each token from the table above. Tokens that hit an external API (`{dad_joke}`, `{fun_fact}`, `{affirmation}`) can be disabled if you'd rather not make network calls; the date and emoji tokens require no network access.

### Database

On first launch Standup Buddy asks you to choose a folder for its single SQLite database file. Pick a folder inside iCloud Drive to sync between Macs, or any local folder for single-machine use.

You can move the database later under **Settings → Database**:

- **Change Folder…** — pick a new location. If the folder already contains a compatible Standup Buddy database, the app switches to it. If the folder is empty, you're asked whether to **move your current data** into it or **start fresh** with an empty database. The change is validated before it's applied, and your previous folder is left untouched if anything goes wrong.
- **Show in Finder** — reveal the current database file in Finder.

**Automatic backups.** Whenever Standup Buddy needs to upgrade the database to a new schema (after you install an app update) or replace it during a reset, it first writes a timestamped copy into a `Backups` subfolder of your data folder (e.g. `Backups/standupbuddy-backup-20260624-093015-premigration.sqlite`). Backups are never deleted automatically, so you can always restore an earlier copy by hand.

**Opening a newer database.** If the database in your folder was created by a *newer* version of Standup Buddy than the one you're running — for example, an older Mac syncing a file written by a newer one — the app won't risk opening it and reading against an unexpected schema. Instead it shows a dialog offering to **Quit Standup Buddy** (so you can update the app or move the file yourself), **Choose Different Folder…**, or **Start Fresh** — which backs the existing file up before creating a new, empty database.

### Sections

**Settings → Sections** controls which sections appear in generated standups and what they're called:

- Toggle any of **Previous**, **Today**, **Blockers**, **Open Pull Requests**, and **Gratitude/Joy/Others** on or off. Disabled sections are hidden from the preview and excluded from the generated output.
- Give any section a **custom header**. Leave it blank to use the default. Headers support text replacements like `{yesterday}` and `{format_date('%A')}`.
- **Hide empty sections** — when enabled, any section with no content is omitted entirely from the generated standup instead of showing a `* None` bullet. Off by default.

### Text Replacements

**Settings → Replacements** lets you define additional regex rules applied after the built-in tokens. Each rule has:

- **Pattern** — a regular expression matched against the entry text
- **Template** — the substitution string (supports capture group references like `$1`)
- **Sort Order** — controls the order rules are applied

Custom replacements also appear in the output editor's **Insert Replacement** menu.

### GitHub

To include your open pull requests in generated standups:

1. Create a GitHub [Personal Access Token](https://github.com/settings/tokens) with `repo` scope (classic) or `pull_requests:read` (fine-grained).
2. Open **Settings → GitHub** and paste the token into the Personal Access Token field, then click **Save**.
3. Add one or more repositories with **+**. Each repository requires an owner, a name (`owner/name`), and a display name shown in the standup output.

The token is stored in the macOS Keychain; it is never written to disk or included in any file tracked by the project.

### Calendars

Standup Buddy can turn today's calendar events into standup entries.

1. Open **Settings → Calendars** and click **Grant Calendar Access** (macOS will prompt for permission).
2. Enable the calendars you want to draw from. Calendars are grouped by account; to add Google, Exchange, or other calendars, add the account in **System Settings → Internet Accounts** and it will appear here automatically.
3. Back in the main window, click **Import from Calendar** in the toolbar. Pick the events you want and click **Add Events as Entries** — each becomes a Standup entry for today. Events you've declined are skipped.

## Checking for updates

**Check for Updates…** appears in the application menu, just after **About Standup Buddy**. It compares the running version against the latest published [GitHub release](https://github.com/bratta/StandupBuddy/releases) and tells you whether you're up to date or offers a **View Release** button to open the release page. The check is unauthenticated and requires only network access to the public repository.

## API Console

Choose **View → Show API Console Log** to open the **API Console**, which logs all outbound requests (dad jokes, fun facts, affirmations, GitHub, and update checks) and their responses. It's handy for debugging a GitHub token or network issue.

## Requirements

- macOS 26 (Tahoe) or later

---

# For contributors

## Build requirements

- macOS 26 (Tahoe) or later
- Xcode 26 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

The Xcode project is generated by XcodeGen from `project.yml` and is **not** committed. Always run `xcodegen generate` after pulling changes that touch the project configuration or after adding/removing source files. Swift Package dependencies (GRDB and MarkdownUI) are declared in `project.yml` and resolved by Xcode on first open.

## First-time setup

Two files contain signing identity and are not committed to the repository. Copy each example and fill in your values before building.

### project.yml

```bash
cp project.yml.example project.yml
```

Open `project.yml` and replace the two placeholders:

| Placeholder | Where to find it |
|---|---|
| `XXXXXXXXXX` (Team ID) | [Apple Developer → Account → Membership](https://developer.apple.com/account) — the 10-character string next to your name |
| `Your Provisioning Profile Name` | The name shown in Xcode → Settings → Accounts → Manage Certificates, or in the Apple Developer portal under Profiles |

For local development without a Developer Program membership, leave `DEVELOPMENT_TEAM` blank and set both `CODE_SIGN_IDENTITY` values to `"-"`.

### scripts/exportOptions.plist (release builds only)

```bash
cp scripts/exportOptions.plist.example scripts/exportOptions.plist
```

Open `scripts/exportOptions.plist` and replace the `XXXXXXXXXX` placeholders with your Team ID and fill in your certificate and provisioning profile names. This file is only needed when running `scripts/release.sh`.

## Building

1. Complete the first-time setup above.
2. Generate the Xcode project:
   ```
   xcodegen generate
   ```
3. Open the generated project:
   ```
   open StandupBuddy.xcodeproj
   ```
4. Build and run with `⌘R`.

## Running tests

```
xcodebuild test -project StandupBuddy.xcodeproj -scheme StandupBuddy -destination 'platform=macOS'
```

Or run the test suite directly from Xcode with `⌘U`. Tests live in `Tests/` and cover the generator, text-replacement engine, workday calculation, update checker, database migration backups and safety guards, and supporting helpers.

### Testing the update checker

**Check for Updates…** compares the running version against the latest GitHub release. To exercise the "update available" path without bumping the version or publishing a release, set an environment variable that overrides the version the app reports for itself. This override only takes effect in **DEBUG** builds and is compiled out of release builds.

1. In Xcode, choose **Product → Scheme → Edit Scheme…** (`⌘<`).
2. Select **Run → Arguments**.
3. Under **Environment Variables**, add `UPDATE_CHECK_CURRENT_VERSION` with a value older than the latest release (e.g. `1.0.0`).
4. Run the app and choose **Check for Updates…** — it will report an update and the **View Release** button opens the GitHub release page.

Toggle the variable's checkbox to flip between the "update available" and "up to date" results without rebuilding. Remove or uncheck it to test against the real bundle version. The check hits the public `releases/latest` endpoint, so it requires the `bratta/StandupBuddy` repository to be public (or network access to it).

## Releasing

Releases are produced by `scripts/release.sh` (build, sign, notarize, and package the DMG) together with the helpers in `scripts/release/`. The versioned `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` live in the gitignored `project.yml`, so a version bump produces no committable change — a release is a tag on `main` plus a published GitHub release. The notarization step requires a keychain profile named `StandupBuddy`.
