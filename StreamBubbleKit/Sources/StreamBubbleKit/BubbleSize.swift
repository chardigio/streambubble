import CoreGraphics

/// The face bubble's sizes. A click on the bubble moves to the next one, as Loom did.
public enum BubbleSize: Int, CaseIterable, Identifiable, Sendable {
    case small
    case medium
    case large
    /// The two big sizes are for a talk-to-camera video, where the face matters more than
    /// the screen behind it.
    case extraLarge
    case huge

    public var diameter: CGFloat {
        switch self {
        case .small: 140
        case .medium: 220
        case .large: 320
        case .extraLarge: 440
        case .huge: 600
        }
    }

    public var id: Int { rawValue }

    /// The menu shows the diameter, so the user can see how big each size is before a pick.
    public var title: String {
        let name = switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        case .huge: "Huge"
        }
        return "\(name) (\(Int(diameter)) pt)"
    }

    public var next: BubbleSize {
        BubbleSize(rawValue: rawValue + 1) ?? .small
    }

    /// The largest size up to `limit` that fits in `area` with `margin` on each side. A
    /// bubble that sticks out of a small region shows only in part in the video. The small
    /// size is the floor, and `RegionGeometry.minimumSide` makes sure that it always fits.
    public static func largest(atMost limit: BubbleSize, fittingIn area: CGSize, margin: CGFloat) -> BubbleSize {
        let room = min(area.width, area.height) - 2 * margin
        return allCases.reversed().first { $0.rawValue <= limit.rawValue && $0.diameter <= room } ?? .small
    }
}
