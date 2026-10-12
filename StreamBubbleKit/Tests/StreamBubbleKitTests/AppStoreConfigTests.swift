import Foundation
import Testing
@testable import StreamBubbleKit

/// The Mac App Store rejects a build without the App Sandbox, and a sandboxed build without
/// these entitlements fails at run time with no camera, no voice, or no place to save. The
/// app target is not in this package, so these tests read its config files from the source tree.
@Suite struct AppStoreConfigTests {
    static let appFolder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // StreamBubbleKitTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // StreamBubbleKit
        .deletingLastPathComponent()  // StreamBubble (the project)
        .appendingPathComponent("StreamBubble", isDirectory: true)

    static func plist(_ name: String) throws -> [String: Any] {
        let data = try Data(contentsOf: appFolder.appendingPathComponent(name))
        return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    @Test(arguments: [
        "com.apple.security.app-sandbox",
        "com.apple.security.device.camera",
        "com.apple.security.device.audio-input",
        "com.apple.security.assets.movies.read-write",
    ])
    func theEntitlementsAllow(_ key: String) throws {
        let entitlements = try Self.plist("StreamBubble.entitlements")
        #expect(entitlements[key] as? Bool == true)
    }

    @Test func theAppDeclaresNoNonExemptEncryption() throws {
        // Without this key, App Store Connect holds each build for an export compliance answer.
        let info = try Self.plist("Info.plist")
        #expect(info["ITSAppUsesNonExemptEncryption"] as? Bool == false)
    }
}

@Suite struct RecordingsLocationTests {
    @Test func theFolderIsStreamBubbleInsideTheRealMoviesFolder() {
        let home = URL(fileURLWithPath: "/Users/someone", isDirectory: true)
        #expect(RecordingsLocation.folder(home: home).path == "/Users/someone/Movies/StreamBubble")
    }

    @Test func theRealHomeIsNotASandboxContainer() {
        let home = RecordingsLocation.realHomeDirectory()
        #expect(!home.path.contains("/Library/Containers/"))
        #expect(home.path == NSHomeDirectoryForUser(NSUserName()))
    }
}
