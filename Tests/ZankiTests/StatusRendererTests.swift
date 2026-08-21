import AppKit
import Testing
@testable import Zanki

private func limit(_ kind: String, _ percent: Int, model: String? = nil) -> RateLimit {
    RateLimit(kind: kind, percent: percent, resetsAt: nil, modelName: model)
}

private let fixedTheme = Theme()

@Suite struct StatusRendererTests {
    @Test func 通常時は枠ごとのセグメント() {
        let snap = UsageSnapshot(limits: [
            limit("session", 16), limit("weekly_all", 72), limit("weekly_scoped", 93, model: "Fable"),
        ])
        let segs = StatusRenderer.segments(for: snap, errorText: nil, theme: fixedTheme)
        #expect(segs.map(\.label) == ["5h", "週", "F"])
        #expect(segs.map(\.value) == ["16%", "72%", "93%"])
        #expect(segs.map(\.percent) == [16, 72, 93])
        // 文字色は使用率によらず前景色のまま。変わるのはドーナツだけ（60%+黄・80%+赤）
        #expect(segs.allSatisfy { $0.textColor == Brand.light })
        #expect(segs[0].donutColor == Brand.orange)
        #expect(segs[1].donutColor == Brand.yellow)
        #expect(segs[2].donutColor == Brand.danger)
    }

    @Test func 要ログインは赤テキストのみ() {
        let segs = StatusRenderer.segments(for: nil, errorText: "要ログイン", theme: fixedTheme)
        #expect(segs.count == 1)
        #expect(segs[0].percent == nil)
        #expect(segs[0].label == "")
        #expect(segs[0].value == "要ログイン")
        #expect(segs[0].textColor == Brand.danger)
    }

    @Test func 値なしはダッシュを薄色で() {
        for segs in [
            StatusRenderer.segments(for: nil, errorText: nil, theme: fixedTheme),
            StatusRenderer.segments(for: nil, errorText: "--%", theme: fixedTheme),
            StatusRenderer.segments(for: UsageSnapshot(limits: []), errorText: nil, theme: fixedTheme),
        ] {
            #expect(segs.map(\.value) == ["--%"])
            #expect(segs[0].percent == nil)
            #expect(segs[0].textColor != Brand.danger)
        }
    }

    @Test func 画像は内容に応じた正のサイズ() {
        let snap = UsageSnapshot(limits: [limit("session", 16)])
        for theme in [fixedTheme] {
            let image = StatusRenderer.image(for: snap, errorText: nil, theme: theme)
            #expect(image.size.height == StatusRenderer.capsuleHeight)
            #expect(image.size.width > StatusRenderer.capsuleHeight)
        }
    }

    @Test func CodexありはClaudeとの間にセパレータを入れる() {
        let claude = UsageSnapshot(limits: [limit("session", 16), limit("weekly_all", 72)])
        let codex = UsageSnapshot(limits: [limit("codex_session", 25), limit("codex_weekly", 28)])
        let segs = StatusRenderer.segments(
            for: claude, errorText: nil, codexSnapshot: codex,
            codexErrorText: nil, isCodexAvailable: true, theme: fixedTheme)

        #expect(segs.map(\.label) == ["5h", "週", "", "5h", "週"])
        #expect(segs[2].isSeparator)
        #expect(segs[3].donutColor == Brand.blue)
        #expect(segs[4].donutColor == Brand.blue)
    }

    @Test func CodexなしはセパレータもCodex枠も出さない() {
        let claude = UsageSnapshot(limits: [limit("session", 16)])
        let segs = StatusRenderer.segments(
            for: claude, errorText: nil, codexSnapshot: nil,
            codexErrorText: nil, isCodexAvailable: false, theme: fixedTheme)

        #expect(segs.count == 1)
        #expect(!segs.contains { $0.isSeparator })
    }

    @Test func Codex初回取得失敗はセパレータ後にダッシュを出す() {
        let claude = UsageSnapshot(limits: [limit("session", 16)])
        let segs = StatusRenderer.segments(
            for: claude, errorText: nil, codexSnapshot: nil,
            codexErrorText: "--%", isCodexAvailable: true, theme: fixedTheme)

        #expect(segs.map(\.value) == ["16%", "", "--%"])
        #expect(segs[1].isSeparator)
    }
}
