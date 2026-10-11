/// The recorder's states. The menu, the hotkeys, and the countdown all go through these
/// transitions, so a hotkey press at a strange moment (during the region drag, during the
/// countdown, or while the stream starts or the file finishes) cannot start a second
/// recording or pause a stream that does not exist yet.
public enum RecorderState: Equatable, Sendable {
    case idle
    /// Permission checks and the region drag, before the countdown.
    case preparing
    case countingDown(Int)
    /// The countdown is over, and the stream has not started yet.
    case starting
    case recording
    case paused
    case finishing

    public static let countdownStart = 3

    public var isBusy: Bool { self != .idle }

    /// The menus disable Start/Stop when a press would do nothing, so the user can see that
    /// the app is busy and not broken.
    public var canToggle: Bool { onToggle() != self }

    /// The menus show Pause/Resume only when a press would do something.
    public var canPauseToggle: Bool { onPauseToggle() != self }

    /// Start or stop, from the menu or Hyperkey+L.
    public func onToggle() -> RecorderState {
        switch self {
        case .idle: .preparing
        case .countingDown: .idle
        case .recording, .paused: .finishing
        case .preparing, .starting, .finishing: self
        }
    }

    /// Pause or resume, from the menu or Hyperkey+P.
    public func onPauseToggle() -> RecorderState {
        switch self {
        case .recording: .paused
        case .paused: .recording
        default: self
        }
    }

    public func onPrepared(success: Bool) -> RecorderState {
        guard self == .preparing else { return self }
        return success ? .countingDown(Self.countdownStart) : .idle
    }

    /// One second of the countdown.
    public func onTick() -> RecorderState {
        guard case let .countingDown(remaining) = self else { return self }
        return remaining > 1 ? .countingDown(remaining - 1) : .starting
    }

    public func onStarted() -> RecorderState {
        self == .starting ? .recording : self
    }
}
