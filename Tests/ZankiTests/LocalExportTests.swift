import Foundation
import Testing
@testable import Zanki

@Suite struct LocalExportTests {
    @Test func 手元のファイルに本人だけが読める形で書く() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("usage.json")
        let state = AppState()
        state.snapshot = UsageSnapshot(limits: [RateLimit(kind: "session", percent: 42, resetsAt: nil, modelName: nil)])

        LocalExport.write(state: state, to: file)

        let payload = try JSONDecoder().decode(ScriptableExport.Payload.self, from: Data(contentsOf: file))
        #expect(payload.claude.limits.first?.percent == 42)
        let permissions = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int
        #expect(permissions == 0o600)
    }
}
