# Standup Buddy

A macOS app for writing daily standups. Log what you worked on, track blockers and gratitude items, connect your GitHub repositories, and generate a formatted standup message with one keystroke.

![Standup Buddy](standup-buddy-goose.jpg)

## What it does

Standup Buddy keeps a running log of work entries organized into three categories:

- **Standup** — tasks worked on each day; automatically split into *Previous* (last workday) and *Today* sections when generating
- **Blocker** — open items that stay in the output until manually closed
- **Gratitude/Joy/Others** — open items similar to blockers

When you generate a standup (`⌘⇧G`), the app produces a Markdown-formatted message:

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

The output is copied to the clipboard and shown in a preview sheet for review before use.

### Text replacements

Entry text can include special tokens that are expanded at generate time:

| Token | Expands to |
|---|---|
| `{dad_joke}` | A random dad joke from [icanhazdadjoke.com](https://icanhazdadjoke.com), prefixed with `:joy_cat:`. |
| `{today}` | The current date name (e.g. `Friday`). Accepts an optional strftime format: `{today('%A')}`. |
| `{format_date}` | A synonym for `{today}`. |
| `{previous}` | The previous workday name (e.g. `Friday`). Accepts an optional strftime format: `{previous('%Y-%m-%d')}`. |
| `{yesterday}` | A synonym for `{previous}` |
| `{fun_fact}` | A random fun fact from [uselessfacts.jsph.pl](https://uselessfacts.jsph.pl). |
| `{affirmation}` | A random positive affirmation from [affirmations.dev](https://www.affirmations.dev). |
| `{emoji_of_day}` | A consistent emoji for today's date — changes each day, the same for everyone. |

Custom regex-based replacements can also be configured in Settings → Text Replacements. Each rule has a pattern and a substitution template and is applied in sort-order after the built-in tokens.

## Requirements

- macOS 26 (Tahoe) or later
- Xcode 26 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

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
xcodebuild test -project StandupBuddy.xcodeproj -scheme StandupBuddyTests -destination 'platform=macOS'
```

Or run the test suite directly from Xcode with `⌘U`.

## Configuration

### Database folder

On first launch Standup Buddy asks you to choose a folder for its single SQLite database file. Pick a folder inside iCloud Drive to sync between Macs, or any local folder for single-machine use.

You can move the database later under **Settings → Database**:

- **Change Folder…** — pick a new location. If the folder already contains a compatible Standup Buddy database, the app switches to it. If the folder is empty, you're asked whether to **move your current data** into it or **start fresh** with an empty database. The change is validated before it's applied, and your previous folder is left untouched if anything goes wrong.
- **Show in Finder** — reveal the current database file in Finder.

### GitHub integration

To include your open pull requests in generated standups:

1. Create a GitHub [Personal Access Token](https://github.com/settings/tokens) with `repo` scope (classic) or `pull_requests:read` (fine-grained).
2. Open **Settings → GitHub** and paste the token into the Personal Access Token field, then click **Save**.
3. Add one or more repositories with **+**. Each repository requires an owner, a name (`owner/name`), and a display name shown in the standup output.

The token is stored in the macOS Keychain; it is never written to disk or included in any file tracked by the project.

### Text replacement toggles

**Settings → General** exposes toggles for all built-in replacement tokens:

- **`{dad_joke}`** — on by default; disable if you prefer not to hit the external API
- **`{format_date(...)}`** — on by default; disable to treat the token as literal text
- **`{yesterday}`** — on by default; no network call required
- **`{fun_fact}`** — on by default; disable if you prefer not to hit the external API
- **`{affirmation}`** — on by default; disable if you prefer not to hit the external API
- **`{emoji_of_day}`** — on by default; no network call required

### Custom replacements

**Settings → Text Replacements** lets you define additional regex rules applied after the built-in tokens. Each rule has:

- **Pattern** — a regular expression matched against the entry text
- **Template** — the substitution string (supports capture group references like `$1`)
- **Sort Order** — controls the order rules are applied

An **API Console** (`View → Show API Console Log`) logs all outbound requests and their responses, which is useful for debugging GitHub token or network issues.
