# ClearShot

A fast, native macOS screenshot utility with a polished result UI and optional AI-powered analysis and editing via Google Gemini.

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-lightgrey)

## Why ClearShot

macOS's built-in screenshot tool is fine for a quick grab, but it doesn't let you *do* anything with what you just captured. ClearShot keeps the screenshot on screen after capture and gives you a real set of actions — copy, save, annotate, OCR, share, or hand it to an AI model to explain, summarize, or edit — all without leaving the keyboard.

## Features

- **Three capture modes** — full screen, click-and-drag region, or pick a specific window — each with its own configurable global shortcut.
- **A result UI that doesn't get in your way.** Screenshots open in a compact preview panel with actions instead of being silently copied and forgotten.
- **Extensible AI provider system.** Ships with Google Gemini; adding another provider means implementing one Swift protocol.
- **Ask AI** — explain, summarize, extract text, or answer a custom question about a screenshot.
- **Edit with AI** — describe a change in plain English and get back an edited image.
- **On-device OCR** — text extraction via Apple's Vision framework, no network request required.
- **Screenshot history** — a lightweight, configurable-retention local history with quick actions.
- **Secure by default** — API keys live only in the macOS Keychain, never in plist files or UserDefaults.
- **Native and fast** — built entirely on SwiftUI + AppKit, no Electron, no bloat.
- **Careful animations** — spring-based entrance/exit transitions throughout, with a global toggle to turn them off.
- Full dark mode, Retina, and keyboard-navigation support.

## Screenshots

- Placeholder
- Placeholder
- Placeholder

| Result panel | Region selection | Settings → Providers |
|---|---|---|
| ![Result panel](docs/screenshots/result-placeholder.png) | ![Region selection](docs/screenshots/region-placeholder.png) | ![Providers settings](docs/screenshots/providers-placeholder.png) |

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (used to generate the `.xcodeproj` — see below)
- A free [Google AI Studio](https://aistudio.google.com/apikey) API key if you want to use AI features (optional — the app is fully usable without one)

## Building

ClearShot's `.xcodeproj` is generated from [`project.yml`](project.yml) with XcodeGen rather than committed directly, so the project file never goes stale or produces noisy merge conflicts.

```bash
# 1. Install XcodeGen (one-time)
brew install xcodegen

# 2. Generate the Xcode project
cd ClearShot
xcodegen generate

# 3. Open and run
open ClearShot.xcodeproj
```

Build and run with `⌘R`. On first launch, ClearShot will ask for **Screen Recording** permission — this is required by macOS before any app can capture the screen.

## AI provider setup

1. Open **ClearShot → Settings → Providers**.
2. Get a free Gemini API key from [Google AI Studio](https://aistudio.google.com/apikey).
3. Paste it into the **Gemini** section and click **Save** — ClearShot immediately tests the connection.
4. Pick a model (defaults to `gemini-2.5-flash` for analysis; `gemini-2.5-flash-image` supports the **Edit with AI** flow).

Your key is stored in the macOS Keychain and is only ever sent directly to Google's API over HTTPS when you explicitly trigger an AI action. **API usage is billed by Google according to their own pricing** — ClearShot does not mark up or charge for AI usage itself.

Want to add another provider (OpenAI, Anthropic, a local model, etc.)? Implement the `AIProvider` protocol in `ClearShot/AI/AIProvider.swift` and register an instance in `AIProviderManager`. Nothing else in the app needs to change.

## Keyboard shortcuts

All shortcuts are re-bindable in **Settings → Shortcuts**.

| Action | Default shortcut |
|---|---|
| Open capture chooser | `⌘⇧Space` |
| Full-screen screenshot | `⌘⇧3` |
| Region screenshot | `⌘⇧4` |
| Window screenshot | `⌘⇧⌃5` |

## Privacy

- Screenshots and history are stored **only** in your local `~/Library/Application Support/ClearShot` folder.
- API keys are stored **only** in the macOS Keychain.
- On-device OCR uses Apple's Vision framework — nothing is uploaded for text extraction.
- A screenshot is sent to an AI provider **only** when you explicitly choose "Ask AI" or "Edit with AI."
- ClearShot collects no analytics or telemetry of any kind.

Full details are always visible in **Settings → Privacy**.

## Architecture

```
ClearShot/
├── App/            App entry point, AppDelegate, hotkey wiring
├── Capture/        Screen capture service, region/window selection overlays
├── Models/         Screenshot & provider data models
├── AI/             AIProvider protocol, Gemini implementation, provider manager
├── Security/       Keychain-backed API key storage
├── History/        Local history persistence + browsing UI
├── Shortcuts/       Global hotkey manager (Carbon) + shortcut recorder UI
├── UI/
│   ├── ResultWindow/   Screenshot preview + action panel, AI prompt sheet
│   ├── MenuBar/        Menu bar dropdown
│   ├── Settings/       Settings window (General/Shortcuts/Providers/Appearance/Privacy/About)
│   └── Components/     Shared buttons, toasts, permission primer
└── Utilities/      App settings, image/file helpers, OCR, error presentation
```

Screenshot capture uses `CGWindowListCreateImage` rather than macOS 14's `SCScreenshotManager` so the app can genuinely support the macOS 13 baseline stated in its requirements; this is the one deliberate use of a soon-to-be-legacy API and is called out here for transparency. A ScreenCaptureKit-based capture path would be a natural next step for a macOS 14+-only fork.

The app is **not sandboxed** (see `ClearShot.entitlements`), which is standard for GitHub-distributed macOS utilities that need global hotkeys and unrestricted screen capture. See the comment in that file if you're adapting this for Mac App Store distribution.

## License

Released under the [MIT License](LICENSE).
