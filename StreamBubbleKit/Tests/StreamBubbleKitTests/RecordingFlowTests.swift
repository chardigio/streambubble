import Foundation
import Testing
@testable import StreamBubbleKit

/// Holds an async call open until the test lets it go, so a test can act in the gap (for
/// example, press Hyperkey+P while the stream starts).
@MainActor
private final class Gate<Value: Sendable> {
    private var continuation: CheckedContinuation<Value, Never>?
    var isWaiting: Bool { continuation != nil }

    func wait() async -> Value {
        await withCheckedContinuation { continuation = $0 }
    }

    func open(_ value: Value) {
        continuation?.resume(returning: value)
        continuation = nil
    }
}

/// A clock that moves only when the test calls `advance()`.
@MainActor
private final class FakeClock: FlowClock {
    private var sleepers: [CheckedContinuation<Void, Never>] = []
    var sleeperCount: Int { sleepers.count }

    func sleep(for duration: Duration) async throws {
        await withCheckedContinuation { sleepers.append($0) }
    }

    func advance() async {
        let woken = sleepers
        sleepers = []
        woken.forEach { $0.resume() }
        await settle()
    }
}

private struct StartFailure: Error {}

@MainActor
private final class FakeHost: RecordingHost {
    var target: String? = "main display"
    var holdPrepare = false
    let prepareGate = Gate<Void>()
    var holdStart = false
    let startGate = Gate<Error?>()
    var savedURL: URL? = URL(fileURLWithPath: "/tmp/video.mp4")
    var stopError: Error?

    var prepareCount = 0
    var countdowns: [Int] = []
    var hideCountdownCount = 0
    var started: [String] = []
    var pauseCount = 0
    var resumeCount = 0
    var stopCount = 0
    var finished: [URL?] = []
    var failures: [Error] = []
    var cleanUpCount = 0

    func prepare() async -> String? {
        prepareCount += 1
        if holdPrepare { await prepareGate.wait() }
        return target
    }

    func showCountdown(_ remaining: Int) { countdowns.append(remaining) }
    func hideCountdown() { hideCountdownCount += 1 }

    func startRecording(_ target: String) async throws {
        started.append(target)
        if holdStart, let error = await startGate.wait() { throw error }
    }

    func pauseRecording() { pauseCount += 1 }
    func resumeRecording() { resumeCount += 1 }

    func stopRecording() async throws -> URL? {
        stopCount += 1
        if let stopError { throw stopError }
        return savedURL
    }

    func recordingDidFinish(_ url: URL?) { finished.append(url) }
    func recordingDidFail(_ error: Error) { failures.append(error) }
    func cleanUp() { cleanUpCount += 1 }
}

/// Lets the tasks that the flow started run up to their next suspension.
@MainActor
private func settle() async {
    for _ in 0..<50 { await Task.yield() }
}

@MainActor
@Suite struct RecordingFlowTests {
    private let host = FakeHost()
    private let clock = FakeClock()
    private let flow: RecordingFlow<FakeHost>

    init() {
        flow = RecordingFlow(host: host, clock: clock)
    }

    /// Toggles and runs the countdown to the end, so the stream has started.
    private func startRecording() async {
        flow.toggle()
        await settle()
        for _ in 0..<RecorderState.countdownStart { await clock.advance() }
    }

    @Test func aFullRecording() async {
        flow.toggle()
        await settle()
        #expect(host.prepareCount == 1)
        #expect(flow.state == .countingDown(3))
        #expect(host.countdowns == [3])

        await clock.advance()
        await clock.advance()
        #expect(host.countdowns == [3, 2, 1])
        await clock.advance()
        #expect(host.hideCountdownCount == 1)
        #expect(host.started == ["main display"])
        #expect(flow.state == .recording)

        await clock.advance()
        #expect(flow.elapsedSeconds == 1)

        flow.togglePause()
        #expect(flow.state == .paused)
        #expect(host.pauseCount == 1)
        await clock.advance()
        #expect(flow.elapsedSeconds == 1) // The clock stops while paused.

        flow.togglePause()
        #expect(host.resumeCount == 1)
        await clock.advance()
        #expect(flow.elapsedSeconds == 2)

        flow.toggle()
        #expect(flow.state == .finishing)
        await settle()
        #expect(host.stopCount == 1)
        #expect(host.finished == [URL(fileURLWithPath: "/tmp/video.mp4")])
        #expect(host.cleanUpCount == 1)
        #expect(flow.state == .idle)
        #expect(flow.elapsedSeconds == 0)
    }

    @Test func aCancelledPreparationGoesBackToIdle() async {
        host.target = nil // The user pressed Escape during the region drag.
        flow.toggle()
        await settle()
        #expect(flow.state == .idle)
        #expect(host.countdowns.isEmpty)
        #expect(host.started.isEmpty)
    }

    @Test func toggleDuringThePreparationDoesNotPrepareTwice() async {
        host.holdPrepare = true
        flow.toggle()
        await settle()
        flow.toggle()
        flow.togglePause()
        await settle()
        #expect(host.prepareCount == 1)
        #expect(flow.state == .preparing)
        host.prepareGate.open(())
        await settle()
        #expect(flow.state == .countingDown(3))
    }

    @Test func pauseWhileTheStreamStartsIsIgnored() async {
        // PR #2491 review: a pause in this gap went to a timeline that start() then replaced,
        // so the menu said Paused while the recorder recorded.
        host.holdStart = true
        await startRecording()
        #expect(flow.state == .starting)
        #expect(host.startGate.isWaiting)

        flow.togglePause()
        flow.toggle()
        #expect(flow.state == .starting)
        #expect(host.pauseCount == 0)
        #expect(host.stopCount == 0)

        host.startGate.open(nil)
        await settle()
        #expect(flow.state == .recording)
    }

    @Test func aFailedStartGoesBackToIdleAndReportsTheError() async {
        host.holdStart = true
        await startRecording()
        host.startGate.open(StartFailure())
        await settle()
        #expect(flow.state == .idle)
        #expect(host.failures.count == 1)
        #expect(host.cleanUpCount == 1)
        await clock.advance()
        #expect(flow.elapsedSeconds == 0)
    }

    @Test func toggleDuringTheCountdownCancelsIt() async {
        flow.toggle()
        await settle()
        await clock.advance()
        flow.toggle()
        #expect(flow.state == .idle)
        #expect(host.hideCountdownCount == 1)
        #expect(host.cleanUpCount == 1)
        await clock.advance()
        await clock.advance()
        #expect(host.started.isEmpty)
        #expect(host.countdowns == [3, 2])
    }

    @Test func aCancelledCountdownDoesNotTickTheNextOne() async {
        // The old countdown's sleep still ends after a cancel. It must not move the new one.
        flow.toggle()
        await settle()
        flow.toggle()
        flow.toggle()
        await settle()
        #expect(flow.state == .countingDown(3))
        await clock.advance()
        #expect(flow.state == .countingDown(2))
    }

    @Test func anUnexpectedStopWhileRecordingKeepsTheFile() async {
        await startRecording()
        let url = URL(fileURLWithPath: "/tmp/partial.mp4")
        flow.streamDidStop(url: url, error: StartFailure())
        #expect(flow.state == .idle)
        #expect(host.finished == [url])
        #expect(host.failures.isEmpty)
        #expect(host.cleanUpCount == 1)
    }

    @Test func anUnexpectedStopWithNoFileReportsTheError() async {
        await startRecording()
        flow.streamDidStop(url: nil, error: StartFailure())
        #expect(flow.state == .idle)
        #expect(host.finished.isEmpty)
        #expect(host.failures.count == 1)
    }

    @Test func anUnexpectedStopAfterTheUserStoppedIsIgnored() async {
        await startRecording()
        flow.toggle()
        flow.streamDidStop(url: nil, error: StartFailure())
        await settle()
        #expect(host.failures.isEmpty)
        #expect(host.finished.count == 1)
    }

    @Test func noFileFromStopIsStillAFinish() async {
        host.savedURL = nil
        await startRecording()
        flow.toggle()
        await settle()
        #expect(host.finished == [nil])
        #expect(flow.state == .idle)
    }

    @Test func aWriterFailureAtStopIsReportedAsAnError() async {
        // Regression (QA, 2026-10-11): a failed writer showed "No frames were recorded",
        // which hid the real cause.
        host.stopError = StartFailure()
        await startRecording()
        flow.toggle()
        await settle()
        #expect(flow.state == .idle)
        #expect(host.finished.isEmpty)
        #expect(host.failures.count == 1)
        #expect(host.cleanUpCount == 1)
    }
}
