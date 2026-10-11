import CoreMedia

/// Removes paused gaps from the sample times so that pause and resume give one continuous file.
///
/// ScreenCaptureKit keeps a host-clock time on each buffer, and that clock does not stop while
/// the user pauses. If the writer took those times as they are, the video would freeze for the
/// length of each pause. The timeline drops the buffers that arrive while paused, and moves each
/// later buffer back by the total paused time.
///
/// The video and audio tracks share one offset. Separate offsets would put the two tracks out
/// of sync by the small difference in when each track's first buffer after a resume arrived.
public struct PauseTimeline: Sendable {
    public enum Track: Sendable, Hashable {
        case video
        case audio
    }

    public private(set) var isPaused = false
    private var offset: CMTime = .zero
    /// The end of the latest raw buffer seen on any track, so a resume can measure the gap
    /// from it. The end, not the start: the first buffer after a resume then lands after
    /// everything already written, not on top of the last one.
    private var latestRawEnd: CMTime?
    private var pausedAtRawEnd: CMTime?
    /// Set by `resume()`; the next buffer on any track closes the gap.
    private var needsGapClose = false
    private var lastWritten: [Track: (start: CMTime, end: CMTime)] = [:]

    /// The end of the latest buffer that was not dropped, on any track. The writer ends the
    /// session here: a still screen sends no new frames, so the last frame can come many
    /// seconds before the last words, and a session that ended at that frame would cut them.
    public private(set) var latestEndTime: CMTime?

    public init() {}

    public mutating func pause() {
        guard !isPaused else { return }
        isPaused = true
        pausedAtRawEnd = latestRawEnd
    }

    public mutating func resume() {
        guard isPaused else { return }
        isPaused = false
        needsGapClose = pausedAtRawEnd != nil
    }

    /// Returns the time to write the buffer at, or nil when the buffer must be dropped.
    ///
    /// AVAssetWriter fails the whole file, for good, when a track gets a time that is not
    /// after the one before it. ScreenCaptureKit frames carry no duration, so after a resume
    /// the first frame can land exactly on the last frame's time. Each track therefore drops
    /// a buffer that does not start strictly after its last start, or that starts before
    /// its last end.
    public mutating func adjust(_ rawTime: CMTime, duration: CMTime = .zero, track: Track) -> CMTime? {
        if isPaused { return nil }
        if needsGapClose, let pausedAt = pausedAtRawEnd {
            offset = CMTimeAdd(offset, CMTimeSubtract(rawTime, pausedAt))
            needsGapClose = false
            pausedAtRawEnd = nil
        }
        let length = duration.isValid ? duration : .zero
        let rawEnd = CMTimeAdd(rawTime, length)
        latestRawEnd = max(latestRawEnd ?? rawEnd, rawEnd)

        let adjusted = CMTimeSubtract(rawTime, offset)
        let end = CMTimeAdd(adjusted, length)
        if let last = lastWritten[track], adjusted <= last.start || adjusted < last.end { return nil }
        lastWritten[track] = (adjusted, end)
        latestEndTime = max(latestEndTime ?? end, end)
        return adjusted
    }
}
