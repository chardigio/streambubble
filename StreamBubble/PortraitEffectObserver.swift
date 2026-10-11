@preconcurrency import AVFoundation

/// Watches the macOS Portrait video effect (the background blur in Control Center), so the
/// menu can show a checkmark when it is on.
///
/// Apple lets only the user turn the effect on or off, and set how strong the blur is. An app
/// can only read the state and open the Video Effects panel. The state is a key-value
/// observable class property, which Swift's typed `observe(_:)` cannot watch, so this uses
/// the older string key path form on the class object.
final class PortraitEffectObserver: NSObject, @unchecked Sendable {
    private let onChange: @MainActor @Sendable (Bool) -> Void
    private static let keyPath = "portraitEffectEnabled"

    init(onChange: @escaping @MainActor @Sendable (Bool) -> Void) {
        self.onChange = onChange
        super.init()
        AVCaptureDevice.self.addObserver(self, forKeyPath: Self.keyPath, options: [.new], context: nil)
    }

    deinit {
        AVCaptureDevice.self.removeObserver(self, forKeyPath: Self.keyPath)
    }

    override func observeValue(
        forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        let enabled = AVCaptureDevice.isPortraitEffectEnabled
        let onChange = onChange
        Task { @MainActor in onChange(enabled) }
    }
}
