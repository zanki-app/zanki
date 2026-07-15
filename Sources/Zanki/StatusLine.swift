import AppKit

enum StatusLine {
    static let warningPercent = 60
    static let dangerPercent = 80

    static func label(for limit: RateLimit) -> String {
        switch limit.kind {
        case "session": return "5h"
        case "weekly_all": return "週"
        default:
            if let first = limit.modelName?.first { return String(first) }
            return String(limit.kind.prefix(3))
        }
    }

    static func resetText(until date: Date?, now: Date = Date()) -> String {
        guard let date else { return "" }
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60
        if days > 0 { return "リセットまで \(days)日\(hours)時間" }
        if hours > 0 { return "リセットまで \(hours)時間\(minutes)分" }
        return "リセットまで \(minutes)分"
    }
}
