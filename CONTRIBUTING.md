# Contributing to StreamBubble

Contributions are welcome: bug fixes, new features, documentation, and suggestions.

## How to contribute

1. Fork this repository.
2. Make a branch for your change.
3. Make your change. Add tests in `StreamBubbleKit/Tests` for each change to the logic.
4. Open a pull request against `main`.

## What happens when your PR is merged

StreamBubble is developed in a private monorepo. When your PR is merged into `main`, a
sync-back workflow applies your change to that monorepo. Your git author name and email stay
on the commit there. The next sync from the monorepo then brings the code back here with no
change.

## Development setup

```bash
git clone https://github.com/chardigio/streambubble.git
cd streambubble
brew install xcodegen
xcodegen generate                         # makes StreamBubble.xcodeproj
cd StreamBubbleKit && swift test          # logic tests
```

To build and run the app, see [Get started](README.md#get-started). To sign with your own
team, set `DEVELOPMENT_TEAM`: without it, `scripts/install.sh` uses the team in `project.yml`,
which builds only on the maintainer's Mac.

## Code layout

- `StreamBubbleKit/` is a Swift package with the logic that needs no screen or camera: the
  recording flow, the pause timeline, the geometry, and the state machine. It has the tests.
- `StreamBubble/` is the app: ScreenCaptureKit, AVFoundation, and AppKit code.
- `brand/` has the app icon SVG masters. `scripts/make_appicon.sh` renders them.

## How it works

* **The bubble is a real window.** ScreenCaptureKit records it like any other window, so you
  can move it while you record. The recorder leaves out the app's other windows. In region
  mode, the app moves the bubble into the region if it is outside, and shrinks it to fit.
* **The flow** (prepare, count down, start, pause, stop) is `RecordingFlow` in the Kit.
  `AppModel` is its host and does each step with the real windows and stream. The tests
  drive the flow with a fake host and a fake clock.
* **The file ends** after the last buffer on either track, so the final words stay in when
  the screen is still.
* **Pause** needs `SCStream` + `AVAssetWriter`, not `SCRecordingOutput`, which cannot pause.
  `PauseTimeline` drops the buffers while paused and removes the gap from later times.
* **Hotkeys** use Carbon `RegisterEventHotKey`, which needs no Accessibility permission.
* **The drop shadow** is drawn by the app in the bubble window, not by the window server, so
  the video shows the same shadow as the screen.
* **Blur** is the macOS Portrait video effect. Only the user can turn it on, so the menu item
  opens the system Video Effects panel and shows a checkmark while Portrait is on.

## App icon

The icon is "Glass Ring Coral": a frosted window with a glass `record.circle` face bubble, on
a coral tile. The SVG masters are in `brand/`: `build.py` writes `app-icon.svg`, and
`app-icon-16.svg` is a simpler drawing for 16 px only, where the face turns into noise. To
change the icon, edit a master and run `scripts/make_appicon.sh`, which renders each size into
`StreamBubble/Assets.xcassets/AppIcon.appiconset`.

## Questions?

Open an issue to ask a question or to discuss a change before you make it.
