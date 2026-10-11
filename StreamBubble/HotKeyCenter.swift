import Carbon.HIToolbox
import OSLog
import StreamBubbleKit

/// Registers the global shortcuts with Carbon's `RegisterEventHotKey`.
///
/// This old API is still the only way to get a system-wide shortcut without the Accessibility
/// permission: a global `NSEvent` monitor for key presses needs that permission, and it also
/// cannot stop the key press from reaching the front app.
@MainActor
final class HotKeyCenter {
    private var refs: [EventHotKeyRef] = []
    private var handlerRef: EventHandlerRef?
    private var actions: [UInt32: () -> Void] = [:]

    // The Carbon callback is a C function, so it cannot capture `self`. It finds the center
    // through this one shared instance.
    private static var shared: HotKeyCenter?
    private static let logger = Logger(subsystem: "com.cd17822.streambubble", category: "hotkeys")

    /// Returns false when the system refuses the shortcut, most often because another app
    /// already registered the same chord.
    @discardableResult
    func register(_ binding: HotKeyBinding, action: @escaping () -> Void) -> Bool {
        installHandlerIfNeeded()
        actions[binding.id] = action
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x5342_424C), id: binding.id) // "SBBL"
        let status = RegisterEventHotKey(binding.keyCode, binding.modifiers, id, GetEventDispatcherTarget(), 0, &ref)
        guard status == noErr, let ref else {
            actions[binding.id] = nil
            Self.logger.error("RegisterEventHotKey failed for \(binding.displayName, privacy: .public): \(status)")
            return false
        }
        refs.append(ref)
        return true
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        Self.shared = self
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ in
            var id = EventHotKeyID()
            GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &id
            )
            let hotKeyID = id.id
            MainActor.assumeIsolated { HotKeyCenter.shared?.actions[hotKeyID]?() }
            return noErr
        }, 1, &spec, nil, &handlerRef)
    }
}
