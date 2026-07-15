import AppKit
import Testing
@testable import Zanki

@Suite struct ThemeTests {
    @Test func 外観で前景と背景が入れ替わる() {
        let dark = Theme(appearance: .dark, accent: .orange)
        #expect(dark.foreground == Brand.light)
        #expect(dark.background == Brand.dark)

        let light = Theme(appearance: .light, accent: .orange)
        #expect(light.foreground == Brand.dark)
        #expect(light.background == Brand.light)
    }

    @Test func アクセント色はオレンジまたは前景色() {
        #expect(Theme(appearance: .dark, accent: .orange).accentColor == Brand.orange)
        #expect(Theme(appearance: .light, accent: .orange).accentColor == Brand.orange)
        // 「ホワイト」は前景色扱い（ライト外観では墨色になる）
        #expect(Theme(appearance: .dark, accent: .white).accentColor == Brand.light)
        #expect(Theme(appearance: .light, accent: .white).accentColor == Brand.dark)
    }

    @Test func ドーナツ色は60で黄_80で赤_それ未満はアクセント() {
        for appearance in Appearance.allCases {
            for accent in Accent.allCases {
                let theme = Theme(appearance: appearance, accent: accent)
                #expect(theme.donutColor(forPercent: 0) == theme.accentColor)
                #expect(theme.donutColor(forPercent: 59) == theme.accentColor)
                #expect(theme.donutColor(forPercent: 60) == Brand.yellow)
                #expect(theme.donutColor(forPercent: 79) == Brand.yellow)
                #expect(theme.donutColor(forPercent: 80) == Brand.danger)
                #expect(theme.donutColor(forPercent: 100) == Brand.danger)
            }
        }
    }

    @Test func アクセント色ボタン上のラベル色() {
        // オレンジ地は常に墨色、前景色地は背景色で反転
        #expect(Theme(appearance: .dark, accent: .orange).onAccent == Brand.dark)
        #expect(Theme(appearance: .light, accent: .orange).onAccent == Brand.dark)
        #expect(Theme(appearance: .dark, accent: .white).onAccent == Brand.dark)
        #expect(Theme(appearance: .light, accent: .white).onAccent == Brand.light)
    }
}
