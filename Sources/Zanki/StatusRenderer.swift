import AppKit

/// メニューバー表示全体（角丸カプセル＋ドーナツ＋数値）を1枚のNSImageとして描画する
enum StatusRenderer {
    struct Segment {
        /// nil ならテキストのみ（エラー表示・ドーナツなし）
        let percent: Int?
        /// 枠名（"5h" 等）。小さいフォントで描く。エラー表示では空
        let label: String
        /// パーセント値（"16%" 等）またはエラーテキスト
        let value: String
        let textColor: NSColor
        let donutColor: NSColor
    }

    static let capsuleHeight: CGFloat = 20
    static let cornerRadius: CGFloat = 5
    static let capsuleAlpha: CGFloat = 0.62
    static let donutDiameter: CGFloat = 13
    static let donutLineWidth: CGFloat = 2.5
    static let horizontalPadding: CGFloat = 9
    static let segmentGap: CGFloat = 11
    static let donutTextGap: CGFloat = 4
    static let labelValueGap: CGFloat = 3
    static let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    /// 枠名はパーセントより目立たないよう小さく描く
    static let labelFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)

    /// 数値の色（案A: 通常はアイボリー・60%以上オレンジ・80%以上赤）
    static func textColor(forPercent percent: Int) -> NSColor {
        if percent >= StatusLine.dangerPercent { return Brand.danger }
        if percent >= StatusLine.warningPercent { return Brand.orange }
        return Brand.light
    }

    /// ドーナツの色（案A: 常時オレンジ・80%以上のみ赤）
    static func donutColor(forPercent percent: Int) -> NSColor {
        percent >= StatusLine.dangerPercent ? Brand.danger : Brand.orange
    }

    /// 表示内容をセグメント列へ変換する（テスト対象の純粋ロジック）
    static func segments(for snapshot: UsageSnapshot?, errorText: String?) -> [Segment] {
        if let errorText, snapshot == nil {
            let color: NSColor = errorText == "--%" ? Brand.light.withAlphaComponent(0.6) : Brand.danger
            return [Segment(percent: nil, label: "", value: errorText, textColor: color, donutColor: color)]
        }
        guard let snapshot, !snapshot.limits.isEmpty else {
            let dim = Brand.light.withAlphaComponent(0.6)
            return [Segment(percent: nil, label: "", value: "--%", textColor: dim, donutColor: dim)]
        }
        return snapshot.limits.map { limit in
            Segment(percent: limit.percent,
                    label: StatusLine.label(for: limit),
                    value: "\(limit.percent)%",
                    textColor: textColor(forPercent: limit.percent),
                    donutColor: donutColor(forPercent: limit.percent))
        }
    }

    static func image(for snapshot: UsageSnapshot?, errorText: String?) -> NSImage {
        let segments = segments(for: snapshot, errorText: errorText)
        let labelWidths = segments.map { $0.label.isEmpty ? 0 : width(of: $0.label, font: labelFont) + labelValueGap }
        let valueWidths = segments.map { width(of: $0.value, font: font) }
        var contentWidth: CGFloat = 0
        for (index, segment) in segments.enumerated() {
            if index > 0 { contentWidth += segmentGap }
            if segment.percent != nil { contentWidth += donutDiameter + donutTextGap }
            contentWidth += labelWidths[index] + valueWidths[index]
        }
        let size = NSSize(width: contentWidth + horizontalPadding * 2, height: capsuleHeight)
        let image = NSImage(size: size, flipped: false) { rect in
            let capsule = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            Brand.dark.withAlphaComponent(capsuleAlpha).setFill()
            capsule.fill()

            var x = horizontalPadding
            for (index, segment) in segments.enumerated() {
                if let percent = segment.percent {
                    drawDonut(percent: percent, color: segment.donutColor,
                              at: NSPoint(x: x, y: (rect.height - donutDiameter) / 2))
                    x += donutDiameter + donutTextGap
                }
                let value = NSAttributedString(string: segment.value, attributes: [
                    .font: font, .foregroundColor: segment.textColor,
                ])
                // 値を上下中央に置き、ラベルはそのベースラインに揃えて小さく描く
                let valueY = (rect.height - value.size().height) / 2
                let baseline = valueY - font.descender
                if !segment.label.isEmpty {
                    let label = NSAttributedString(string: segment.label, attributes: [
                        .font: labelFont, .foregroundColor: segment.textColor,
                    ])
                    label.draw(at: NSPoint(x: x, y: baseline + labelFont.descender))
                    x += labelWidths[index]
                }
                value.draw(at: NSPoint(x: x, y: valueY))
                x += valueWidths[index]
                if index < segments.count - 1 { x += segmentGap }
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func width(of text: String, font: NSFont) -> CGFloat {
        NSAttributedString(string: text, attributes: [.font: font]).size().width.rounded(.up)
    }

    /// 12時位置から時計回りに percent 分の円弧を描く
    private static func drawDonut(percent: Int, color: NSColor, at origin: NSPoint) {
        let rect = NSRect(x: origin.x + donutLineWidth / 2, y: origin.y + donutLineWidth / 2,
                          width: donutDiameter - donutLineWidth, height: donutDiameter - donutLineWidth)
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2

        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = donutLineWidth
        Brand.light.withAlphaComponent(0.22).setStroke()
        track.stroke()

        let fraction = min(max(Double(percent), 0), 100) / 100
        guard fraction > 0 else { return }
        let progress = NSBezierPath()
        progress.appendArc(withCenter: center, radius: radius,
                           startAngle: 90, endAngle: 90 - 360 * fraction, clockwise: true)
        progress.lineWidth = donutLineWidth
        progress.lineCapStyle = .round
        color.setStroke()
        progress.stroke()
    }
}
