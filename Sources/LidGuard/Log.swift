import Foundation

enum LogLevel: String {
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"
}

final class Log: @unchecked Sendable {
    static let shared = Log()

    static let fileURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/LidGuard.log")

    private static let maxBytes = 1_048_576
    private let queue = DispatchQueue(label: "be.pascu.LidGuard.log")

    func callAsFunction(_ level: LogLevel, _ message: String) {
        let stamp = Self.formatter.string(from: Date())
        let line = "\(stamp) \(level.rawValue.padding(toLength: 5, withPad: " ", startingAt: 0)) \(message)\n"
        queue.async { self.append(line) }
        #if DEBUG
        print(line, terminator: "")
        #endif
    }

    private func append(_ line: String) {
        let fm = FileManager.default
        let url = Self.fileURL
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        rotateIfNeeded()
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }

    private func rotateIfNeeded() {
        let url = Self.fileURL
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size >= Self.maxBytes else { return }
        let rotated = url.appendingPathExtension("1")
        try? FileManager.default.removeItem(at: rotated)
        try? FileManager.default.moveItem(at: url, to: rotated)
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
}

let log: Log = Log.shared
