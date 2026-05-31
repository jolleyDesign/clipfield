# Contributing to Clipfield

Thanks for your interest in improving Clipfield! This guide covers how to set up
the project, how the codebase is organized, and the conventions we follow so that
contributions stay consistent and easy to review.

## Code of conduct

Be kind and constructive. We follow the spirit of the
[Contributor Covenant](https://www.contributor-covenant.org/): assume good faith,
keep discussions focused on the work, and make this a project people enjoy
contributing to.

## Prerequisites

- **macOS 14 (Sonoma) or later** — the app targets `.macOS(.v14)`.
- **Full Xcode** (not just the Command Line Tools). Clipfield uses SwiftData and
  SwiftUI, which depend on closed-source macro plugins (`SwiftDataMacros`,
  `PreviewsMacros`) that ship only inside Xcode. `build_app.sh` points the build
  at `/Applications/Xcode.app` automatically; override with `DEVELOPER_DIR` if
  Xcode lives elsewhere.

No third-party package dependencies — the project is pure SwiftPM + Apple frameworks.

## Build & run

```sh
# Release build → Clipfield.app (ad-hoc signed), then launch it
./build_app.sh
open ./Clipfield.app

# Debug build
./build_app.sh debug

# Compile-only (fast iteration, no .app bundle)
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" swift build
```

`build_app.sh` compiles the SwiftPM executable, assembles a proper `.app` bundle
with `Info.plist` (`LSUIElement`, so there's no Dock icon), and **ad-hoc
code-signs** it. The ad-hoc signature is important: macOS keys the Accessibility
permission grant to the signature, so signing keeps your grant stable across
rebuilds. Run the bundled `.app` (not `swift run`) when you need launch-at-login
or a stable Accessibility grant — those require a real, signed bundle.

> **Note:** `package_dmg.sh` is for producing a signed + notarized DMG with an
> Apple Developer ID and is not needed for day-to-day development.

## Project layout

```
Sources/Clipfield/
  App/        @main app, AppDelegate (status item + window wiring), launch-at-login,
              Accessibility-permission state
  Models/     SwiftData models (ClipItem, Folder, Snippet) + ClipKind / SmartTag enums
  Storage/    ModelContainer (DataController), HistoryStore (dedup/retention/clear),
              CryptoVault (at-rest encryption), first-launch SampleData
  Clipboard/  changeCount poller (ClipboardMonitor), pasteboard read/write,
              all-flavor capture, auto-paster
  Tagging/    on-device SmartTagger (NSDataDetector + regex + NaturalLanguage),
              TextTransform actions
  Search/     tag-aware SearchEngine
  Hotkeys/    Carbon global hotkey (HotKeyManager) + persisted binding (HotkeyStore)
  Privacy/    per-app exclusions (ExclusionManager)
  UI/         Theme, Settings tabs, and the overlay (panel/controller/view/rows/
              preview/search field)
```

### How it fits together (data flow)

1. **Capture.** `ClipboardMonitor` polls `NSPasteboard.changeCount` (there's no
   change notification). On a change, `PasteboardReader` builds a `CapturedClip`
   — picking the richest representation and capturing *all* flavors for a
   byte-perfect paste — unless the content is marked concealed or comes from an
   excluded app.
2. **Tag.** `SmartTagger` analyzes the text on-device to assign `SmartTag`s and
   refine the primary `ClipKind`.
3. **Store.** `HistoryStore` inserts into SwiftData with de-duplication (by a
   non-reversible content hash) and retention pruning. Payloads are written
   through `CryptoVault`, which transparently encrypts at rest when enabled.
4. **Pick.** The global hotkey (`HotKeyManager`) toggles the overlay
   (`OverlayController` → `OverlayView`). Selecting an item asks the controller
   to paste.
5. **Paste.** `ClipboardWriter` restores the clip to the pasteboard and `Paster`
   refocuses the previous app and synthesizes ⌘V (requires Accessibility; until
   granted, the item is just copied).

## Coding conventions

The codebase is small and deliberately consistent. Please match the surrounding
style rather than introducing new patterns:

- **Comments explain *why*, not *what*.** Most types carry a short doc comment
  describing their role; non-obvious decisions (AppKit quirks, async activation,
  encryption invariants) get an inline note. Keep this up — it's the main reason
  the code reads well.
- **`// MARK:` sections** group related members within a file. Follow the existing
  grouping in larger files (e.g. `OverlayView`, `SettingsView`).
- **Access control:** prefer `private` for view internals and helpers. Swift's
  `private`/`fileprivate` are file-scoped, so keep a type and its private members
  in one file rather than splitting across extensions.
- **UI is `@MainActor`.** The app uses Swift 5 language mode (see `Package.swift`)
  to avoid fighting strict-concurrency diagnostics in AppKit/SwiftUI code.
- **Shared visual constants live in `Theme`** (corner radii, accent gradient,
  springs). Reach for `Theme.selectionSpring` / `Theme.promptSpring` rather than
  re-declaring animation literals.
- **UserDefaults keys** are centralized as `static let` constants on the relevant
  type (`AppearanceKeys`, `HotkeyStore`, `HistoryStore.retentionLimitKey`,
  `CryptoVault.enabledDefaultsKey`). Add new keys there, not as inline string
  literals.
- **Privacy first.** Everything stays on-device. Don't add network calls,
  analytics, or telemetry. Honor the concealed-type markers and app exclusions.
- Indentation is 4 spaces; no trailing whitespace. There is no enforced linter,
  so a clean `git diff` and matching the local style is the bar.

## Common extension points

These are designed to be easy to extend — a good place to start:

- **A new smart tag:** add a case to `SmartTag` (with `systemImage` + `label`),
  detect it in `SmartTagger.analyze`, and — if it can be a clip's primary type —
  add it to `ClipKind` and `SmartTagger.refinedKind`. It becomes searchable and
  filterable automatically (`SearchEngine` keys off `SmartTag`).
- **A new text transform:** add a case to `TextTransform` with a `label` and an
  `apply(to:)` implementation. It appears in the row's "Transform & Paste" menu.
- **A new setting:** add a key to `AppearanceKeys` (or the relevant store) and a
  control in the matching `SettingsView` tab.

## Submitting changes

1. **Fork** the repo and create a topic branch (`git checkout -b my-change`).
2. **Make focused commits** with clear messages. Keep unrelated changes in
   separate PRs.
3. **Build and exercise the app** before opening a PR — there is no automated
   test suite yet (see below), so manual verification of the affected flow is
   expected. Note in the PR what you tested.
4. **Open a pull request** describing *what* changed and *why*. Screenshots or a
   short clip help a lot for UI changes.
5. A maintainer will review. Expect a round or two of feedback — it's normal and
   keeps the bar high.

### What makes a PR easy to merge

- Scoped to one concern.
- Matches the existing style and comment density.
- Doesn't widen access control or add dependencies without a reason.
- Preserves the privacy guarantees (local-only, honors exclusions/concealed types).

## Testing

There is currently **no automated test suite.** The tagging, search, text
transforms, and crypto encode/decode helpers are pure and would be the natural
first candidates for unit tests — contributions adding a `Tests/` target with
SwiftPM `XCTest` are very welcome.

## Reporting bugs & requesting features

Open a GitHub issue. For bugs, include your macOS version, steps to reproduce,
and what you expected vs. what happened. For clipboard-capture issues, the source
app and content type are especially useful.

## License

By contributing, you agree that your contributions are licensed under the
project's [MIT License](LICENSE).
