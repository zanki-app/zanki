import AppKit

/// Claude 系ツールに馴染むカラーパレット
enum Brand {
    /// #141413
    static let dark = NSColor(srgbRed: 0x14 / 255, green: 0x14 / 255, blue: 0x13 / 255, alpha: 1)
    /// #faf9f5
    static let light = NSColor(srgbRed: 0xFA / 255, green: 0xF9 / 255, blue: 0xF5 / 255, alpha: 1)
    /// #e8e6dc
    static let lightGray = NSColor(srgbRed: 0xE8 / 255, green: 0xE6 / 255, blue: 0xDC / 255, alpha: 1)
    /// #b0aea5
    static let midGray = NSColor(srgbRed: 0xB0 / 255, green: 0xAE / 255, blue: 0xA5 / 255, alpha: 1)
    /// #d97757（Claudeオレンジ・プライマリアクセント）
    static let orange = NSColor(srgbRed: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255, alpha: 1)
    /// #c24b3f（オレンジと馴染む深い赤。80%以上の警告用）
    static let danger = NSColor(srgbRed: 0xC2 / 255, green: 0x4B / 255, blue: 0x3F / 255, alpha: 1)
}
