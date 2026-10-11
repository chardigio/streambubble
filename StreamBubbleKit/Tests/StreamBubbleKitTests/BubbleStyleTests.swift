import CoreGraphics
import Foundation
import Testing
@testable import StreamBubbleKit

@Suite struct BubbleStyleTests {
    @Test func theDefaultIsTheRingWithNoShadow() {
        #expect(BubbleStyle.default == BubbleStyle(showsRing: true, showsShadow: false))
    }

    @Test func theRingAndTheShadowAreIndependent() {
        let both = BubbleStyle(showsRing: true, showsShadow: true)
        #expect(both.ringWidth == BubbleStyle.ringLineWidth)
        #expect(both.shadowOpacity == BubbleStyle.shadowStrength)
        let neither = BubbleStyle(showsRing: false, showsShadow: false)
        #expect(neither.ringWidth == 0)
        #expect(neither.shadowOpacity == 0)
    }

    @Test func theRingIsTenToTwentyPercentThinnerThanTheOldThreePoints() {
        #expect(BubbleStyle.ringLineWidth >= 3 * 0.8)
        #expect(BubbleStyle.ringLineWidth <= 3 * 0.9)
    }

    @Test func theStyleIsSavedAndReadBack() throws {
        let defaults = try #require(UserDefaults(suiteName: "BubbleStyleTests-\(UUID().uuidString)"))
        #expect(BubbleStyle(defaults: defaults) == .default)
        BubbleStyle(showsRing: false, showsShadow: true).save(to: defaults)
        #expect(BubbleStyle(defaults: defaults) == BubbleStyle(showsRing: false, showsShadow: true))
    }

    @Test func theWindowHasRoomForTheShadowOnEachSide() {
        let circle = CGRect(x: 100, y: 200, width: 220, height: 220)
        let window = BubbleStyle.windowFrame(around: circle)
        let pad = BubbleStyle.shadowRoom
        #expect(window == CGRect(x: 100 - pad, y: 200 - pad, width: 220 + 2 * pad, height: 220 + 2 * pad))
        #expect(BubbleStyle.circle(inWindowFrame: window) == circle)
    }

    @Test func theShadowFitsInTheRoom() {
        #expect(BubbleStyle.shadowRadius + abs(BubbleStyle.shadowOffset) <= BubbleStyle.shadowRoom)
    }
}
