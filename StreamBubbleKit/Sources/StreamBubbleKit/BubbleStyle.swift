import CoreGraphics
import Foundation

/// The edge of the face bubble: a white ring, a soft drop shadow, both, or neither.
///
/// The shadow is drawn by the app in the bubble window, not by the window server
/// (`NSWindow.hasShadow`). The recording captures the window's own pixels, so a shadow that
/// the app draws looks the same on the screen and in the video.
public struct BubbleStyle: Equatable, Sendable {
    public var showsRing: Bool
    public var showsShadow: Bool

    public static let `default` = BubbleStyle(showsRing: true, showsShadow: false)

    /// 2.5 pt, about 17% thinner than the first 3 pt ring, which looked heavy on a small bubble.
    public static let ringLineWidth: CGFloat = 2.5

    /// The empty room on each side of the circle in the window, where the shadow can fall.
    /// It stays when the shadow is off, so a change of style does not move the bubble. The
    /// room is clear, and macOS sends clicks on clear window pixels to the window below.
    public static let shadowRoom: CGFloat = 24
    public static let shadowRadius: CGFloat = 12
    /// Downward, in points. The shadow is a little lower than the bubble, as from a top light.
    public static let shadowOffset: CGFloat = 6
    public static let shadowStrength: Float = 0.55

    private static let ringKey = "bubbleShowsRing"
    private static let shadowKey = "bubbleShowsShadow"

    public init(showsRing: Bool, showsShadow: Bool) {
        self.showsRing = showsRing
        self.showsShadow = showsShadow
    }

    /// A key that was never saved keeps its default, so a first launch shows the ring.
    public init(defaults: UserDefaults) {
        self.init(
            showsRing: defaults.object(forKey: Self.ringKey) as? Bool ?? Self.default.showsRing,
            showsShadow: defaults.object(forKey: Self.shadowKey) as? Bool ?? Self.default.showsShadow
        )
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(showsRing, forKey: Self.ringKey)
        defaults.set(showsShadow, forKey: Self.shadowKey)
    }

    public var ringWidth: CGFloat { showsRing ? Self.ringLineWidth : 0 }
    public var shadowOpacity: Float { showsShadow ? Self.shadowStrength : 0 }

    public static func windowFrame(around circle: CGRect) -> CGRect {
        circle.insetBy(dx: -shadowRoom, dy: -shadowRoom)
    }

    public static func circle(inWindowFrame frame: CGRect) -> CGRect {
        frame.insetBy(dx: shadowRoom, dy: shadowRoom)
    }
}
