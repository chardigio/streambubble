import AVFoundation
import OSLog
import ScreenCaptureKit
import VideoToolbox
import StreamBubbleKit

/// What to record: a display, and optionally a part of it.
/// SCDisplay and SCWindow are plain value descriptions that ScreenCaptureKit hands out, but
/// they are not marked Sendable, so the struct says it for them.
struct CaptureTarget: @unchecked Sendable {
    let display: SCDisplay
    /// The part of the display to record, in display points with a top-left origin. Nil
    /// records the whole display.
    let sourceRect: CGRect?
    /// The display's backing scale, so the file has the screen's real pixel density.
    let scale: CGFloat
    /// The codec, frame rate, and bitrate of the file.
    let quality: RecordingQuality
    /// Our own windows to leave out of the video (the region outline, the countdown). The
    /// bubble is not in this list: the video must show it.
    let excludedWindows: [SCWindow]
    /// False when the user denied the microphone. The video then has no audio track.
    let includeMicrophone: Bool
}

/// Records the screen and the microphone to an .mp4.
///
/// This uses an `SCStream` with an `AVAssetWriter` and not `SCRecordingOutput`, because
/// `SCRecordingOutput` cannot pause. Pausing here drops the buffers and `PauseTimeline` moves
/// the later times back, so the file plays straight through.
///
/// All the writer state is touched only on `queue`, which is also the queue that
/// ScreenCaptureKit delivers buffers on. That is the reason for `@unchecked Sendable`.
final class ScreenRecorder: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.cd17822.streambubble", category: "recorder")
    private let queue = DispatchQueue(label: "com.cd17822.streambubble.recorder")
    private var stream: SCStream?
    /// When `start` was called, so the log shows how long the first frame took.
    private var startRequestedAt: ContinuousClock.Instant?
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var timeline = PauseTimeline()
    private var sessionStarted = false

    /// Called on the main actor when the stream ends without `stop()`, for example when the
    /// user clicks "Stop" in the macOS screen-sharing menu. The file up to that point is
    /// still saved, and its URL comes with the error.
    var onUnexpectedStop: (@MainActor @Sendable (URL?, Error) -> Void)?

    func start(target: CaptureTarget, outputURL: URL) async throws {
        let pointSize = target.sourceRect?.size
            ?? CGSize(width: target.display.width, height: target.display.height)
        let quality = target.quality
        let pixels = quality.outputPixelSize(for: pointSize, displayScale: target.scale)
        let frameRate = quality.framesPerSecond

        let config = SCStreamConfiguration()
        config.width = pixels.width
        config.height = pixels.height
        if let rect = target.sourceRect { config.sourceRect = rect }
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.sRGB
        config.queueDepth = 6
        config.showsCursor = true
        // macOS draws a ring at each click, which is the click animation Charlie asked for.
        config.showMouseClicks = true
        config.capturesAudio = false
        config.captureMicrophone = target.includeMicrophone
        if target.includeMicrophone {
            config.microphoneCaptureDeviceID = AVCaptureDevice.default(for: .audio)?.uniqueID
        }

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: Self.videoSettings(quality: quality, pixels: pixels))
        video.expectsMediaDataInRealTime = true
        let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 128_000,
        ])
        audio.expectsMediaDataInRealTime = true
        guard writer.canAdd(video), !target.includeMicrophone || writer.canAdd(audio) else {
            throw RecorderError.writerSetupFailed
        }
        writer.add(video)
        if target.includeMicrophone { writer.add(audio) }
        guard writer.startWriting() else {
            throw writer.error ?? RecorderError.writerSetupFailed
        }

        let filter = SCContentFilter(display: target.display, excludingWindows: target.excludedWindows)
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        if target.includeMicrophone {
            try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: queue)
        }

        queue.sync {
            self.writer = writer
            self.videoInput = video
            self.audioInput = target.includeMicrophone ? audio : nil
            self.timeline = PauseTimeline()
            self.sessionStarted = false
            self.stream = stream
            self.startRequestedAt = .now
        }
        let captureRequested = ContinuousClock.now
        do {
            try await stream.startCapture()
            Self.logger.info("startCapture took \(captureRequested.duration(to: .now), privacy: .public)")
        } catch {
            queue.sync {
                self.stream = nil
                self.writer = nil
                self.videoInput = nil
                self.audioInput = nil
            }
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }
    }

    func pause() { queue.async { self.timeline.pause() } }
    func resume() { queue.async { self.timeline.resume() } }

    /// Stops the capture and finishes the file. Returns the file URL, or nil when no frame
    /// arrived (the file would be empty, so it is deleted). Throws the writer's error when
    /// the file could not be finished.
    func stop() async throws -> URL? {
        let stream = queue.sync { self.stream }
        try? await stream?.stopCapture()
        return try await finishWriting()
    }

    private func finishWriting() async throws -> URL? {
        let parts: (AVAssetWriter, Bool, CMTime?)? = queue.sync {
            defer {
                self.stream = nil
                self.writer = nil
                self.videoInput = nil
                self.audioInput = nil
            }
            guard let writer = self.writer else { return nil }
            self.videoInput?.markAsFinished()
            self.audioInput?.markAsFinished()
            return (writer, self.sessionStarted, self.timeline.latestEndTime)
        }
        guard let (writer, started, endTime) = parts else { return nil }
        guard started else {
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: writer.outputURL)
            return nil
        }
        // End after the last buffer on either track. A still screen sends no new frames, so
        // an end at the last frame would cut the words that the user said after it.
        if let endTime { writer.endSession(atSourceTime: endTime) }
        // A writer that already failed cannot finish; finishWriting() returns at once.
        if writer.status == .writing { await writer.finishWriting() }
        guard writer.status == .completed else {
            let error = writer.error ?? RecorderError.writerSetupFailed
            Self.logger.error("The writer failed: \(error.localizedDescription, privacy: .public)")
            // A file with no moov atom cannot play, so it is of no use to keep.
            try? FileManager.default.removeItem(at: writer.outputURL)
            throw error
        }
        return writer.outputURL
    }

    // MARK: SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard buffer.isValid, let writer, writer.status == .writing else { return }
        switch type {
        case .screen:
            guard Self.isCompleteFrame(buffer) else { return }
            let raw = buffer.presentationTimeStamp
            guard let time = timeline.adjust(raw, duration: buffer.duration, track: .video) else { return }
            if !sessionStarted {
                writer.startSession(atSourceTime: time)
                sessionStarted = true
                if let startRequestedAt {
                    Self.logger.info("First frame came \(startRequestedAt.duration(to: .now), privacy: .public) after start")
                }
            }
            append(buffer, at: time, to: videoInput)
        case .microphone:
            // Audio before the first frame has no video to go with, so it is dropped.
            guard sessionStarted else { return }
            guard let time = timeline.adjust(buffer.presentationTimeStamp, duration: buffer.duration, track: .audio) else {
                return
            }
            append(buffer, at: time, to: audioInput)
        default:
            break
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { [weak self] in
            guard let self else { return }
            let url: URL?
            var reported = error
            do { url = try await self.finishWriting() } catch {
                url = nil
                reported = error
            }
            await MainActor.run { self.onUnexpectedStop?(url, reported) }
        }
    }

    // MARK: Helpers

    private static func videoSettings(quality: RecordingQuality, pixels: PixelSize) -> [String: Any] {
        var compression: [String: Any] = [
            AVVideoAverageBitRateKey: quality.averageBitRate(for: pixels),
            AVVideoExpectedSourceFrameRateKey: quality.framesPerSecond,
            // A key frame each 2 seconds, so a player can seek in the file with no long wait.
            AVVideoMaxKeyFrameIntervalKey: quality.framesPerSecond * 2,
        ]
        if let encoderQuality = quality.encoderQuality {
            compression[AVVideoQualityKey] = encoderQuality
        }
        let codec: AVVideoCodecType
        switch quality.codec {
        case .h264:
            codec = .h264
            compression[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
        case .hevc:
            codec = .hevc
            compression[AVVideoProfileLevelKey] = kVTProfileLevel_HEVC_Main_AutoLevel as String
        }
        return [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: pixels.width,
            AVVideoHeightKey: pixels.height,
            // The frames are sRGB, and the encoder converts them to BT.709. Without the tag,
            // a player guesses the colors, and some guess wrong and show a washed-out picture.
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
            AVVideoCompressionPropertiesKey: compression,
        ]
    }

    private func append(_ buffer: CMSampleBuffer, at time: CMTime, to input: AVAssetWriterInput?) {
        guard let input, input.isReadyForMoreMediaData else { return }
        if time == buffer.presentationTimeStamp {
            input.append(buffer)
        } else if let moved = Self.retimed(buffer, by: CMTimeSubtract(buffer.presentationTimeStamp, time)) {
            input.append(moved)
        }
    }

    /// ScreenCaptureKit also sends "idle" buffers with no image when nothing on the screen
    /// changed. Only a complete frame has pixels to write.
    private static func isCompleteFrame(_ buffer: CMSampleBuffer) -> Bool {
        guard
            let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
            let rawStatus = attachments.first?[.status] as? Int,
            let status = SCFrameStatus(rawValue: rawStatus)
        else { return false }
        return status == .complete
    }

    private static func retimed(_ buffer: CMSampleBuffer, by offset: CMTime) -> CMSampleBuffer? {
        var count: CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(buffer, entryCount: 0, arrayToFill: nil, entriesNeededOut: &count)
        var timings = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(), count: count)
        CMSampleBufferGetSampleTimingInfoArray(buffer, entryCount: count, arrayToFill: &timings, entriesNeededOut: &count)
        for index in timings.indices {
            timings[index].presentationTimeStamp = CMTimeSubtract(timings[index].presentationTimeStamp, offset)
            if timings[index].decodeTimeStamp.isValid {
                timings[index].decodeTimeStamp = CMTimeSubtract(timings[index].decodeTimeStamp, offset)
            }
        }
        var result: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault, sampleBuffer: buffer,
            sampleTimingEntryCount: count, sampleTimingArray: &timings, sampleBufferOut: &result
        )
        return result
    }
}

enum RecorderError: LocalizedError {
    case writerSetupFailed
    case noDisplay

    var errorDescription: String? {
        switch self {
        case .writerSetupFailed: "StreamBubble could not write the video file."
        case .noDisplay: "StreamBubble could not find the display to record."
        }
    }
}
