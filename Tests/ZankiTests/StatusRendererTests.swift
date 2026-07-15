import AppKit
import Testing
@testable import Zanki

private func limit(_ kind: String, _ percent: Int, model: String? = nil) -> RateLimit {
    RateLimit(kind: kind, percent: percent, resetsAt: nil, modelName: model)
}

@Suite struct StatusRendererTests {
    @Test func 通常時は枠ごとのセグメント() {
        let snap = UsageSnapshot(limits: [
            limit("session", 16), limit("weekly_all", 72), limit("weekly_scoped", 93, model: "Fable"),
        ])
        let segs = StatusRenderer.segments(for: snap, errorText: nil)
        #expect(segs.map(\.label) == ["5h", "週", "F"])
        #expect(segs.map(\.value) == ["16%", "72%", "93%"])
        #expect(segs.map(\.percent) == [16, 72, 93])
        // 案A: 通常はアイボリー文字＋オレンジドーナツ / 60%+で文字もオレンジ / 80%+で両方赤
        #expect(segs[0].textColor == Brand.light)
        #expect(segs[0].donutColor == Brand.orange)
        #expect(segs[1].textColor == Brand.orange)
        #expect(segs[1].donutColor == Brand.orange)
        #expect(segs[2].textColor == Brand.danger)
        #expect(segs[2].donutColor == Brand.danger)
    }

    @Test func 要ログインは赤テキストのみ() {
        let segs = StatusRenderer.segments(for: nil, errorText: "要ログイン")
        #expect(segs.count == 1)
        #expect(segs[0].percent == nil)
        #expect(segs[0].label == "")
        #expect(segs[0].value == "要ログイン")
        #expect(segs[0].textColor == Brand.danger)
    }

    @Test func 値なしはダッシュを薄色で() {
        for segs in [
            StatusRenderer.segments(for: nil, errorText: nil),
            StatusRenderer.segments(for: nil, errorText: "--%"),
            StatusRenderer.segments(for: UsageSnapshot(limits: []), errorText: nil),
        ] {
            #expect(segs.map(\.value) == ["--%"])
            #expect(segs[0].percent == nil)
            #expect(segs[0].textColor != Brand.danger)
        }
    }

    @Test func 画像は内容に応じた正のサイズ() {
        let snap = UsageSnapshot(limits: [limit("session", 16)])
        let image = StatusRenderer.image(for: snap, errorText: nil)
        #expect(image.size.height == StatusRenderer.capsuleHeight)
        #expect(image.size.width > StatusRenderer.capsuleHeight)
    }
}
