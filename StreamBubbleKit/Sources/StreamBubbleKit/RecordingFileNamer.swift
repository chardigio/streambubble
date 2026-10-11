import Foundation

/// Names a recording after its start time, in the same style as macOS screenshots, so the
/// files sort by time in Finder.
public enum RecordingFileNamer {
    public static func fileName(for date: Date, calendar: Calendar = .current, suffix: Int? = nil) -> String {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let stamp = String(
            format: "%04d-%02d-%02d at %02d.%02d.%02d",
            c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0, c.second ?? 0
        )
        let number = suffix.map { " (\($0))" } ?? ""
        return "StreamBubble \(stamp)\(number).mp4"
    }

    public static func uniqueURL(
        in directory: URL,
        for date: Date,
        calendar: Calendar = .current,
        exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> URL {
        var url = directory.appendingPathComponent(fileName(for: date, calendar: calendar))
        var suffix = 2
        while exists(url) {
            url = directory.appendingPathComponent(fileName(for: date, calendar: calendar, suffix: suffix))
            suffix += 1
        }
        return url
    }
}
