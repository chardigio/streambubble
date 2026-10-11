import AppKit
import AVFoundation
import Observation
import ScreenCaptureKit
import StreamBubbleKit

enum CaptureMode: String, CaseIterable, Identifiable {
    case display
    case region

    var id: String { rawValue }

    var title: String {
        switch self {
        case .display: "Full Display"
        case .region: "Region…"
        }
    }
}

/// What one recording captures, chosen in `prepare()`.
struct RecordingTarget {
    let screen: NSScreen
    /// The region in global AppKit coordinates, or nil for the whole display.
    let region: CGRect?
    let includeMicrophone: Bool
}

/// Connects the menu, the hotkeys, and the bubble to the recording.
///
/// `RecordingFlow` (in StreamBubbleKit, with tests) owns the order of events and the state.
/// This class is its host: it does each step with the real windows, permissions, and stream.
@MainActor
@Observable
final class AppModel: RecordingHost {
    var captureMode: CaptureMode = .display {
        didSet { UserDefaults.standard.set(captureMode.rawValue, forKey: "captureMode") }
    }
    var bubbleStyle: BubbleStyle = .default {
        didSet {
            bubbleStyle.save(to: .standard)
            bubble.style = bubbleStyle
        }
    }
    private(set) var bubbleSize: BubbleSize = .medium
    private(set) var isBubbleShown = false
    /// Set when another app already owns one of the shortcuts, so the menu can say so.
    private(set) var hotKeyWarning: String?
    /// The macOS Portrait effect, which blurs the background behind the face in the bubble.
    private(set) var isBackgroundBlurOn = AVCaptureDevice.isPortraitEffectEnabled

    @ObservationIgnored private(set) var flow: RecordingFlow<AppModel>!
    @ObservationIgnored private let camera = CameraController()
    @ObservationIgnored private lazy var bubble = BubbleWindow(session: camera.session)
    @ObservationIgnored private let recorder = ScreenRecorder()
    @ObservationIgnored private let hotKeys = HotKeyCenter()
    @ObservationIgnored private let regionSelector = RegionSelector()
    @ObservationIgnored private var countdownPanel: CountdownPanel?
    @ObservationIgnored private var outlinePanel: RegionOutlinePanel?
    @ObservationIgnored private var portraitObserver: PortraitEffectObserver?

    static let recordingsFolder = FileManager.default
        .urls(for: .moviesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("StreamBubble", isDirectory: true)

    init() {
        if let saved = UserDefaults.standard.string(forKey: "captureMode"), let mode = CaptureMode(rawValue: saved) {
            captureMode = mode
        }
        bubbleStyle = BubbleStyle(defaults: .standard)
        bubbleSize = bubble.size
        flow = RecordingFlow(host: self)
        recorder.onUnexpectedStop = { [weak self] url, error in
            self?.flow.streamDidStop(url: url, error: error)
        }
        let failed = [
            (HotKeyBinding.toggleRecording, { [weak self] in self?.flow.toggle() }),
            (HotKeyBinding.togglePause, { [weak self] in self?.flow.togglePause() }),
        ].filter { binding, action in !hotKeys.register(binding, action: action) }.map { $0.0.displayName }
        if !failed.isEmpty {
            hotKeyWarning = "\(failed.joined(separator: " and ")) is in use by another app"
        }
        bubble.onSizeChange = { [weak self] size in self?.bubbleSize = size }
        bubble.contextMenu = { [weak self] in self.map { BubbleContextMenu.make(for: $0) } }
        portraitObserver = PortraitEffectObserver { [weak self] enabled in self?.isBackgroundBlurOn = enabled }
        Task { await setBubbleShown(true) }
    }

    // MARK: Menu text

    var state: RecorderState { flow.state }

    var statusTitle: String {
        switch state {
        case .idle: "Ready"
        case .preparing: "Getting ready…"
        case let .countingDown(n): "Starting in \(n)…"
        case .starting: "Starting…"
        case .recording: "Recording \(Self.clock(flow.elapsedSeconds))"
        case .paused: "Paused \(Self.clock(flow.elapsedSeconds))"
        case .finishing: "Saving…"
        }
    }

    var toggleTitle: String {
        switch state {
        case .idle, .preparing, .starting: "Start Recording"
        case .countingDown: "Cancel Countdown"
        case .recording, .paused, .finishing: "Stop Recording"
        }
    }

    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: Actions

    func setBubbleShown(_ shown: Bool) async {
        if shown {
            guard await camera.start() else {
                showMessage("StreamBubble cannot use the camera.", detail: "Allow it in System Settings > Privacy & Security > Camera.")
                return
            }
            if !isBubbleShown, let screen = Self.screenWithMouse() { bubble.placeAtDefaultPosition(on: screen) }
            bubble.orderFrontRegardless()
            isBubbleShown = true
        } else {
            bubble.orderOut(nil)
            camera.stop()
            isBubbleShown = false
        }
    }

    func setBubbleSize(_ size: BubbleSize) {
        bubble.setSize(size)
        bubbleSize = size
    }

    /// Opens Control Center's Video Effects panel, where the user turns Portrait on and sets
    /// the strength of the blur. macOS shows that panel only while an app uses the camera.
    func openVideoEffects() {
        AVCaptureDevice.showSystemUserInterface(.videoEffects)
    }

    func openRecordingsFolder() {
        try? FileManager.default.createDirectory(at: Self.recordingsFolder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(Self.recordingsFolder)
    }

    // MARK: RecordingHost

    func prepare() async -> RecordingTarget? {
        guard ensureScreenRecordingPermission() else { return nil }
        let includeMicrophone = await AVCaptureDevice.requestAccess(for: .audio)
        if !includeMicrophone {
            // Record anyway: a silent video is still useful, and a refusal to record would
            // be a surprise. The message says why there is no sound.
            showMessage(
                "This recording has no sound.",
                detail: "StreamBubble cannot use the microphone. Allow it in System Settings > Privacy & Security > Microphone."
            )
        }

        let target: RecordingTarget
        switch captureMode {
        case .display:
            guard let screen = Self.screenWithMouse() else { return nil }
            target = RecordingTarget(screen: screen, region: nil, includeMicrophone: includeMicrophone)
        case .region:
            guard
                let (rect, displayID) = await regionSelector.select(),
                let screen = NSScreen.screens.first(where: { $0.displayID == displayID })
            else { return nil }
            target = RecordingTarget(screen: screen, region: rect, includeMicrophone: includeMicrophone)
        }

        if isBubbleShown { bubble.ensureVisible(in: target.region ?? target.screen.visibleFrame) }
        if let region = target.region {
            outlinePanel = RegionOutlinePanel(region: region)
            outlinePanel?.orderFrontRegardless()
        }
        countdownPanel = CountdownPanel(centeredIn: target.region ?? target.screen.visibleFrame)
        return target
    }

    func showCountdown(_ remaining: Int) {
        countdownPanel?.show(remaining)
    }

    func hideCountdown() {
        countdownPanel?.orderOut(nil)
        countdownPanel = nil
    }

    func startRecording(_ target: RecordingTarget) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == target.screen.displayID }) else {
            throw RecorderError.noDisplay
        }
        // Leave out each of our windows except the bubble: the region outline, and the menu
        // if it is still open.
        let bubbleID = CGWindowID(bubble.windowNumber)
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let excluded = content.windows.filter {
            $0.owningApplication?.processID == ownPID && !(isBubbleShown && $0.windowID == bubbleID)
        }
        var sourceRect: CGRect?
        if let region = target.region {
            let rect = RegionGeometry.sourceRect(forGlobalRect: region, onDisplayFrame: target.screen.frame)
            guard !rect.isEmpty else { throw RecorderError.noDisplay }
            sourceRect = rect
        }
        try FileManager.default.createDirectory(at: Self.recordingsFolder, withIntermediateDirectories: true)
        let url = RecordingFileNamer.uniqueURL(in: Self.recordingsFolder, for: Date())
        try await recorder.start(
            target: CaptureTarget(
                display: display, sourceRect: sourceRect, scale: target.screen.backingScaleFactor,
                excludedWindows: excluded, includeMicrophone: target.includeMicrophone
            ),
            outputURL: url
        )
    }

    func pauseRecording() { recorder.pause() }
    func resumeRecording() { recorder.resume() }
    func stopRecording() async throws -> URL? { try await recorder.stop() }

    func recordingDidFinish(_ url: URL?) {
        if let url {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            showMessage("StreamBubble did not save a video.", detail: "No frames were recorded.")
        }
    }

    func recordingDidFail(_ error: Error) {
        showMessage("StreamBubble stopped.", detail: error.localizedDescription)
    }

    func cleanUp() {
        hideCountdown()
        outlinePanel?.orderOut(nil)
        outlinePanel = nil
    }

    // MARK: Helpers

    private func ensureScreenRecordingPermission() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        // This opens the system prompt the first time. macOS applies a new grant only after
        // the app restarts, so the user must quit and open StreamBubble again.
        CGRequestScreenCaptureAccess()
        showMessage(
            "StreamBubble needs the Screen Recording permission.",
            detail: "Turn on StreamBubble in System Settings > Privacy & Security > Screen & System Audio Recording. Then quit and open StreamBubble again."
        )
        return false
    }

    private static func screenWithMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }

    private func showMessage(_ message: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        NSApp.activate()
        alert.runModal()
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}
