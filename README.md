<p align="center"><img src="assets/logo-1024.png" width="112" alt="Bustelo app icon"></p>
<h1 align="center">Bustelo</h1>
<p align="center">Keep your Mac awake and active.</p>
<p align="center"><a href="https://github.com/swlittles/Bustelo/actions/workflows/ci.yml"><img src="https://github.com/swlittles/Bustelo/actions/workflows/ci.yml/badge.svg" alt="Build and tests"></a> · macOS 13+ · Swift + AppKit · MIT</p>

Bustelo is a small menu-bar app with two jobs:

1. **Keep the Mac awake.** The display stays on and the Mac won't idle sleep while a session runs.
2. **Keep the Mac active.** macOS treats a few minutes without keyboard or mouse input as idle. Bustelo resets that idle timer without clicking, typing, or moving the pointer.

It's a focused take on [Amphetamine](https://apps.apple.com/app/amphetamine/id937984704): one menu, a few durations, nothing else. No account and no analytics. The only network request is the update check to GitHub, which you can turn off.

## Use it

Click the cup in the menu bar.

| Menu item | What it does |
| --- | --- |
| Turn On / Turn Off | Keep the Mac awake until you turn it off |
| Turn On For ▸ | Indefinitely, or 15 minutes to 8 hours. While on, it's titled Keep Awake For and a checkmark shows the current length |
| Stay Active | Reset the idle timer while a session runs (on by default) |
| Turn On When Bustelo Opens | Start a session at launch; pair with Open at Login |
| Open at Login | Launch Bustelo when you log in |
| Check for Updates Automatically | Check GitHub daily for a new release (on by default) |
| Check for Updates… | Check now, and install when you're ready |

The cup is filled while a session is running. A small dot on it means an update is ready. Bustelo never interrupts you with an update window. If a session is running when you install an update, it resumes after the relaunch.

## How Stay Active works, and why it's safe

macOS tracks the system idle time, which is seconds since the last keyboard or mouse input. Keeping the screen on doesn't reset it, so with Amphetamine-style power assertions alone the Mac still counts as idle.

Bustelo resets it with a **no-op modifier event**: a "modifier keys changed" event reporting exactly the modifiers already held, which is normally none. The window server counts it as input, but no key goes down, no text is typed, and the pointer never moves or clicks. Apps see that nothing changed. The pointer never moves, so hover tooltips, video controls, and auto-hidden cursors stay as they are.

Bustelo also sends it only when it can't get in your way:

- **Only after 60 seconds without real input.** While you're working it does nothing. Idle checks typically wait several minutes, so 60 seconds leaves plenty of margin.
- **Never while a mouse button is held**, so it can't interfere with a click or drag.
- **Never while the screen is locked.** A locked Mac is treated as idle as usual.
- **Never while the display is asleep or the screen saver is running**, so it won't wake a screen you turned off on purpose.
- **Never while another user owns the screen** (fast user switching).

The menu shows when Bustelo is paused for one of these reasons.

We tested several approaches before choosing this one:

| Approach | Resets the system idle time? | Side effects |
| --- | --- | --- |
| Power assertion only (Amphetamine, `caffeinate`) | No | — |
| `IOPMAssertionDeclareUserActivity` | No | — |
| Event sent only to Bustelo's own process | No (resets the HID counter only) | — |
| Mouse move to the pointer's current position | Yes | Delivered to the app under the pointer; can reveal hidden cursors and video controls |
| **No-op modifier event (Bustelo)** | **Yes** | **None observed** |

Sending events requires **Accessibility** permission. Bustelo asks the first time it needs it; you can also enable it under **System Settings → Privacy & Security → Accessibility**. Bustelo never reads your input. It only checks how long you've been idle.

## Install

Download the latest `Bustelo-…-macos-universal.dmg` from **[Releases](https://github.com/swlittles/Bustelo/releases)**, open it, and drag **Bustelo** into **Applications**. Releases are universal (Apple Silicon and Intel), signed with Developer ID, and notarized by Apple.

From 1.1.0 on, Bustelo updates itself through [Sparkle](https://sparkle-project.org). The update feed and every download are signed, and each update is verified before it's installed. Version 1.0.0 has no updater, so install 1.1.0 manually once.

## Build from source

Requires macOS 13+ and the Xcode Command Line Tools (full Xcode isn't needed).

```sh
bash scripts/test.sh        # logic tests
bash scripts/build.sh       # dist/Bustelo Dev.app (ad-hoc signed, separate bundle ID)
open "dist/Bustelo Dev.app"
```

Ad-hoc builds change identity on every rebuild, so macOS may ask you to re-enable Accessibility afterwards.

To test the nudge without waiting a minute:

```sh
"dist/Bustelo Dev.app/Contents/MacOS/Bustelo Dev" -StartOnLaunch YES -NudgeAfterSeconds 5
```

### Releasing

Bump `VERSION` and `BUILD_NUMBER`, add a matching `## x.y.z` section to `CHANGELOG.md`, then push a `vX.Y.Z` tag. The Release workflow tests, builds a universal app, signs it with Developer ID, notarizes and staples the app and DMG, signs the Sparkle appcast, and publishes a GitHub release. It needs these repository secrets: `DEVELOPER_ID_P12_BASE64`, `DEVELOPER_ID_P12_PASSWORD`, `SPARKLE_ED_PRIVATE_KEY`, plus either `NOTARY_APPLE_ID` + `NOTARY_APP_PASSWORD` or `NOTARY_API_KEY_P8` + `NOTARY_KEY_ID` + `NOTARY_ISSUER_ID`.

## Responsible use

Use Bustelo in line with any policies that apply to your Mac.

## License

MIT. Includes [Sparkle](https://github.com/sparkle-project/Sparkle) (MIT; see `docs/THIRD_PARTY_NOTICES.txt`). Named after the coffee; not affiliated with or endorsed by Café Bustelo or the makers of Amphetamine.
