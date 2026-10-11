/// The global shortcuts. Charlie maps Caps Lock to a "hyperkey" (Cmd+Ctrl+Opt+Shift), so a
/// hyperkey chord cannot clash with a shortcut in another app.
///
/// The values are Carbon key codes and modifier bits because the app registers them with
/// `RegisterEventHotKey`. That API, unlike a global `NSEvent` key monitor, needs no
/// Accessibility permission.
public struct HotKeyBinding: Sendable, Equatable {
    public let id: UInt32
    public let keyCode: UInt32
    public let modifiers: UInt32
    /// The key's letter, for messages such as "Hyperkey+L is in use by another app".
    public let key: String

    public var displayName: String {
        modifiers == Self.hyperModifiers ? "Hyperkey+\(key)" : key
    }

    // cmdKey | shiftKey | optionKey | controlKey from Carbon's Events.h.
    public static let hyperModifiers: UInt32 = 256 | 512 | 2048 | 4096

    public static let toggleRecording = HotKeyBinding(id: 1, keyCode: 37, modifiers: hyperModifiers, key: "L")
    public static let togglePause = HotKeyBinding(id: 2, keyCode: 35, modifiers: hyperModifiers, key: "P")
}
