import CoreGraphics
import Foundation

public struct PixelSize: Equatable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public enum VideoCodec: Sendable {
    case h264
    case hevc

    public var name: String {
        switch self {
        case .h264: "H.264"
        case .hevc: "HEVC"
        }
    }

    /// The longest side that the Apple hardware encoders take. H.264 level 5.2 stops at 4096,
    /// so a 5K display at 2x (5120 px) makes the writer fail unless the output gets smaller.
    public var maximumSide: Int {
        switch self {
        case .h264: 4096
        case .hevc: 8192
        }
    }
}

/// How sharp the recording is, and so how big the file is.
///
/// Measurements on a 1x display (STA-2674) showed that the real-time encoders already come
/// near the 4:2:0 limit, where only a quarter of the color detail stays. So a higher bitrate
/// alone gives little. `high` uses HEVC and asks the encoder for its best quality, which kept
/// about 1 dB more detail on the face. A larger gain needs 4:4:4 (ProRes 4444) or a 2x
/// capture, and both were rejected: ProRes files are about 7 GB a minute, and on a 1x display
/// ScreenCaptureKit only upscales a 2x capture, while HEVC at that size drops frames.
public enum RecordingQuality: String, CaseIterable, Identifiable, Sendable {
    // The menus list the cases in this order, best first.
    case high
    /// H.264 plays everywhere, including old Windows PCs and some chat apps that do not take
    /// HEVC, so this tier is for a file that must go anywhere.
    case standard

    public static let `default`: RecordingQuality = .high
    public static let defaultsKey = "recordingQuality"
    /// A small region at the per-pixel rate would get a bitrate too low for any sharp detail.
    public static let minimumBitRate = 4_000_000

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .standard: "Standard"
        case .high: "High"
        }
    }

    /// The menu names the codec, so a user who must send the file to a PC knows that
    /// Standard is the one that plays everywhere.
    public var menuTitle: String {
        "\(title) (\(codec.name), \(framesPerSecond) fps)"
    }

    public var codec: VideoCodec {
        switch self {
        case .standard: .h264
        case .high: .hevc
        }
    }

    public var framesPerSecond: Int {
        switch self {
        case .standard: 30
        case .high: 60
        }
    }

    /// The bits for each pixel of each frame. The old recorder used 0.1 with H.264, and
    /// `high` doubles it. The encoder often stays under this target on a still screen, so it
    /// is a ceiling for busy moments more than a file size.
    var bitsPerPixelPerFrame: Double {
        switch self {
        case .standard: 0.1
        case .high: 0.2
        }
    }

    /// The encoder's quality target from 0 to 1, or nil for the encoder's own default.
    public var encoderQuality: Double? {
        switch self {
        case .standard: nil
        case .high: 1.0
        }
    }

    /// The size of the video for a capture of `pointSize` points on a display at
    /// `displayScale`. The size gets smaller, with the same shape, when it is past the codec's
    /// limit, and each side is even because the encoders reject odd sides.
    public func outputPixelSize(for pointSize: CGSize, displayScale: CGFloat) -> PixelSize {
        var scale = displayScale
        let longest = Swift.max(pointSize.width, pointSize.height)
        if longest > 0 {
            scale = Swift.min(scale, CGFloat(codec.maximumSide) / longest)
        }
        let pixels = RegionGeometry.pixelSize(for: pointSize, scale: scale)
        return PixelSize(width: pixels.width, height: pixels.height)
    }

    public func averageBitRate(for size: PixelSize) -> Int {
        let rate = Double(size.width * size.height * framesPerSecond) * bitsPerPixelPerFrame
        return Swift.max(Int(rate.rounded()), Self.minimumBitRate)
    }

    /// A value that was never saved, or one from a later version that this one does not know,
    /// gives the default.
    public init(defaults: UserDefaults) {
        self = defaults.string(forKey: Self.defaultsKey).flatMap(RecordingQuality.init(rawValue:)) ?? .default
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(rawValue, forKey: Self.defaultsKey)
    }
}
