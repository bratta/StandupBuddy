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
| `{dad_joke}` | A random dad joke from [icanhazdadjoke.com](https://icanhazdadjoke.com), prefixed with `:joy_cat:` |
| `{format_date('%A')}` | The entry's date formatted using POSIX `strftime` format strings |

Custom regex-based replacements can also be configured in Settings → Text Replacements. Each rule has a pattern and a substitution template and is applied in sort-order after the built-in tokens.

## Requirements

- macOS 26 (Tahoe) or later
- Xcode 26 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Building

1. Clone the repository.
2. Generate the Xcode project from `project.yml`:
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

### GitHub integration

To include your open pull requests in generated standups:

1. Create a GitHub [Personal Access Token](https://github.com/settings/tokens) with `repo` scope (classic) or `pull_requests:read` (fine-grained).
2. Open **Settings → GitHub** and paste the token into the Personal Access Token field, then click **Save**.
3. Add one or more repositories with **+**. Each repository requires an owner, a name (`owner/name`), and a display name shown in the standup output.

The token is stored in the macOS Keychain; it is never written to disk or included in any file tracked by the project.

### Text replacement toggles

**Settings → General** exposes toggles for the two built-in replacement tokens:

- **`{dad_joke}`** — on by default; disable if you prefer not to hit the external API
- **`{format_date(...)}`** — on by default; disable to treat the token as literal text

### Custom replacements

**Settings → Text Replacements** lets you define additional regex rules applied after the built-in tokens. Each rule has:

- **Pattern** — a regular expression matched against the entry text
- **Template** — the substitution string (supports capture group references like `$1`)
- **Sort Order** — controls the order rules are applied

An **API Console** (`View → Show API Console Log`) logs all outbound requests and their responses, which is useful for debugging GitHub token or network issues.
