import Foundation

enum UsageDecodeError: Error {
    case notAnObject
}

struct RateLimit: Equatable, Identifiable {
    /// "session" / "weekly_all" / "weekly_scoped" など
    let kind: String
    /// 使用率（0〜100の整数）
    let percent: Int
    let resetsAt: Date?
    /// weekly_scoped のときの対象モデル表示名（例 "Fable"）
    let modelName: String?

    var id: String { kind + (modelName.map { ":" + $0 } ?? "") }
}

struct UsageSnapshot: Equatable {
    let limits: [RateLimit]

    static func decode(from data: Data) throws -> UsageSnapshot {
        guard let root = try? JSONSerialization.jsonObject(with: data),
              let dict = root as? [String: Any] else {
            throw UsageDecodeError.notAnObject
        }
        let entries = dict["limits"] as? [[String: Any]] ?? []
        let limits: [RateLimit] = entries.compactMap { entry in
            guard let kind = entry["kind"] as? String,
                  let percent = entry["percent"] as? NSNumber else { return nil }
            let resetsAt = (entry["resets_at"] as? String).flatMap(parseISO8601)
            let modelName = (((entry["scope"] as? [String: Any])?["model"]) as? [String: Any])?["display_name"] as? String
            return RateLimit(kind: kind, percent: percent.intValue, resetsAt: resetsAt, modelName: modelName)
        }
        return UsageSnapshot(limits: limits)
    }

    /// 小数秒あり/なし・マイクロ秒（3桁超）に対応するISO8601パース
    private static func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: string) { return date }
        if let dotRange = string.range(of: #"\.\d+"#, options: .regularExpression) {
            return formatter.date(from: string.replacingCharacters(in: dotRange, with: ""))
        }
        return nil
    }
}
