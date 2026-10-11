# StreamBubble

A Mac menu bar app that records the screen, and a round camera bubble
with your face floats on the screen, so the video shows you too.

## Install

You need macOS 15 or later, Xcode 16 or later, and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`). From this folder:

```bash
DEVELOPMENT_TEAM=<your team ID> scripts/install.sh
```

Use your own Apple team ID (Xcode > Settings > Accounts). A free personal team is enough. A
stable signature keeps the macOS permissions across rebuilds. If you leave the variable out,
the script uses the team in `project.yml`, which builds only on the maintainer's Mac.

The script builds a Release copy, puts it in `/Applications`, and opens it. The first time,
macOS asks for three permissions: Camera, Microphone, and Screen Recording. After you allow
Screen Recording, quit StreamBubble and open it again. macOS applies that grant only at launch.

## Use

| Action | Shortcut | Menu |
|---|---|---|
| Start or stop | Hyperkey+L (Cmd+Ctrl+Opt+Shift+L) | Start Recording / Stop Recording |
| Pause or resume | Hyperkey+P | Pause / Resume |
| Change the bubble size (5 sizes, 140 to 600 pt) | Click the bubble (next size) | Bubble Size (pick one) |
| Move the bubble | Drag the bubble | |
| Open the menu next to the bubble | Right-click (or Control-click) the bubble | |

* **Record** picks the full display (the one with the cursor) or a region that you drag out
  (at least 200 x 200 pt). A red dashed line marks the region. The line is not in the video.
* A 3-2-1 countdown shows before the recording starts. Start again during the countdown to cancel.
* The cursor shows in the video, and macOS draws a ring at each click.
* **Blur Background…** opens the macOS Video Effects panel. Turn on Portrait there, and use
  its slider to set how strong the blur is. The menu item has a checkmark while Portrait is on.
* **Bubble Border** has two toggles: **White Ring** (on by default) and **Drop Shadow**. Use
  one, both, or neither. The app draws the shadow itself, so the video shows the same shadow
  as the screen.
* If you deny the microphone, StreamBubble still records, with no sound, and tells you why.
* If another app owns a shortcut, the menu says so.
* The video goes to `~/Movies/StreamBubble/` as an `.mp4`, and Finder opens on it.

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

## App icon

The icon is "Glass Ring Coral": a frosted window with a glass `record.circle` face bubble, on
a coral tile. The SVG masters are in `brand/`: `build.py` writes `app-icon.svg`, and `app-icon-16.svg` is a
simpler drawing for 16 px only, where the face turns into noise. To change the icon, edit a
master and run `scripts/make_appicon.sh`, which renders each size into
`StreamBubble/Assets.xcassets/AppIcon.appiconset`.

## Develop

```bash
xcodegen generate                      # makes StreamBubble.xcodeproj (gitignored)
cd StreamBubbleKit && swift test       # logic tests: flow, timeline, geometry, state, names
```

`StreamBubbleKit` holds the logic that needs no screen or camera. The `StreamBubble` target
holds the ScreenCaptureKit, AVFoundation, and AppKit code.

## Contribute

Pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
