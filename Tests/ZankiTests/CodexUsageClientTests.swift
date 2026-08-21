import Foundation
import Testing
@testable import Zanki

@Suite struct CodexUsageClientTests {
    @Test func camelCaseのトップレベルから5時間と週間を抽出する() throws {
        let data = Data(#"{"rateLimits":{"limitId":"codex","primary":{"usedPercent":25,"windowDurationMins":300,"resetsAt":1760000000},"secondary":{"usedPercent":28,"windowDurationMins":10080,"resetsAt":1760604800},"planType":"pro"}}"#.utf8)
        let snapshot = try CodexRateLimitsResponse.decode(from: data)

        #expect(snapshot.limits.map(\.kind) == ["codex_session", "codex_weekly"])
        #expect(snapshot.limits.map(\.percent) == [25, 28])
        #expect(snapshot.limits.map { $0.resetsAt?.timeIntervalSince1970 } == [1760000000, 1760604800])
    }

    @Test func トップレベルが無ければlimitIdをkey順に走査する() throws {
        let data = Data(#"{"rateLimitsByLimitId":{"z":{"primary":{"usedPercent":91,"windowDurationMins":300,"resetsAt":1760000001}},"a":{"primary":{"usedPercent":12,"windowDurationMins":300,"resetsAt":1760000002},"secondary":{"usedPercent":34,"windowDurationMins":10080,"resetsAt":1760604802}}}}"#.utf8)
        let snapshot = try CodexRateLimitsResponse.decode(from: data)

        #expect(snapshot.limits.map(\.percent) == [12, 34])
    }

    @Test func 使用率かリセット時刻が欠けたウィンドウは捨てる() throws {
        let data = Data(#"{"rateLimits":{"primary":{"windowDurationMins":300,"resetsAt":1760000000},"secondary":{"usedPercent":28,"windowDurationMins":10080}}}"#.utf8)
        let snapshot = try CodexRateLimitsResponse.decode(from: data)

        #expect(snapshot.limits.isEmpty)
    }

    @Test func 対象外のウィンドウ時間は抽出しない() throws {
        let data = Data(#"{"rateLimits":{"primary":{"usedPercent":25,"windowDurationMins":60,"resetsAt":1760000000},"secondary":{"usedPercent":28,"windowDurationMins":43200,"resetsAt":1760604800}}}"#.utf8)
        let snapshot = try CodexRateLimitsResponse.decode(from: data)

        #expect(snapshot.limits.isEmpty)
    }
}
