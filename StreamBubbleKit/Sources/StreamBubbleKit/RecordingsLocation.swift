import Darwin
import Foundation

/// Finds `~/Movies/StreamBubble` in the user's real home folder.
///
/// In the App Sandbox, `FileManager` and `NSHomeDirectory()` give the app's container
/// (`~/Library/Containers/<bundle ID>/Data`). The `assets.movies.read-write` entitlement gives
/// access to the real `~/Movies`, but only by its real path, and a recording in the container
/// is one that the user cannot find. The password database still holds the real home folder.
public enum RecordingsLocation {
    public static func folder(home: URL = realHomeDirectory()) -> URL {
        home
            .appendingPathComponent("Movies", isDirectory: true)
            .appendingPathComponent("StreamBubble", isDirectory: true)
    }

    public static func realHomeDirectory() -> URL {
        if let entry = getpwuid(getuid()), let dir = entry.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }
}
