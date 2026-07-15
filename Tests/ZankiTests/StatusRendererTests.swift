import AppKit
import Testing
@testable import Zanki

private func limit(_ kind: String, _ percent: Int, model: String? = nil) -> RateLimit {
    RateLimit(kind: kind, percent: percent, resetsAt: nil, modelName: model)
}

private let darkOrange = Theme(appearance: .dark, accent: .orange)

@Suite struct StatusRendererTests {
    @Test func 通常時は枠ごとのセグメント() {
        let snap = UsageSnapshot(limits: [
            limit("session", 16), limit("weekly_all", 72), limit("weekly_scoped", 93, model: "Fable"),
        ])
        let segs = StatusRenderer.segments(for: snap, errorText: nil, theme: darkOrange)
        #expect(segs.map(\.label) == ["5h", "週", "F"])
        #expect(segs.map(\.value) == ["16%", "72%", "93%"])
        #expect(segs.map(\.percent) == [16, 72, 93])
        // 文字色は使用率によらず前景色のまま。変わるのはドーナツだけ（60%+黄・80%+赤）
        #expect(segs.allSatisfy { $0.textColor == Brand.light })
        #expect(segs[0].donutColor == Brand.orange)
        #expect(segs[1].donutColor == Brand.yellow)
        #expect(segs[2].donutColor == Brand.danger)
    }

    @Test func ホワイトアクセントは通常時ドーナツが前景色() {
        let snap = UsageSnapshot(limits: [limit("session", 16)])
        let darkWhite = StatusRenderer.segments(
            for: snap, errorText: nil, theme: Theme(appearance: .dark, accent: .white))
        #expect(darkWhite[0].donutColor == Brand.light)
        let lightWhite = StatusRenderer.segments(
            for: snap, errorText: nil, theme: Theme(appearance: .light, accent: .white))
        #expect(lightWhite[0].donutColor == Brand.dark)
        #expect(lightWhite[0].textColor == Brand.dark)
    }

    @Test func 要ログインは赤テキストのみ() {
        let segs = StatusRenderer.segments(for: nil, errorText: "要ログイン", theme: darkOrange)
        #expect(segs.count == 1)
        #expect(segs[0].percent == nil)
        #expect(segs[0].label == "")
        #expect(segs[0].value == "要ログイン")
        #expect(segs[0].textColor == Brand.danger)
    }

    @Test func 値なしはダッシュを薄色で() {
        for segs in [
            StatusRenderer.segments(for: nil, errorText: nil, theme: darkOrange),
            StatusRenderer.segments(for: nil, errorText: "--%", theme: darkOrange),
            StatusRenderer.segments(for: UsageSnapshot(limits: []), errorText: nil, theme: darkOrange),
        ] {
            #expect(segs.map(\.value) == ["--%"])
            #expect(segs[0].percent == nil)
            #expect(segs[0].textColor != Brand.danger)
        }
    }

    @Test func 画像は内容に応じた正のサイズ() {
        let snap = UsageSnapshot(limits: [limit("session", 16)])
        for theme in [darkOrange, Theme(appearance: .light, accent: .white)] {
            let image = StatusRenderer.image(for: snap, errorText: nil, theme: theme)
            #expect(image.size.height == StatusRenderer.capsuleHeight)
            #expect(image.size.width > StatusRenderer.capsuleHeight)
        }
    }
}
