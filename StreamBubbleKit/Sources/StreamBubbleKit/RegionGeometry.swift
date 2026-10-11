import CoreGraphics

/// Geometry for the "record a region" mode and for the bubble's position.
///
/// AppKit gives global rects with the origin at the bottom left of the main screen, and y up.
/// ScreenCaptureKit's `sourceRect` wants the origin at the top left of the captured display,
/// and y down. These functions are the one place that converts between the two.
public enum RegionGeometry {
    /// The smallest region side: room for the small bubble with its margin. A smaller drag is
    /// most likely a stray click, and a region that cannot hold the bubble loses the face.
    public static let minimumSide: CGFloat = 200

    public static func rect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x), y: min(start.y, end.y),
            width: abs(end.x - start.x), height: abs(end.y - start.y)
        )
    }

    public static func isUsable(_ rect: CGRect) -> Bool {
        rect.width >= minimumSide && rect.height >= minimumSide
    }

    public static func sourceRect(forGlobalRect rect: CGRect, onDisplayFrame display: CGRect) -> CGRect {
        let clipped = rect.intersection(display)
        guard !clipped.isNull else { return .zero }
        return CGRect(
            x: clipped.minX - display.minX,
            y: display.maxY - clipped.maxY,
            width: clipped.width,
            height: clipped.height
        )
    }

    /// The H.264 and HEVC encoders reject odd dimensions, so the output rounds down to even.
    public static func pixelSize(for size: CGSize, scale: CGFloat) -> (width: Int, height: Int) {
        func even(_ value: CGFloat) -> Int {
            let whole = Int(value.rounded(.down))
            return whole - whole % 2
        }
        return (even(size.width * scale), even(size.height * scale))
    }

    public static func bubbleOrigin(diameter: CGFloat, in region: CGRect, margin: CGFloat) -> CGPoint {
        CGPoint(x: region.minX + margin, y: region.minY + margin)
    }

    public static func clamp(_ frame: CGRect, inside bounds: CGRect) -> CGRect {
        var result = frame
        result.origin.x = min(max(frame.minX, bounds.minX), bounds.maxX - frame.width)
        result.origin.y = min(max(frame.minY, bounds.minY), bounds.maxY - frame.height)
        return result
    }
}
