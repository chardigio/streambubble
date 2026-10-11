import AppKit
import StreamBubbleKit

/// The bubble's right-click menu: the same commands as the menu bar menu, next to the bubble.
///
/// A SwiftUI `MenuBarExtra` cannot be shown at another place, so this builds a plain `NSMenu`
/// from the same `AppModel` values. It is built again on each right click, so the titles,
/// checkmarks, and disabled items always match the current state.
@MainActor
enum BubbleContextMenu {
    static func make(for model: AppModel) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let state = model.state

        let status = NSMenuItem(title: model.statusTitle, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        if let warning = model.hotKeyWarning {
            let item = NSMenuItem(title: warning, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(.separator())

        // The key equivalents only show the global hotkeys. Carbon handles the presses.
        menu.addItem(ActionItem(model.toggleTitle, key: "l", enabled: state.canToggle) { model.flow.toggle() })
        if state.canPauseToggle {
            menu.addItem(ActionItem(state == .paused ? "Resume" : "Pause", key: "p") { model.flow.togglePause() })
        }
        menu.addItem(.separator())

        let header = NSMenuItem(title: "Record", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for mode in CaptureMode.allCases {
            let item = ActionItem(mode.title, enabled: !state.isBusy) { model.captureMode = mode }
            item.state = model.captureMode == mode ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let sizes = NSMenu()
        for size in BubbleSize.allCases {
            let item = ActionItem(size.title) { model.setBubbleSize(size) }
            item.state = model.bubbleSize == size ? .on : .off
            sizes.addItem(item)
        }
        menu.addItem(submenu("Bubble Size", sizes))

        let borders = NSMenu()
        let ring = ActionItem("White Ring") { model.bubbleStyle.showsRing.toggle() }
        ring.state = model.bubbleStyle.showsRing ? .on : .off
        borders.addItem(ring)
        let shadow = ActionItem("Drop Shadow") { model.bubbleStyle.showsShadow.toggle() }
        shadow.state = model.bubbleStyle.showsShadow ? .on : .off
        borders.addItem(shadow)
        menu.addItem(submenu("Bubble Border", borders))
        let blur = ActionItem("Blur Background…") { model.openVideoEffects() }
        blur.state = model.isBackgroundBlurOn ? .on : .off
        menu.addItem(blur)
        menu.addItem(ActionItem("Hide Camera Bubble") { Task { await model.setBubbleShown(false) } })
        menu.addItem(.separator())

        menu.addItem(ActionItem("Open Recordings Folder") { model.openRecordingsFolder() })
        menu.addItem(ActionItem("Quit StreamBubble", enabled: !state.isBusy) { NSApp.terminate(nil) })
        return menu
    }

    private static func submenu(_ title: String, _ submenu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }
}

/// An `NSMenuItem` that runs a closure, so the menu needs no target object with selectors.
@MainActor
private final class ActionItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, key: String = "", enabled: Bool = true, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: key)
        target = self
        isEnabled = enabled
        if !key.isEmpty { keyEquivalentModifierMask = [.command, .control, .option, .shift] }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func run() { handler() }
}
