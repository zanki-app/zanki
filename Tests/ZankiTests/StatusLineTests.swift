import AppKit
import Testing
@testable import Zanki

private func limit(_ kind: String, _ percent: Int, model: String? = nil) -> RateLimit {
    RateLimit(kind: kind, percent: percent, resetsAt: nil, modelName: model)
}

@Suite struct StatusLineTests {
    @Test func ラベル() {
        #expect(StatusLine.label(for: limit("session", 0)) == "5h")
        #expect(StatusLine.label(for: limit("weekly_all", 0)) == "週")
        #expect(StatusLine.label(for: limit("weekly_scoped", 0, model: "Fable")) == "F")
        #expect(StatusLine.label(for: limit("weekly_scoped", 0, model: "Opus")) == "O")
        #expect(StatusLine.label(for: limit("monthly", 0)) == "mon")
    }

    @Test func リセット残時間の文言() {
        let now = Date(timeIntervalSince1970: 0)
        #expect(StatusLine.resetText(until: now.addingTimeInterval(60 * 30), now: now) == "30分")
        #expect(StatusLine.resetText(until: now.addingTimeInterval(3600 * 3 + 60 * 12), now: now) == "3時間12分")
        #expect(StatusLine.resetText(until: now.addingTimeInterval(86400 * 2 + 3600 * 5), now: now) == "2日5時間")
        #expect(StatusLine.resetText(until: now.addingTimeInterval(-10), now: now) == "0分")
        #expect(StatusLine.resetText(until: nil, now: now) == "")
    }
}
