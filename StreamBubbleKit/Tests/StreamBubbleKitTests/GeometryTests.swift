import CoreGraphics
import Testing
@testable import StreamBubbleKit

@Suite struct BubbleSizeTests {
    @Test func eachSizeHasAMenuTitleWithItsDiameter() {
        #expect(BubbleSize.allCases.map(\.title) == [
            "Small (140 pt)", "Medium (220 pt)", "Large (320 pt)", "Extra Large (440 pt)", "Huge (600 pt)",
        ])
    }

    @Test func cyclesThroughAllFiveSizesAndBack() {
        #expect(BubbleSize.small.next == .medium)
        #expect(BubbleSize.medium.next == .large)
        #expect(BubbleSize.large.next == .extraLarge)
        #expect(BubbleSize.extraLarge.next == .huge)
        #expect(BubbleSize.huge.next == .small)
    }

    @Test func theTwoBigSizesAreBiggerThanLarge() {
        #expect(BubbleSize.extraLarge.diameter > BubbleSize.large.diameter)
        #expect(BubbleSize.huge.diameter > BubbleSize.extraLarge.diameter)
    }

    @Test func theHugeBubbleFitsOnASmallLaptopScreen() {
        // A 13-inch MacBook Air has a 900 pt-tall screen with a menu bar; the clamp in
        // BubbleWindow keeps it on screen only if the bubble is smaller than the screen.
        #expect(BubbleSize.huge.diameter + 2 * 24 <= 900 - 40)
    }

    @Test func largestFittingStepsDownFromHuge() {
        // 500 - 2 * 24 = 452, so huge (600) does not fit and extra large (440) does.
        let size = BubbleSize.largest(atMost: .huge, fittingIn: CGSize(width: 500, height: 900), margin: 24)
        #expect(size == .extraLarge)
    }

    @Test func largestFittingKeepsTheSizeWhenItFits() {
        let size = BubbleSize.largest(atMost: .medium, fittingIn: CGSize(width: 1000, height: 800), margin: 24)
        #expect(size == .medium)
    }

    @Test func largestFittingShrinksForASmallRegion() {
        // 300 - 2 * 24 = 252, so large (320) does not fit and medium (220) does.
        let size = BubbleSize.largest(atMost: .large, fittingIn: CGSize(width: 300, height: 400), margin: 24)
        #expect(size == .medium)
    }

    @Test func largestFittingFallsBackToSmall() {
        let size = BubbleSize.largest(atMost: .large, fittingIn: CGSize(width: 100, height: 100), margin: 24)
        #expect(size == .small)
    }

    @Test func theSmallestUsableRegionHoldsTheSmallBubble() {
        let side = RegionGeometry.minimumSide
        let size = BubbleSize.largest(atMost: .large, fittingIn: CGSize(width: side, height: side), margin: 24)
        #expect(size.diameter + 48 <= side)
    }

    @Test func diametersGrow() {
        #expect(BubbleSize.small.diameter < BubbleSize.medium.diameter)
        #expect(BubbleSize.medium.diameter < BubbleSize.large.diameter)
        #expect(BubbleSize.allCases.map(\.diameter) == BubbleSize.allCases.map(\.diameter).sorted())
    }
}

@Suite struct RegionGeometryTests {
    @Test func normalizesADragInAnyDirection() {
        let rect = RegionGeometry.rect(from: CGPoint(x: 300, y: 400), to: CGPoint(x: 100, y: 150))
        #expect(rect == CGRect(x: 100, y: 150, width: 200, height: 250))
    }

    @Test func convertsAnAppKitRectToATopLeftDisplayRect() {
        // AppKit puts the origin at the bottom left of the main screen. ScreenCaptureKit's
        // sourceRect puts it at the top left of the captured display.
        let display = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let region = CGRect(x: 100, y: 600, width: 400, height: 300)
        let source = RegionGeometry.sourceRect(forGlobalRect: region, onDisplayFrame: display)
        #expect(source == CGRect(x: 100, y: 82, width: 400, height: 300))
    }

    @Test func convertsARectOnASecondaryDisplay() {
        // A second display to the right of the main one, and lower.
        let display = CGRect(x: 1512, y: -200, width: 1920, height: 1080)
        let region = CGRect(x: 1612, y: 0, width: 800, height: 600)
        let source = RegionGeometry.sourceRect(forGlobalRect: region, onDisplayFrame: display)
        #expect(source == CGRect(x: 100, y: 280, width: 800, height: 600))
    }

    @Test func clipsARegionToTheDisplay() {
        let display = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let region = CGRect(x: -50, y: 700, width: 300, height: 300)
        let source = RegionGeometry.sourceRect(forGlobalRect: region, onDisplayFrame: display)
        #expect(source == CGRect(x: 0, y: 0, width: 250, height: 100))
    }

    @Test func aRegionOffTheDisplayGivesAnEmptyRect() {
        let display = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let region = CGRect(x: 2000, y: 0, width: 300, height: 300)
        #expect(RegionGeometry.sourceRect(forGlobalRect: region, onDisplayFrame: display).isEmpty)
    }

    @Test func outputPixelSizeIsEvenBecauseH264NeedsEvenDimensions() {
        let size = RegionGeometry.pixelSize(for: CGSize(width: 401, height: 300.5), scale: 2)
        #expect(size.width == 802)
        #expect(size.height == 600)
        let odd = RegionGeometry.pixelSize(for: CGSize(width: 100.5, height: 33.5), scale: 1)
        #expect(odd.width == 100)
        #expect(odd.height == 32)
    }

    @Test func aTinyDragIsNotARegion() {
        #expect(RegionGeometry.isUsable(CGRect(x: 0, y: 0, width: 10, height: 300)) == false)
        #expect(RegionGeometry.isUsable(CGRect(x: 0, y: 0, width: 150, height: 300)) == false)
        #expect(RegionGeometry.isUsable(CGRect(x: 0, y: 0, width: 200, height: 200)))
    }

    @Test func placesTheBubbleInTheBottomLeftCornerOfTheRegion() {
        let region = CGRect(x: 100, y: 100, width: 800, height: 600)
        let origin = RegionGeometry.bubbleOrigin(diameter: 200, in: region, margin: 24)
        #expect(origin == CGPoint(x: 124, y: 124))
    }

    @Test func clampsABubbleFrameInsideTheScreen() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let off = CGRect(x: 950, y: -40, width: 200, height: 200)
        #expect(RegionGeometry.clamp(off, inside: screen) == CGRect(x: 800, y: 0, width: 200, height: 200))
    }
}
