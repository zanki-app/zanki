import AppKit
import Testing
@testable import Zanki

@Suite struct ThemeTests {
    @Test func 固定配色はダーク地に前景アイボリー() {
        let theme = Theme()
        #expect(theme.foreground == Brand.light)
        #expect(theme.background == Brand.dark)
        #expect(theme.accentColor == Brand.orange)
        #expect(theme.onAccent == Brand.dark)
    }

    @Test func ドーナツ色は60で黄_80で赤_それ未満はオレンジ() {
        let theme = Theme()
        #expect(theme.donutColor(forPercent: 0) == Brand.orange)
        #expect(theme.donutColor(forPercent: 59) == Brand.orange)
        #expect(theme.donutColor(forPercent: 60) == Brand.yellow)
        #expect(theme.donutColor(forPercent: 79) == Brand.yellow)
        #expect(theme.donutColor(forPercent: 80) == Brand.danger)
        #expect(theme.donutColor(forPercent: 100) == Brand.danger)
    }

    @Test func Codex通常色は青で警告色は共通() {
        let theme = Theme()
        #expect(theme.codexDonutColor(forPercent: 0) == Brand.blue)
        #expect(theme.codexDonutColor(forPercent: 59) == Brand.blue)
        #expect(theme.codexDonutColor(forPercent: 60) == Brand.yellow)
        #expect(theme.codexDonutColor(forPercent: 80) == Brand.danger)
    }
}
