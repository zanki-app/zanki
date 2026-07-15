import Foundation
import Testing
@testable import Zanki

private func fixture(_ name: String) throws -> Data {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/\(name)")
    return try Data(contentsOf: url)
}

@Suite struct UsageSnapshotTests {
    @Test func 実レスポンスをデコードできる() throws {
        let snap = try UsageSnapshot.decode(from: fixture("usage-real.json"))
        #expect(snap.limits.count == 3)
        #expect(snap.limits[0].kind == "session")
        #expect(snap.limits[0].percent == 16)
        #expect(snap.limits[1].kind == "weekly_all")
        #expect(snap.limits[2].modelName == "Fable")
        #expect(snap.limits.allSatisfy { $0.resetsAt != nil })
    }

    @Test func 配列順を保持し不完全な要素は読み飛ばす() throws {
        let json = """
        {"limits": [
          {"kind": "weekly_scoped", "group": "weekly", "percent": 35,
           "resets_at": "2026-07-18T00:00:00Z",
           "scope": {"model": {"id": null, "display_name": "Fable"}}},
          {"kind": "broken"},
          {"kind": "session", "group": "session", "percent": 16,
           "resets_at": "2026-07-14T17:50:00.097545+00:00", "scope": null}
        ]}
        """.data(using: .utf8)!
        let snap = try UsageSnapshot.decode(from: json)
        #expect(snap.limits.map(\.kind) == ["weekly_scoped", "session"])
        #expect(snap.limits[0].modelName == "Fable")
        #expect(snap.limits[1].modelName == nil)
        #expect(snap.limits[1].resetsAt != nil)
    }

    @Test func limitsが無ければ空() throws {
        let snap = try UsageSnapshot.decode(from: "{}".data(using: .utf8)!)
        #expect(snap.limits.isEmpty)
    }

    @Test func オブジェクトでなければエラー() {
        #expect(throws: UsageDecodeError.self) {
            _ = try UsageSnapshot.decode(from: "[1,2]".data(using: .utf8)!)
        }
    }
}
