import CoreGraphics
import Foundation
import Testing
@testable import StreamBubbleKit

@Suite struct RecordingQualityTests {
    /// Charlie's main display: a 3440x1440 ultrawide at 1x.
    let ultrawide = CGSize(width: 3440, height: 1440)

    @Test func theDefaultIsHigh() {
        #expect(RecordingQuality.default == .high)
    }

    @Test func theMenuListsHighFirstBecauseItIsTheHighestQuality() {
        #expect(RecordingQuality.allCases == [.high, .standard])
        #expect(RecordingQuality.allCases.map(\.title) == ["High", "Standard"])
    }

    @Test func theMenuTitleSaysTheCodecAndTheFrameRate() {
        #expect(RecordingQuality.standard.menuTitle == "Standard (H.264, 30 fps)")
        #expect(RecordingQuality.high.menuTitle == "High (HEVC, 60 fps)")
    }

    @Test func standardIsH264At30FPSAndHighIsHEVCAt60FPS() {
        #expect(RecordingQuality.standard.codec == .h264)
        #expect(RecordingQuality.standard.framesPerSecond == 30)
        #expect(RecordingQuality.high.codec == .hevc)
        #expect(RecordingQuality.high.framesPerSecond == 60)
    }

    @Test func highAsksTheEncoderForItsBestQuality() {
        #expect(RecordingQuality.high.encoderQuality == 1.0)
        #expect(RecordingQuality.standard.encoderQuality == nil)
    }

    @Test func bothTiersRecordAtTheDisplayDensity() {
        for quality in RecordingQuality.allCases {
            #expect(quality.outputPixelSize(for: ultrawide, displayScale: 1) == PixelSize(width: 3440, height: 1440))
        }
        let retina = CGSize(width: 1728, height: 1117)
        #expect(RecordingQuality.high.outputPixelSize(for: retina, displayScale: 2) == PixelSize(width: 3456, height: 2234))
    }

    @Test func h264StaysInsideItsLimitAndKeepsTheShape() {
        // A 5K display: 2560x1440 points at 2x is 5120 px wide, past the H.264 limit of 4096.
        let size = RecordingQuality.standard.outputPixelSize(for: CGSize(width: 2560, height: 1440), displayScale: 2)
        #expect(size == PixelSize(width: 4096, height: 2304))
    }

    @Test func hevcKeepsAFiveKDisplayAtFullSize() {
        let size = RecordingQuality.high.outputPixelSize(for: CGSize(width: 2560, height: 1440), displayScale: 2)
        #expect(size == PixelSize(width: 5120, height: 2880))
    }

    @Test func hevcStaysInsideItsLimitAndKeepsTheShape() {
        // Two 5K displays side by side would be 10240 px at 2x, past the HEVC limit of 8192.
        let size = RecordingQuality.high.outputPixelSize(for: CGSize(width: 5120, height: 1440), displayScale: 2)
        #expect(size == PixelSize(width: 8192, height: 2304))
    }

    @Test func theSidesAreAlwaysEven() {
        let size = RecordingQuality.high.outputPixelSize(for: CGSize(width: 401.3, height: 299.7), displayScale: 1)
        #expect(size.width % 2 == 0)
        #expect(size.height % 2 == 0)
    }

    @Test func highHasTwiceTheBitsPerPixelOfTheOldRecorder() {
        // The old recorder used width x height x 6 bits per second at 60 fps.
        let old = 3440 * 1440 * 6
        let high = RecordingQuality.high.averageBitRate(for: PixelSize(width: 3440, height: 1440))
        #expect(high == 2 * old)
    }

    @Test func standardHasTheOldBitsPerPixelAtHalfTheFrames() {
        let standard = RecordingQuality.standard.averageBitRate(for: PixelSize(width: 3440, height: 1440))
        #expect(standard == 3440 * 1440 * 3)
    }

    @Test func aSmallRegionStillGetsTheFloorBitRate() {
        let rate = RecordingQuality.standard.averageBitRate(for: PixelSize(width: 200, height: 200))
        #expect(rate == RecordingQuality.minimumBitRate)
    }

    @Test func theQualityIsSavedAndReadBack() throws {
        let defaults = try #require(UserDefaults(suiteName: "RecordingQualityTests-\(UUID().uuidString)"))
        #expect(RecordingQuality(defaults: defaults) == .default)
        RecordingQuality.standard.save(to: defaults)
        #expect(RecordingQuality(defaults: defaults) == .standard)
    }

    @Test func anUnknownSavedValueFallsBackToTheDefault() throws {
        let defaults = try #require(UserDefaults(suiteName: "RecordingQualityTests-\(UUID().uuidString)"))
        defaults.set("max", forKey: RecordingQuality.defaultsKey)
        #expect(RecordingQuality(defaults: defaults) == .default)
    }
}
