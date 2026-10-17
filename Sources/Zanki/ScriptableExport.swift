import Foundation

enum ScriptableExport {
    static let preferenceKey = "zanki.exportScriptable"
    static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
            "Library/Mobile Documents/iCloud~dk~simonbs~Scriptable/Documents", isDirectory: true)
    }

    struct Payload: Codable {
        let version: Int
        let updatedAt: String
        let claude: Provider
        let codex: Provider
    }

    struct Provider: Codable {
        let status: String
        let fetchedAt: String?
        let limits: [Limit]

        enum CodingKeys: String, CodingKey { case status, fetchedAt, limits }
        func encode(to encoder: Encoder) throws {
            var values = encoder.container(keyedBy: CodingKeys.self)
            try values.encode(status, forKey: .status)
            try values.encode(fetchedAt, forKey: .fetchedAt)
            try values.encode(limits, forKey: .limits)
        }
    }

    struct Limit: Codable {
        let kind: String
        let percent: Int
        let resetsAt: String?
        let windowMinutes: Int?
        let modelName: String?

        enum CodingKeys: String, CodingKey { case kind, percent, resetsAt, windowMinutes, modelName }
        func encode(to encoder: Encoder) throws {
            var values = encoder.container(keyedBy: CodingKeys.self)
            try values.encode(kind, forKey: .kind)
            try values.encode(percent, forKey: .percent)
            try values.encode(resetsAt, forKey: .resetsAt)
            try values.encode(windowMinutes, forKey: .windowMinutes)
            try values.encode(modelName, forKey: .modelName)
        }
    }

    static func payload(from state: AppState, at date: Date = Date()) -> Payload {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        func provider(status: String, snapshot: UsageSnapshot?, fetchedAt: Date?) -> Provider {
            let limits = (snapshot?.limits ?? []).map { limit in
                let minutes: Int?
                switch limit.kind {
                case "session", "codex_session": minutes = 300
                case "weekly_all", "weekly_scoped", "codex_weekly": minutes = 10080
                default: minutes = nil
                }
                return Limit(kind: limit.kind, percent: limit.percent,
                             resetsAt: limit.resetsAt.map { formatter.string(from: $0) },
                             windowMinutes: minutes, modelName: limit.modelName)
            }
            return Provider(status: status, fetchedAt: fetchedAt.map { formatter.string(from: $0) }, limits: limits)
        }
        let claudeStatus = state.loginRequired ? "loginRequired" :
            state.snapshot != nil ? "ok" : state.errorText != nil ? "error" : "loading"
        let codexStatus = !state.isCodexAvailable ? "unavailable" :
            state.codexSnapshot != nil ? "ok" : state.codexErrorText != nil ? "error" : "loading"
        return Payload(version: 1, updatedAt: formatter.string(from: date),
                       claude: provider(status: claudeStatus, snapshot: state.loginRequired ? nil : state.snapshot,
                                        fetchedAt: state.claudeFetchedAt),
                       codex: provider(status: codexStatus, snapshot: state.isCodexAvailable ? state.codexSnapshot : nil,
                                       fetchedAt: state.codexFetchedAt))
    }

    static func isAvailable(directory: URL = defaultDirectory) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    static func write(state: AppState, directory: URL = defaultDirectory) {
        guard isAvailable(directory: directory),
              let data = try? JSONEncoder().encode(payload(from: state)) else { return }
        try? data.write(to: directory.appendingPathComponent("Zanki.usage.json"), options: .atomic)
    }

    static func remove(directory: URL = defaultDirectory) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("Zanki.usage.json"))
    }
}
