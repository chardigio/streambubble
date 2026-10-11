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

To build and run the app, see [Install](README.md#install).

## Code layout

- `StreamBubbleKit/` is a Swift package with the logic that needs no screen or camera: the
  recording flow, the pause timeline, the geometry, and the state machine. It has the tests.
- `StreamBubble/` is the app: ScreenCaptureKit, AVFoundation, and AppKit code.
- `brand/` has the app icon SVG masters. `scripts/make_appicon.sh` renders them.

## Questions?

Open an issue to ask a question or to discuss a change before you make it.
