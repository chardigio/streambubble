import CoreGraphics

/// The menu bar icon: the app icon's idea, a window with a `record.circle` bubble over its
/// bottom-right corner, drawn as a one-colour line glyph.
///
/// macOS menu bar extras are template images: one colour plus alpha, which the system tints
/// for a light or dark menu bar and for the highlighted state. A coloured copy of the app icon
/// would look wrong there, so the glyph keeps only the shapes. It is drawn in code, not shipped
/// as a PNG, so it stays sharp at each display scale.
///
/// All values are in points, with the origin at the top left.
public enum MenuBarGlyph {
    public static let size = CGSize(width: 21, height: 16)
    public static let lineWidth: CGFloat = 1.5
    public static let windowRect = CGRect(x: 1, y: 2, width: 14, height: 10.5)
    public static let windowCornerRadius: CGFloat = 2.5
    public static let bubbleCenter = CGPoint(x: 15.5, y: 11)
    /// The outer edge of the ring.
    public static let ringRadius: CGFloat = 4.75
    public static let dotRadius: CGFloat = 2.25
    /// The clear band between the ring and the window line, so the two shapes stay separate.
    public static let clearance: CGFloat = 1.25

    /// Draws the glyph in black on a clear background. The caller makes it a template image.
    public static func draw(in context: CGContext, paused: Bool) {
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.setStrokeColor(CGColor(gray: 0, alpha: 1))
        context.setLineWidth(lineWidth)

        let window = windowRect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        context.addPath(CGPath(
            roundedRect: window, cornerWidth: windowCornerRadius, cornerHeight: windowCornerRadius, transform: nil
        ))
        context.strokePath()

        // Erase the window line under the bubble and a band around it.
        context.setBlendMode(.clear)
        context.fillEllipse(in: circle(radius: ringRadius + clearance))
        context.setBlendMode(.normal)

        context.strokeEllipse(in: circle(radius: ringRadius - lineWidth / 2))
        if paused {
            let barWidth: CGFloat = 1.1
            let barHeight = dotRadius * 1.8
            for x in [bubbleCenter.x - 1.15 - barWidth / 2, bubbleCenter.x + 1.15 - barWidth / 2] {
                context.fill(CGRect(x: x, y: bubbleCenter.y - barHeight / 2, width: barWidth, height: barHeight))
            }
        } else {
            context.fillEllipse(in: circle(radius: dotRadius))
        }
    }

    private static func circle(radius: CGFloat) -> CGRect {
        CGRect(x: bubbleCenter.x - radius, y: bubbleCenter.y - radius, width: radius * 2, height: radius * 2)
    }
}
