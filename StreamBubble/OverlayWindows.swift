import AppKit
import StreamBubbleKit

/// A borderless, click-through window above everything. The countdown and the region
/// outline use it.
@MainActor
class OverlayPanel: NSPanel {
    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
    }
}

/// The big 3-2-1 before the recording starts.
@MainActor
final class CountdownPanel: OverlayPanel {
    private let label = NSTextField(labelWithString: "")

    init(centeredIn rect: CGRect) {
        let side: CGFloat = 180
        super.init(frame: NSRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side))
        let background = NSView(frame: NSRect(x: 0, y: 0, width: side, height: side))
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.65).cgColor
        background.layer?.cornerRadius = side / 2
        label.font = .systemFont(ofSize: 96, weight: .bold)
        label.textColor = .white
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: background.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: background.centerYAnchor),
        ])
        contentView = background
    }

    func show(_ number: Int) {
        label.stringValue = "\(number)"
        orderFrontRegardless()
    }
}

/// A dashed outline just outside the recorded region, so the user can see the edges. It sits
/// outside the region and the recorder also excludes it, so it never shows in the video.
@MainActor
final class RegionOutlinePanel: OverlayPanel {
    init(region: CGRect) {
        let inset: CGFloat = -4
        super.init(frame: region.insetBy(dx: inset, dy: inset))
        let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        let border = CAShapeLayer()
        border.path = CGPath(rect: view.bounds.insetBy(dx: 1.5, dy: 1.5), transform: nil)
        border.fillColor = nil
        border.strokeColor = NSColor.systemRed.cgColor
        border.lineWidth = 3
        border.lineDashPattern = [10, 6]
        view.layer?.addSublayer(border)
        contentView = view
    }
}

/// Lets the user drag out the region to record, on any screen. Escape cancels.
@MainActor
final class RegionSelector {
    private var windows: [SelectionWindow] = []
    private var continuation: CheckedContinuation<(CGRect, CGDirectDisplayID)?, Never>?

    /// Returns the region in global AppKit coordinates and the display it is on.
    func select() async -> (CGRect, CGDirectDisplayID)? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            NSApp.activate()
            windows = NSScreen.screens.map { screen in
                let window = SelectionWindow(screen: screen)
                let displayID = screen.displayID
                window.onFinish = { [weak self] rect in self?.finish(rect.map { ($0, displayID) }) }
                window.makeKeyAndOrderFront(nil)
                return window
            }
            NSCursor.crosshair.push()
        }
    }

    private func finish(_ result: (CGRect, CGDirectDisplayID)?) {
        NSCursor.pop()
        windows.forEach { $0.orderOut(nil) }
        windows = []
        continuation?.resume(returning: result)
        continuation = nil
    }
}

@MainActor
private final class SelectionWindow: NSWindow {
    var onFinish: ((CGRect?) -> Void)?

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.onFinish = { [weak self] localRect in
            guard let self else { return }
            self.onFinish?(localRect.map { self.convertToScreen($0) })
        }
        contentView = view
    }

    override var canBecomeKey: Bool { true }
}

@MainActor
private final class SelectionView: NSView {
    var onFinish: ((CGRect?) -> Void)?
    private var start: NSPoint?
    private var current: NSPoint?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onFinish?(nil) } // Escape
    }

    override func mouseDown(with event: NSEvent) {
        start = convert(event.locationInWindow, from: nil)
        current = start
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let start, let current else { return }
        let rect = RegionGeometry.rect(from: start, to: current)
        self.start = nil
        self.current = nil
        needsDisplay = true
        if RegionGeometry.isUsable(rect) { onFinish?(rect) }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.35).setFill()
        bounds.fill()
        let hint = "Drag to choose the part of the screen to record. Press Esc to cancel."
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = hint.size(withAttributes: attributes)
        hint.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.maxY - 120), withAttributes: attributes)

        guard let start, let current else { return }
        let rect = RegionGeometry.rect(from: start, to: current)
        NSColor.clear.setFill()
        rect.fill(using: .copy)
        NSColor.white.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 2
        path.stroke()
        let label = "\(Int(rect.width)) × \(Int(rect.height))"
        label.draw(at: NSPoint(x: rect.minX, y: rect.minY - 26), withAttributes: attributes)
    }
}
