import AppKit

/// 固定配色（ダーク外観×オレンジアクセント・Codexはブルー）。
/// 外観・アクセントの切替機能は2026-08-21に廃止（本人判断・ダーク×オレンジのみ使用のため）。
/// 描画側は色をここからだけ引く
struct Theme: Equatable {
    var foreground: NSColor { Brand.light }
    var background: NSColor { Brand.dark }
    /// 補助テキスト（リセット残時間・更新時刻など）
    var subtle: NSColor { Brand.midGray }
    /// メニューバーカプセルの地色
    var capsuleFill: NSColor { Brand.dark.withAlphaComponent(0.62) }
    /// ドーナツ/バーの未達部分
    var track: NSColor { Brand.light.withAlphaComponent(0.22) }
    /// 通常時のドーナツ/バーの色（Claude側）
    var accentColor: NSColor { Brand.orange }
    /// アクセント色ボタン上のラベル色（オレンジ地は墨色）
    var onAccent: NSColor { Brand.dark }

    /// ドーナツ/バーの色。60%以上は黄・80%以上は赤（文字色は常に前景色のまま変えない）
    func donutColor(forPercent percent: Int) -> NSColor {
        if percent >= StatusLine.dangerPercent { return Brand.danger }
        if percent >= StatusLine.warningPercent { return Brand.yellow }
        return accentColor
    }

    /// Codexは通常時の青を固定し、警告色だけClaudeと共有する
    func codexDonutColor(forPercent percent: Int) -> NSColor {
        if percent >= StatusLine.dangerPercent { return Brand.danger }
        if percent >= StatusLine.warningPercent { return Brand.yellow }
        return Brand.blue
    }
}
