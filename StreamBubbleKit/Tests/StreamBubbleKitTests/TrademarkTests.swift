import Foundation
import Testing

/// StreamBubble is public and sold on the Mac App Store, so it must not name another
/// company's product. A comparison to a competitor can look like a claim of affiliation, and
/// App Review rejects metadata that names other apps. The public repo mirrors this folder, so
/// this test scans every text file in it. The names are in base64, so this file does not
/// contain them either.
@Suite struct TrademarkTests {
    static let projectFolder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // StreamBubbleKitTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // StreamBubbleKit
        .deletingLastPathComponent()  // StreamBubble (the project)

    static let bannedNames = ["bG9vbQ=="].map { String(decoding: Data(base64Encoded: $0)!, as: UTF8.self) }
    static let skippedFolders: Set<String> = [".build", ".git", ".swiftpm", "DerivedData", "build"]
    static let textExtensions: Set<String> = [
        "md", "swift", "yml", "yaml", "sh", "plist", "entitlements", "json", "svg", "txt", "",
    ]

    static func textFiles() -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: projectFolder, includingPropertiesForKeys: [.isDirectoryKey])
        var files: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            if skippedFolders.contains(url.lastPathComponent) || url.pathExtension == "xcodeproj" {
                enumerator?.skipDescendants()
                continue
            }
            let isFolder = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if !isFolder && textExtensions.contains(url.pathExtension.lowercased()) {
                files.append(url)
            }
        }
        return files
    }

    @Test func theMatchIsForWholeWordsOnly() throws {
        let name = try #require(Self.bannedNames.first)
        let pattern = try Regex("\\b\(name)\\b").ignoresCase()
        #expect("the \(name.capitalized) app".firstMatch(of: pattern) != nil)
        #expect("a b\(name) effect".firstMatch(of: pattern) == nil)
    }

    @Test func theProjectFindsItsOwnFiles() {
        let names = Self.textFiles().map(\.lastPathComponent)
        #expect(names.contains("README.md"))
        #expect(names.contains("TrademarkTests.swift"))
    }

    @Test func noFileNamesACompetitor() throws {
        for file in Self.textFiles() {
            let text = try String(contentsOf: file, encoding: .utf8)
            for name in Self.bannedNames {
                // A whole word only, so a longer word that contains the name does not fail.
                let pattern = try Regex("\\b\(name)\\b").ignoresCase()
                #expect(text.firstMatch(of: pattern) == nil, "\(file.path) contains \"\(name)\"")
            }
        }
    }
}
