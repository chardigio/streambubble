import Foundation
import Testing
@testable import StreamBubbleKit

@Suite struct RecorderStateTests {
    @Test func toggleFromIdleStartsThePreparation() {
        #expect(RecorderState.idle.onToggle() == .preparing)
    }

    @Test func preparationLeadsToTheCountdownOrBackToIdle() {
        #expect(RecorderState.preparing.onPrepared(success: true) == .countingDown(3))
        #expect(RecorderState.preparing.onPrepared(success: false) == .idle)
        #expect(RecorderState.recording.onPrepared(success: true) == .recording)
    }

    @Test func toggleAndPauseDuringThePreparationDoNothing() {
        // A second Hyperkey+L during the region drag must not start a second drag.
        #expect(RecorderState.preparing.onToggle() == .preparing)
        #expect(RecorderState.preparing.onPauseToggle() == .preparing)
    }

    @Test func countdownTicksDownThenStarts() {
        #expect(RecorderState.countingDown(3).onTick() == .countingDown(2))
        #expect(RecorderState.countingDown(2).onTick() == .countingDown(1))
        #expect(RecorderState.countingDown(1).onTick() == .starting)
    }

    @Test func startingBecomesRecordingOnlyWhenTheStreamRuns() {
        #expect(RecorderState.starting.onStarted() == .recording)
        #expect(RecorderState.idle.onStarted() == .idle)
    }

    @Test func toggleAndPauseWhileStartingDoNothing() {
        // The recorder has no stream yet, so a pause would go to nothing (PR #2491 review).
        #expect(RecorderState.starting.onToggle() == .starting)
        #expect(RecorderState.starting.onPauseToggle() == .starting)
    }

    @Test func toggleDuringTheCountdownCancelsIt() {
        #expect(RecorderState.countingDown(2).onToggle() == .idle)
    }

    @Test func toggleWhileRecordingOrPausedStops() {
        #expect(RecorderState.recording.onToggle() == .finishing)
        #expect(RecorderState.paused.onToggle() == .finishing)
    }

    @Test func toggleWhileFinishingDoesNothing() {
        #expect(RecorderState.finishing.onToggle() == .finishing)
    }

    @Test func pauseFlipsOnlyARunningRecording() {
        #expect(RecorderState.recording.onPauseToggle() == .paused)
        #expect(RecorderState.paused.onPauseToggle() == .recording)
        #expect(RecorderState.idle.onPauseToggle() == .idle)
        #expect(RecorderState.countingDown(2).onPauseToggle() == .countingDown(2))
    }

    @Test func tickOutsideTheCountdownDoesNothing() {
        #expect(RecorderState.recording.onTick() == .recording)
    }

    @Test func busyStates() {
        #expect(RecorderState.idle.isBusy == false)
        #expect(RecorderState.preparing.isBusy)
        #expect(RecorderState.starting.isBusy)
        #expect(RecorderState.countingDown(1).isBusy)
        #expect(RecorderState.recording.isBusy)
        #expect(RecorderState.paused.isBusy)
        #expect(RecorderState.finishing.isBusy)
    }

    @Test func toggleIsAvailableOnlyWhenItChangesTheState() {
        #expect(RecorderState.idle.canToggle)
        #expect(RecorderState.countingDown(2).canToggle)
        #expect(RecorderState.recording.canToggle)
        #expect(RecorderState.paused.canToggle)
        #expect(RecorderState.preparing.canToggle == false)
        #expect(RecorderState.starting.canToggle == false)
        #expect(RecorderState.finishing.canToggle == false)
    }

    @Test func pauseIsAvailableOnlyWhileARecordingRuns() {
        #expect(RecorderState.recording.canPauseToggle)
        #expect(RecorderState.paused.canPauseToggle)
        #expect(RecorderState.idle.canPauseToggle == false)
        #expect(RecorderState.countingDown(1).canPauseToggle == false)
        #expect(RecorderState.starting.canPauseToggle == false)
        #expect(RecorderState.finishing.canPauseToggle == false)
    }
}

@Suite struct HotKeyTests {
    @Test func hyperkeyIsAllFourModifiers() {
        // Carbon modifier bits: cmdKey 256, shiftKey 512, optionKey 2048, controlKey 4096.
        #expect(HotKeyBinding.hyperModifiers == 256 | 512 | 2048 | 4096)
    }

    @Test func defaultBindings() {
        #expect(HotKeyBinding.toggleRecording.keyCode == 37) // kVK_ANSI_L
        #expect(HotKeyBinding.togglePause.keyCode == 35)     // kVK_ANSI_P
        #expect(HotKeyBinding.toggleRecording.modifiers == HotKeyBinding.hyperModifiers)
        #expect(HotKeyBinding.toggleRecording.id != HotKeyBinding.togglePause.id)
    }

    @Test func displayNames() {
        #expect(HotKeyBinding.toggleRecording.displayName == "Hyperkey+L")
        #expect(HotKeyBinding.togglePause.displayName == "Hyperkey+P")
    }
}

@Suite struct RecordingFileNamerTests {
    private let date: Date = {
        var parts = DateComponents()
        parts.year = 2026; parts.month = 10; parts.day = 10
        parts.hour = 15; parts.minute = 4; parts.second = 5
        return Calendar(identifier: .gregorian).date(from: parts)!
    }()

    @Test func namesAFileByItsStartTime() {
        let name = RecordingFileNamer.fileName(for: date, calendar: Calendar(identifier: .gregorian))
        #expect(name == "StreamBubble 2026-10-10 at 15.04.05.mp4")
    }

    @Test func addsANumberWhenTheNameIsTaken() {
        let directory = URL(fileURLWithPath: "/tmp/sb")
        let taken: Set<String> = [
            "/tmp/sb/StreamBubble 2026-10-10 at 15.04.05.mp4",
            "/tmp/sb/StreamBubble 2026-10-10 at 15.04.05 (2).mp4",
        ]
        let url = RecordingFileNamer.uniqueURL(
            in: directory, for: date, calendar: Calendar(identifier: .gregorian),
            exists: { taken.contains($0.path) }
        )
        #expect(url.lastPathComponent == "StreamBubble 2026-10-10 at 15.04.05 (3).mp4")
    }
}
