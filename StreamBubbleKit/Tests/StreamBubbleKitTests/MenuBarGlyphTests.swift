import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import StreamBubbleKit

/// Renders the glyph at 2x (a Retina menu bar) and reads single pixels. Top-left origin, in
/// points, so the coordinates match `MenuBarGlyph`'s own layout.
private struct Render {
    let context: CGContext
    let scale: CGFloat = 2

    init(paused: Bool) {
        let size = MenuBarGlyph.size
        context = CGContext(
            data: nil, width: Int(size.width * 2), height: Int(size.height * 2), bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.scaleBy(x: scale, y: scale)
        MenuBarGlyph.draw(in: context, paused: paused)
        // Set STREAMBUBBLE_GLYPH_PREVIEW=/some/dir to look at the result.
        if let dir = ProcessInfo.processInfo.environment["STREAMBUBBLE_GLYPH_PREVIEW"], let image = context.makeImage() {
            let url = URL(fileURLWithPath: dir).appendingPathComponent(paused ? "glyph-paused.png" : "glyph.png")
            if let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) {
                CGImageDestinationAddImage(dest, image, nil)
                CGImageDestinationFinalize(dest)
            }
        }
    }

    /// The alpha at a point, 0 to 255. y is measured from the top.
    func alpha(_ x: CGFloat, _ y: CGFloat) -> UInt8 {
        let px = Int(x * scale), py = Int(y * scale)
        let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
        return bytes[py * context.bytesPerRow + px * 4 + 3]
    }
}

@Suite struct MenuBarGlyphTests {
    @Test func fitsTheMenuBar() {
        // macOS menu bar extras are about 22 pt tall; the glyph must leave room above and below.
        #expect(MenuBarGlyph.size.height <= 18)
        let bubble = MenuBarGlyph.bubbleCenter
        #expect(bubble.x + MenuBarGlyph.ringRadius <= MenuBarGlyph.size.width)
        #expect(bubble.y + MenuBarGlyph.ringRadius <= MenuBarGlyph.size.height)
    }

    @Test func theBubbleSitsOverTheWindowCorner() {
        // As in the app icon: the bubble covers the bottom-right corner of the window.
        let window = MenuBarGlyph.windowRect
        #expect(window.contains(MenuBarGlyph.bubbleCenter) == false)
        #expect(MenuBarGlyph.bubbleCenter.x - MenuBarGlyph.ringRadius < window.maxX)
        #expect(MenuBarGlyph.bubbleCenter.y - MenuBarGlyph.ringRadius < window.maxY)
    }

    @Test func drawsTheRecordCircleDotAndAGapAroundIt() {
        let render = Render(paused: false)
        let c = MenuBarGlyph.bubbleCenter
        #expect(render.alpha(c.x, c.y) > 200) // the dot
        let gap = (MenuBarGlyph.dotRadius + MenuBarGlyph.ringRadius - MenuBarGlyph.lineWidth) / 2
        #expect(render.alpha(c.x - gap, c.y) < 60) // the clear gap between the dot and the ring
        #expect(render.alpha(c.x - MenuBarGlyph.ringRadius + MenuBarGlyph.lineWidth / 2, c.y) > 200) // the ring
    }

    @Test func clearsTheWindowLineUnderTheBubble() {
        // The window's bottom edge must stop at the bubble, or the two shapes merge into a blob.
        let render = Render(paused: false)
        let window = MenuBarGlyph.windowRect
        let c = MenuBarGlyph.bubbleCenter
        let insideRingGap = c.x - MenuBarGlyph.ringRadius - MenuBarGlyph.clearance / 2
        #expect(render.alpha(insideRingGap, window.maxY - MenuBarGlyph.lineWidth / 2) < 60)
        #expect(render.alpha(window.minX + 3, window.maxY - MenuBarGlyph.lineWidth / 2) > 200)
    }

    @Test func pausedShowsTwoBarsInsteadOfTheDot() {
        let render = Render(paused: true)
        let c = MenuBarGlyph.bubbleCenter
        #expect(render.alpha(c.x, c.y) < 60) // between the bars
        #expect(render.alpha(c.x - MenuBarGlyph.dotRadius * 0.55, c.y) > 150)
        #expect(render.alpha(c.x + MenuBarGlyph.dotRadius * 0.55, c.y) > 150)
    }
}
