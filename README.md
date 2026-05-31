# Clipfield

A native macOS clipboard manager built in Swift (SwiftUI + AppKit + SwiftData).

- Menu-bar app (no Dock icon) that keeps a searchable history of everything you copy.
- Global hotkey (**⇧⌘V** by default) opens a Spotlight-style picker over any app.
- Pick an item → it's pasted into the app you were just using.
- Rich types: text, styled/RTF text, images, files, links.
- Smart auto-tagging (links, emails, phones, addresses, dates, colors, code, numbers)
  with type-filter chips and tag-aware search.
- Pin frequently used items and organize them into folders.
- Tracks how many times each item has been pasted.
- Private by default: content marked private by password managers is ignored, you can
  exclude specific apps, and all history stays local.
- Optional **encryption at rest**: clip and snippet contents are sealed with AES-GCM using a
  256-bit key kept in the macOS Keychain. Toggle it in **Settings → Security**.

## Requirements

- macOS 14 (Sonoma) or later.
- **Full Xcode installed.** The build uses closed-source SwiftData / SwiftUI macro plugins
  that ship only inside Xcode, not the standalone Command Line Tools. `build_app.sh` points
  the build at `/Applications/Xcode.app` automatically.

## Build & run

```sh
./build_app.sh            # release build → Clipfield.app (ad-hoc signed)
open ./Clipfield.app
```

For a debug build: `./build_app.sh debug`.

The script compiles the SwiftPM executable, assembles a proper `.app` bundle with `Info.plist`
(`LSUIElement`), and ad-hoc code-signs it (which keeps the Accessibility permission grant stable
across rebuilds).

## Permissions

- **Global hotkey**: works with no permission (Carbon `RegisterEventHotKey`).
- **Auto-paste**: synthesizing ⌘V requires **Accessibility** permission. A welcome window on
  first launch walks you through granting it (and live-updates when you do); reopen it any time
  from the menu-bar right-click menu → *Permissions & Welcome…*. Until granted, selecting an
  item still copies it so you can press ⌘V yourself.

## Distribution

`./package_dmg.sh` builds the release app and produces `Clipfield.dmg` (ad-hoc signed, for local
use). Shipping to other Macs without Gatekeeper warnings requires signing + notarizing with an
**Apple Developer ID** — the script prints the exact `codesign` / `notarytool` / `stapler` steps.

## Encryption at rest

Turn on **Settings → Security → “Encrypt clipboard data at rest.”** When enabled, the sensitive
payload of every clip and snippet (text, RTF/HTML, images, file references, raw pasteboard
flavors, snippet bodies) is stored as an AES-GCM sealed blob; it's decrypted transparently on
access. The 256-bit key lives in the macOS Keychain (data-protection keychain, available after
first unlock, device-local — it never syncs or migrates to another Mac), so this is **local
encryption only**, not a cross-device feature.

- Toggling the setting re-encrypts (or decrypts) your existing history in place.
- Metadata stays unencrypted so search, sorting, and de-duplication keep working: timestamps,
  source app, type/tags, and a **non-reversible content hash** used for dedup. (The hash is what
  enables matching duplicate captures without holding the plaintext.)
- Search remains fully live — it runs in memory over the decrypted values, not over the store.

## Usage

- **⇧⌘V** (or left-click the menu-bar icon): open the picker. Right-click the icon for
  Settings / Permissions / Quit.
- Type to search; query words that name a type (e.g. `email`, `link`, `image`) filter by tag.
- **↑ / ↓** move, **↩** paste, **⌥↩** paste as plain text, **⌘1–9** quick-paste, **⎋** dismiss.
- **⇥** add/remove from the paste stack, **⇧↩** paste the whole stack.
- **⌘E** edit before pasting, **⌘P** pin/unpin, **⌘⌫** delete (clears the search field first).
- **⌘[ / ⌘]** move between sidebar sections (All · Pinned · Snippets · folders).
- Right-click a row for paste-as-plain, copy, open link, reveal in Finder, transforms, pin,
  move-to-folder, and delete.
- **Snippets**: reusable text with `{{placeholder}}` fields — selecting one prompts to fill
  the fields, then pastes. Create/edit in the Snippets section.
- The footer **⌨ button** shows the full shortcut cheat-sheet.
- Resize the window (drag edges), the sidebar/preview (drag dividers), or collapse them.
- Change the hotkey, theme/size, retention, app exclusions, and launch-at-login in **Settings**.

## Project layout

```
Sources/Clipfield/
  App/        @main app, AppDelegate (wiring), launch-at-login, permission state
  Models/     SwiftData models (ClipItem, Folder, Snippet) + ClipKind / SmartTag enums
  Storage/    ModelContainer + HistoryStore (dedup, retention, clear), CryptoVault, sample data
  Clipboard/  changeCount poller, pasteboard read/write, all-flavor capture, auto-paster
  Tagging/    on-device smart tagger (NSDataDetector + regex + NaturalLanguage), text transforms
  Search/     tag-aware search engine
  Hotkeys/    Carbon global hotkey + persisted binding
  Privacy/    per-app exclusions
  UI/         Theme, Settings, and the overlay (panel/controller/view/rows/preview/search field)
```

## Contributing

Contributions are welcome! See **[CONTRIBUTING.md](CONTRIBUTING.md)** for setup,
a tour of the architecture and data flow, coding conventions, and common
extension points (adding a smart tag, a text transform, or a setting).

In short:

```sh
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" swift build   # compile
./build_app.sh && open ./Clipfield.app                                   # build + run
```

Everything stays on-device — please keep it that way (no network, analytics, or
telemetry).

## License

Clipfield is released under the [MIT License](LICENSE).
