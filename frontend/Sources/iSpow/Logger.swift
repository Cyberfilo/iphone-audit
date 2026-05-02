import Foundation

/// Writes timestamped lines to `/tmp/ispow.log` and to stderr (via NSLog).
/// Tail with: `tail -f /tmp/ispow.log`
enum Log {
    static let path = "/tmp/ispow.log"

    private static let queue = DispatchQueue(label: "iSpow.log")
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Truncate the log on app launch so each session starts clean.
    static func reset() {
        queue.async {
            try? FileManager.default.removeItem(atPath: path)
            FileManager.default.createFile(atPath: path, contents: nil)
        }
    }

    static func log(_ tag: String, _ msg: String,
                    file: String = #fileID, line: Int = #line) {
        let stamp = isoFormatter.string(from: Date())
        let where_ = "\(file):\(line)"
        let formatted = "\(stamp) [\(tag)] \(msg)  (\(where_))"
        // stderr → Console.app
        NSLog("%@", formatted)
        // file → tail-able
        queue.async {
            guard let data = (formatted + "\n").data(using: .utf8) else { return }
            if let h = FileHandle(forWritingAtPath: path) {
                h.seekToEndOfFile()
                h.write(data)
                try? h.close()
            } else {
                FileManager.default.createFile(atPath: path, contents: data)
            }
        }
    }

    static func info(_ msg: String, file: String = #fileID, line: Int = #line) {
        log("INFO", msg, file: file, line: line)
    }
    static func warn(_ msg: String, file: String = #fileID, line: Int = #line) {
        log("WARN", msg, file: file, line: line)
    }
    static func error(_ msg: String, file: String = #fileID, line: Int = #line) {
        log("ERROR", msg, file: file, line: line)
    }
}
