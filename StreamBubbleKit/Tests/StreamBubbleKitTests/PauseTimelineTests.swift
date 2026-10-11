import CoreMedia
import Testing
@testable import StreamBubbleKit

private func t(_ seconds: Double) -> CMTime {
    CMTime(seconds: seconds, preferredTimescale: 600)
}

@Suite struct PauseTimelineTests {
    @Test func passesTimesThroughUnchangedBeforeAnyPause() {
        var timeline = PauseTimeline()
        #expect(timeline.adjust(t(10), track: .video) == t(10))
        #expect(timeline.adjust(t(10.5), track: .audio) == t(10.5))
    }

    @Test func dropsSamplesWhilePaused() {
        var timeline = PauseTimeline()
        _ = timeline.adjust(t(10), track: .video)
        timeline.pause()
        #expect(timeline.adjust(t(11), track: .video) == nil)
        #expect(timeline.adjust(t(11), track: .audio) == nil)
    }

    @Test func removesThePausedGapAfterResume() {
        var timeline = PauseTimeline()
        _ = timeline.adjust(t(10), duration: t(0.5), track: .video)
        _ = timeline.adjust(t(12), duration: t(0.5), track: .video)
        timeline.pause()
        _ = timeline.adjust(t(15), track: .video)
        timeline.resume()
        // The first sample after the resume continues where the last sample before the
        // pause ended.
        #expect(timeline.adjust(t(20), duration: t(0.5), track: .video) == t(12.5))
        #expect(timeline.adjust(t(21), duration: t(0.5), track: .video) == t(13.5))
    }

    @Test func sharesOneOffsetAcrossTracksSoAudioStaysInSync() {
        var timeline = PauseTimeline()
        _ = timeline.adjust(t(10), duration: t(0.5), track: .video)
        timeline.pause()
        timeline.resume()
        #expect(timeline.adjust(t(30), track: .video) == t(10.5))
        #expect(timeline.adjust(t(30.5), track: .audio) == t(11))
    }

    @Test func accumulatesSeveralPauses() {
        var timeline = PauseTimeline()
        _ = timeline.adjust(t(0), duration: t(1), track: .video)
        _ = timeline.adjust(t(5), duration: t(1), track: .video)  // ends at 6
        timeline.pause()
        timeline.resume()
        #expect(timeline.adjust(t(10), duration: t(1), track: .video) == t(6)) // 4 s gap removed
        _ = timeline.adjust(t(12), duration: t(1), track: .video)              // -> 8, ends at 9
        timeline.pause()
        timeline.resume()
        #expect(timeline.adjust(t(20), track: .video) == t(9))                 // 7 s more removed
    }

    @Test func aResumedFrameNeverRepeatsTheTimeOfTheLastFrame() {
        // Regression (QA, 2026-10-11): ScreenCaptureKit frames carry no duration, so the
        // first frame after a resume landed on the exact time of the last frame before the
        // pause. AVAssetWriter fails on a repeated time, and the file was left with no moov
        // atom. That frame must be dropped, and the next one must move forward.
        var timeline = PauseTimeline()
        _ = timeline.adjust(t(10), track: .video)
        timeline.pause()
        timeline.resume()
        #expect(timeline.adjust(t(20), track: .video) == nil)
        #expect(timeline.adjust(t(20.02), track: .video) == t(10.02))
    }

    @Test func neverWritesTheSameTimeTwiceOnATrack() {
        var timeline = PauseTimeline()
        #expect(timeline.adjust(t(10), track: .video) == t(10))
        #expect(timeline.adjust(t(10), track: .video) == nil)
    }

    @Test func dropsAnAudioBufferThatOverlapsTheLastOne() {
        // Audio buffers can carry a time from just before the resume. Writing it would put
        // two buffers over the same moment, which AVAssetWriter rejects, so it is dropped.
        var timeline = PauseTimeline()
        _ = timeline.adjust(t(10), duration: t(0.5), track: .audio) // ends at 10.5
        timeline.pause()
        timeline.resume()
        #expect(timeline.adjust(t(20), track: .video) == t(10.5))
        #expect(timeline.adjust(t(19.9), duration: t(0.1), track: .audio) == nil)
        #expect(timeline.adjust(t(20.1), duration: t(0.1), track: .audio) == t(10.6))
        // Back-to-back buffers (one starts where the last ended) are fine.
        #expect(timeline.adjust(t(20.2), duration: t(0.1), track: .audio) == t(10.7))
    }

    @Test func pauseAndResumeAreIdempotent() {
        var timeline = PauseTimeline()
        _ = timeline.adjust(t(1), duration: t(1), track: .video)
        timeline.resume()
        #expect(timeline.isPaused == false)
        timeline.pause()
        timeline.pause()
        #expect(timeline.isPaused)
        timeline.resume()
        #expect(timeline.adjust(t(4), track: .video) == t(2))
    }

    @Test func latestEndTimeCoversAudioAfterTheLastVideoFrame() {
        // A still screen sends no new frames, but the user keeps on talking. The session must
        // end after the last audio buffer, not at the last frame (PR #2491 review).
        var timeline = PauseTimeline()
        #expect(timeline.latestEndTime == nil)
        _ = timeline.adjust(t(10), track: .video)
        _ = timeline.adjust(t(15), duration: t(0.5), track: .audio)
        #expect(timeline.latestEndTime == t(15.5))
    }

    @Test func latestEndTimeUsesAdjustedTimes() {
        var timeline = PauseTimeline()
        _ = timeline.adjust(t(10), track: .video)
        timeline.pause()
        timeline.resume()
        _ = timeline.adjust(t(20), duration: t(1), track: .audio)
        #expect(timeline.latestEndTime == t(11))
    }

    @Test func droppedSamplesDoNotMoveTheEnd() {
        var timeline = PauseTimeline()
        _ = timeline.adjust(t(10), track: .video)
        timeline.pause()
        _ = timeline.adjust(t(30), duration: t(1), track: .audio)
        #expect(timeline.latestEndTime == t(10))
    }
}
