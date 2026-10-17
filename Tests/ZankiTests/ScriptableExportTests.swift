import Foundation
import Testing
@testable import Zanki

@Suite struct ScriptableExportTests {
    private let date = Date(timeIntervalSince1970: 1_792_206_765.75)
    private let limit = RateLimit(kind: "session", percent: 16, resetsAt: nil, modelName: nil)

    @Test(arguments: ["loginRequired", "error", "loading", "ok"])
    func Claudeの状態と優先順位(status: String) {
        let state = AppState()
        state.loginRequired = status == "loginRequired"
        state.errorText = status == "loading" ? nil : "--%"
        state.snapshot = ["loginRequired", "ok"].contains(status) ? UsageSnapshot(limits: [limit]) : nil
        let provider = ScriptableExport.payload(from: state, at: date).claude
        #expect(provider.status == status)
        #expect(provider.limits.count == (status == "ok" ? 1 : 0))
    }

    @Test(arguments: ["unavailable", "error", "loading", "ok"])
    func Codexの状態と優先順位(status: String) {
        let state = AppState()
        state.isCodexAvailable = status != "unavailable"
        state.codexErrorText = status == "loading" ? nil : "--%"
        state.codexSnapshot = ["unavailable", "ok"].contains(status) ? UsageSnapshot(limits: [limit]) : nil
        let provider = ScriptableExport.payload(from: state, at: date).codex
        #expect(provider.status == status)
        #expect(provider.limits.count == (status == "ok" ? 1 : 0))
    }

    @Test func 全枠を同じ順で出し期間を対応づける() {
        let state = AppState()
        let kinds = ["weekly_scoped", "session", "weekly_all", "codex_session", "codex_weekly", "future"]
        let limits = kinds.enumerated().map {
            RateLimit(kind: $1, percent: $0 * 25, resetsAt: date, modelName: "Model\($0)")
        }
        state.snapshot = UsageSnapshot(limits: limits)
        state.codexSnapshot = state.snapshot
        state.isCodexAvailable = true
        let payload = ScriptableExport.payload(from: state, at: date)
        for provider in [payload.claude, payload.codex] {
            #expect(provider.limits.map(\.kind) == kinds)
            #expect(provider.limits.map(\.percent) == limits.map(\.percent))
            #expect(provider.limits.map(\.modelName) == limits.map(\.modelName))
            #expect(provider.limits.map(\.windowMinutes) == [10080, 300, 10080, 300, 10080, nil])
        }
    }

    @Test func 日付は秒までのUTCで欠損値はnull() throws {
        let state = AppState()
        state.snapshot = UsageSnapshot(limits: [limit,
            RateLimit(kind: "future", percent: 120, resetsAt: date, modelName: "Model")])
        state.claudeFetchedAt = date.addingTimeInterval(-10)
        let data = try JSONEncoder().encode(ScriptableExport.payload(from: state, at: date))
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(root["version"] as? Int == 1)
        let formatter = ISO8601DateFormatter()
        #expect(root["updatedAt"] as? String == formatter.string(from: date))
        #expect((root["updatedAt"] as? String)?.contains(".") == false)
        #expect((root["updatedAt"] as? String)?.hasSuffix("Z") == true)
        let claude = try #require(root["claude"] as? [String: Any])
        let codex = try #require(root["codex"] as? [String: Any])
        #expect(claude["fetchedAt"] as? String == formatter.string(from: date.addingTimeInterval(-10)))
        #expect(codex["fetchedAt"] is NSNull)
        let limits = try #require(claude["limits"] as? [[String: Any]])
        #expect(limits[0]["resetsAt"] is NSNull)
        #expect(limits[0]["modelName"] is NSNull)
        #expect(limits[1]["windowMinutes"] is NSNull)
        #expect(limits[1]["resetsAt"] as? String == formatter.string(from: date))
        #expect(limits[1]["modelName"] as? String == "Model")
        _ = try JSONDecoder().decode(ScriptableExport.Payload.self, from: data)
    }

    @Test func フォルダが無ければ作らず通常ファイルも出力先にしない() throws {
        try withTemporaryDirectory { directory in
            let missing = directory.appendingPathComponent("missing")
            #expect(!ScriptableExport.isAvailable(directory: missing))
            ScriptableExport.write(state: AppState(), directory: missing)
            #expect(!FileManager.default.fileExists(atPath: missing.path))
            let file = directory.appendingPathComponent("file")
            try Data().write(to: file)
            #expect(!ScriptableExport.isAvailable(directory: file))
            ScriptableExport.write(state: AppState(), directory: file)
        }
    }

    @Test func 書き出しを上書きして削除でき失敗は伝播しない() throws {
        try withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("Zanki.usage.json")
            let state = AppState()
            ScriptableExport.remove(directory: directory)
            ScriptableExport.write(state: state, directory: directory)
            state.snapshot = UsageSnapshot(limits: [limit])
            ScriptableExport.write(state: state, directory: directory)
            let payload = try JSONDecoder().decode(ScriptableExport.Payload.self, from: Data(contentsOf: file))
            #expect(payload.claude.status == "ok")
            #expect(payload.claude.limits.first?.percent == 16)
            ScriptableExport.remove(directory: directory)
            #expect(!FileManager.default.fileExists(atPath: file.path))
            try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
            ScriptableExport.write(state: state, directory: directory)
            #expect(try FileManager.default.contentsOfDirectory(atPath: file.path).isEmpty)
        }
    }

    private func withTemporaryDirectory(_ operation: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        try operation(directory)
    }
}
