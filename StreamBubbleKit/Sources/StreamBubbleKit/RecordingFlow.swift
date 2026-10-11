import Foundation
import Observation

/// The parts of a recording that need the real system: windows, permissions, and the stream.
/// The app implements this; the tests use a fake, so the flow's timing can be checked
/// without a screen, a camera, or a permission prompt.
@MainActor
public protocol RecordingHost: AnyObject {
    associatedtype Target

    /// Checks the permissions and asks for the region if needed. Nil means "do not record"
    /// (a permission is missing, or the user pressed Escape).
    func prepare() async -> Target?
    func showCountdown(_ remaining: Int)
    func hideCountdown()
    func startRecording(_ target: Target) async throws
    func pauseRecording()
    func resumeRecording()
    /// Returns the saved file, or nil when nothing was recorded. Throws when the file could
    /// not be finished, so the user sees the real cause.
    func stopRecording() async throws -> URL?
    func recordingDidFinish(_ url: URL?)
    func recordingDidFail(_ error: Error)
    /// Removes what `prepare()` put on the screen, such as the region outline.
    func cleanUp()
}

@MainActor
public protocol FlowClock: AnyObject {
    func sleep(for duration: Duration) async throws
}

@MainActor
public final class SystemFlowClock: FlowClock {
    public init() {}

    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

/// Runs one recording from the first Hyperkey+L to the saved file: prepare, count down,
/// start, pause and resume, stop.
///
/// Each user action goes through a `RecorderState` transition first, and the side effects
/// follow from the new state. Each run also has a number, so a sleep from a cancelled
/// countdown that ends late cannot tick the next countdown or the next clock.
@MainActor
@Observable
public final class RecordingFlow<Host: RecordingHost> {
    public private(set) var state: RecorderState = .idle
    /// The recorded time without the pauses, for the menu bar clock.
    public private(set) var elapsedSeconds = 0

    @ObservationIgnored private weak var host: Host?
    @ObservationIgnored private let clock: FlowClock
    @ObservationIgnored private var run = 0
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var clockTask: Task<Void, Never>?

    public init(host: Host, clock: FlowClock = SystemFlowClock()) {
        self.host = host
        self.clock = clock
    }

    public func toggle() {
        let previous = state
        let next = previous.onToggle()
        guard next != previous else { return }
        state = next
        switch next {
        case .preparing:
            run += 1
            let run = run
            task = Task { await self.prepareAndStart(run: run) }
        case .idle:
            // A cancelled countdown.
            task?.cancel()
            host?.hideCountdown()
            reset()
        case .finishing:
            Task { await self.finish() }
        default:
            break
        }
    }

    public func togglePause() {
        let next = state.onPauseToggle()
        guard next != state else { return }
        state = next
        if next == .paused { host?.pauseRecording() } else { host?.resumeRecording() }
    }

    /// The stream ended without a stop from the user, for example from the macOS
    /// screen-sharing menu. The recorder still saves what it has.
    public func streamDidStop(url: URL?, error: Error) {
        guard state == .recording || state == .paused else { return }
        reset()
        if let url { host?.recordingDidFinish(url) } else { host?.recordingDidFail(error) }
    }

    private func prepareAndStart(run: Int) async {
        let target = await host?.prepare()
        guard run == self.run else { return }
        state = state.onPrepared(success: target != nil)
        guard let target, case let .countingDown(first) = state else { return }
        host?.showCountdown(first)

        while case .countingDown = state {
            do { try await clock.sleep(for: .seconds(1)) } catch { return }
            guard run == self.run, case .countingDown = state else { return }
            state = state.onTick()
            if case let .countingDown(remaining) = state { host?.showCountdown(remaining) }
        }
        host?.hideCountdown()
        guard state == .starting else { return }

        do {
            try await host?.startRecording(target)
        } catch {
            guard run == self.run else { return }
            reset()
            host?.recordingDidFail(error)
            return
        }
        guard run == self.run else { return }
        state = state.onStarted()
        startClock(run: run)
    }

    private func finish() async {
        do {
            let url = try await host?.stopRecording()
            reset()
            host?.recordingDidFinish(url)
        } catch {
            reset()
            host?.recordingDidFail(error)
        }
    }

    private func startClock(run: Int) {
        elapsedSeconds = 0
        clockTask = Task {
            while true {
                do { try await clock.sleep(for: .seconds(1)) } catch { return }
                guard run == self.run else { return }
                if state == .recording { elapsedSeconds += 1 }
            }
        }
    }

    /// Back to idle. The run number moves on, so each task from this run stops at its next
    /// check.
    private func reset() {
        run += 1
        task = nil
        clockTask?.cancel()
        clockTask = nil
        elapsedSeconds = 0
        state = .idle
        host?.cleanUp()
    }
}
