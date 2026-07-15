import AppKit

/// メニューバー・ポップオーバー全体の外観
enum Appearance: String, CaseIterable {
    case dark, light
}

/// 通常時（60%未満）のドーナツ/バーの色
enum Accent: String, CaseIterable {
    case orange, white
}

/// 外観×アクセントから決まる配色。描画側は色をここからだけ引く
struct Theme: Equatable {
    let appearance: Appearance
    let accent: Accent

    var foreground: NSColor { appearance == .dark ? Brand.light : Brand.dark }
    var background: NSColor { appearance == .dark ? Brand.dark : Brand.light }
    /// 補助テキスト（リセット残時間・更新時刻など）
    var subtle: NSColor { appearance == .dark ? Brand.midGray : Brand.darkGray }
    /// メニューバーカプセルの地色
    var capsuleFill: NSColor {
        appearance == .dark
            ? Brand.dark.withAlphaComponent(0.62)
            : Brand.light.withAlphaComponent(0.72)
    }
    /// ライト外観はカプセルが地に沈むため薄い縁取りを足す（ダークは不要）
    var capsuleBorder: NSColor? {
        appearance == .light ? Brand.dark.withAlphaComponent(0.14) : nil
    }
    /// ドーナツ/バーの未達部分
    var track: NSColor {
        appearance == .dark
            ? Brand.light.withAlphaComponent(0.22)
            : Brand.dark.withAlphaComponent(0.18)
    }
    /// 通常時のドーナツ/バーの色。「ホワイト」は前景色扱い（ライト外観では墨色）
    var accentColor: NSColor { accent == .orange ? Brand.orange : foreground }
    /// アクセント色ボタン上のラベル色（オレンジ地は墨色・前景色地は背景色で反転）
    var onAccent: NSColor { accent == .orange ? Brand.dark : background }

    /// ドーナツ/バーの色。60%以上は黄・80%以上は赤（文字色は常に前景色のまま変えない）
    func donutColor(forPercent percent: Int) -> NSColor {
        if percent >= StatusLine.dangerPercent { return Brand.danger }
        if percent >= StatusLine.warningPercent { return Brand.yellow }
        return accentColor
    }
}
