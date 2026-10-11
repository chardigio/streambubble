@preconcurrency import AVFoundation

/// Owns the camera session that feeds the bubble's preview.
///
/// The session runs only while the bubble shows, so the camera light goes off when the user
/// hides the bubble.
@MainActor
final class CameraController {
    let session = AVCaptureSession()
    private var configured = false
    private let sessionQueue = DispatchQueue(label: "com.cd17822.streambubble.camera")

    func start() async -> Bool {
        guard await AVCaptureDevice.requestAccess(for: .video) else { return false }
        if !configured {
            guard configure() else { return false }
            configured = true
        }
        let session = session
        sessionQueue.async { if !session.isRunning { session.startRunning() } }
        return true
    }

    func stop() {
        let session = session
        sessionQueue.async { if session.isRunning { session.stopRunning() } }
    }

    private func configure() -> Bool {
        let device = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .continuityCamera, .external],
            mediaType: .video,
            position: .unspecified
        ).devices.first ?? AVCaptureDevice.default(for: .video)
        guard let device, let input = try? AVCaptureDeviceInput(device: device) else { return false }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high
        guard session.canAddInput(input) else { return false }
        session.addInput(input)
        return true
    }
}
