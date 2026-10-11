import AppKit
import AVFoundation
import StreamBubbleKit

/// The round camera window that floats over everything.
///
/// It is a real window on the screen, not a layer that the app draws into the video. That is
/// how Loom works too: what you see is what the file gets, and you can move the bubble while
/// you record. The recorder must not exclude this window from the capture.
@MainActor
final class BubbleWindow: NSPanel {
    private let bubbleView: BubbleView
    private let shadowView = ShadowView()
    private(set) var size: BubbleSize = .medium
    var style: BubbleStyle = .default {
        didSet { applyStyle() }
    }
    /// Tells the model about a size change that the window makes itself (a click on the
    /// bubble, or a shrink to fit a region), so the menu checkmark stays correct.
    var onSizeChange: ((BubbleSize) -> Void)?
    /// Builds the right-click menu. It is a closure so the menu is new on each click.
    var contextMenu: (() -> NSMenu?)? {
        get { bubbleView.contextMenu }
        set { bubbleView.contextMenu = newValue }
    }

    /// The circle on the screen. The window is larger, to leave room for the drop shadow.
    var circleFrame: NSRect { BubbleStyle.circle(inWindowFrame: frame) }

    init(session: AVCaptureSession) {
        bubbleView = BubbleView(session: session)
        let diameter = BubbleSize.medium.diameter
        super.init(
            contentRect: BubbleStyle.windowFrame(around: NSRect(x: 0, y: 0, width: diameter, height: diameter)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        // The app draws its own shadow (see BubbleStyle), so the screen and the video match.
        hasShadow = false
        level = .statusBar
        // Stay on screen on each Space and over full-screen apps, so a switch of Space while
        // recording does not lose the bubble.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovable = false // BubbleView moves the window itself, to tell a click from a drag.
        hidesOnDeactivate = false
        contentView = shadowView
        let room = BubbleStyle.shadowRoom
        bubbleView.frame = shadowView.bounds.insetBy(dx: room, dy: room)
        bubbleView.autoresizingMask = [.width, .height]
        shadowView.addSubview(bubbleView)
        bubbleView.onClick = { [weak self] in self?.cycleSize() }
        applyStyle()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// The default place: the bottom-left corner of the screen with the cursor.
    func placeAtDefaultPosition(on screen: NSScreen) {
        let origin = RegionGeometry.bubbleOrigin(diameter: size.diameter, in: screen.visibleFrame, margin: 32)
        setCircleFrame(NSRect(origin: origin, size: NSSize(width: size.diameter, height: size.diameter)))
    }

    /// Makes sure the video shows the whole bubble: when it is not fully inside `rect`, it
    /// shrinks to the largest size that fits and moves to the bottom-left corner of `rect`.
    func ensureVisible(in rect: CGRect) {
        guard !rect.contains(circleFrame) else { return }
        size = BubbleSize.largest(atMost: size, fittingIn: rect.size, margin: 24)
        onSizeChange?(size)
        let origin = RegionGeometry.bubbleOrigin(diameter: size.diameter, in: rect, margin: 24)
        setCircleFrame(NSRect(origin: origin, size: NSSize(width: size.diameter, height: size.diameter)))
    }

    func cycleSize() {
        setSize(size.next)
        onSizeChange?(size)
    }

    func setSize(_ newSize: BubbleSize) {
        guard newSize != size else { return }
        size = newSize
        let diameter = size.diameter
        let circle = circleFrame
        // Grow and shrink around the center, so the bubble stays where the user put it.
        var newCircle = NSRect(
            x: circle.midX - diameter / 2, y: circle.midY - diameter / 2,
            width: diameter, height: diameter
        )
        if let screen = screen ?? NSScreen.main {
            newCircle = RegionGeometry.clamp(newCircle, inside: screen.frame)
        }
        setCircleFrame(newCircle, animate: true)
    }

    private func setCircleFrame(_ circle: NSRect, animate: Bool = false) {
        setFrame(BubbleStyle.windowFrame(around: circle), display: true, animate: animate)
    }

    private func applyStyle() {
        bubbleView.ringWidth = style.ringWidth
        shadowView.shadowOpacity = style.shadowOpacity
    }
}

/// The window's clear content view. It draws the drop shadow of the circle in its middle.
///
/// The shadow is on a sublayer of its own: AppKit owns the shadow values of a view's backing
/// layer and resets them, so a shadow set there does not show. The sublayer has no content, and
/// `shadowPath` gives the shadow its round shape. The camera view cannot cast the shadow
/// itself: that view clips to its round shape, and the clip cuts off a shadow.
@MainActor
private final class ShadowView: NSView {
    var shadowOpacity: Float = 0 {
        didSet { updateShadow() }
    }
    private let shadowLayer = CALayer()

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        shadowLayer.shadowColor = NSColor.black.cgColor
        shadowLayer.shadowRadius = BubbleStyle.shadowRadius
        shadowLayer.shadowOffset = CGSize(width: 0, height: -BubbleStyle.shadowOffset)
        layer?.addSublayer(shadowLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layout() {
        super.layout()
        updateShadow()
    }

    private func updateShadow() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let room = BubbleStyle.shadowRoom
        shadowLayer.frame = bounds
        shadowLayer.shadowPath = CGPath(ellipseIn: bounds.insetBy(dx: room, dy: room), transform: nil)
        shadowLayer.shadowOpacity = shadowOpacity
        CATransaction.commit()
    }
}

@MainActor
private final class BubbleView: NSView {
    var onClick: (() -> Void)?
    var contextMenu: (() -> NSMenu?)?
    var ringWidth: CGFloat = 0 {
        didSet { layer?.borderWidth = ringWidth }
    }
    private let previewLayer: AVCaptureVideoPreviewLayer
    private var dragStartMouse: NSPoint?
    private var dragStartOrigin: NSPoint?
    private var didDrag = false

    init(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.borderColor = NSColor.white.withAlphaComponent(0.9).cgColor
        layer?.backgroundColor = NSColor.black.cgColor
        previewLayer.videoGravity = .resizeAspectFill
        // A mirror image, as in FaceTime and Photo Booth, looks natural to the person in it.
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        layer?.addSublayer(previewLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        layer?.cornerRadius = bounds.width / 2
        CATransaction.commit()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    /// AppKit calls this for a right click and shows the menu next to the pointer.
    override func menu(for event: NSEvent) -> NSMenu? { contextMenu?() }

    override func mouseDown(with event: NSEvent) {
        // A Control-click is a right click on the Mac. The `mouseDown` override below stops
        // AppKit from doing that itself, so do it here.
        if event.modifierFlags.contains(.control), let menu = contextMenu?() {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
            return
        }
        dragStartMouse = NSEvent.mouseLocation
        dragStartOrigin = window?.frame.origin
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let startMouse = dragStartMouse, let startOrigin = dragStartOrigin else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - startMouse.x
        let dy = now.y - startMouse.y
        // A small wobble during a click is still a click.
        if !didDrag, hypot(dx, dy) < 3 { return }
        didDrag = true
        NSCursor.closedHand.set()
        window.setFrameOrigin(NSPoint(x: startOrigin.x + dx, y: startOrigin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        if dragStartMouse != nil, !didDrag { onClick?() }
        dragStartMouse = nil
        dragStartOrigin = nil
        window?.invalidateCursorRects(for: self)
    }
}
