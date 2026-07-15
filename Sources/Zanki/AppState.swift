import Foundation
import Observation

@Observable
final class AppState {
    var snapshot: UsageSnapshot?
    /// nil なら正常。"要ログイン" などの短い状態文言
    var errorText: String?
    var lastUpdated: Date?
    /// 認証切れ（要ログイン）状態。ポップオーバーのログイン導線の表示条件
    var loginRequired = false

    var appearance: Appearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "zanki.appearance") }
    }
    var accent: Accent {
        didSet { UserDefaults.standard.set(accent.rawValue, forKey: "zanki.accent") }
    }
    var theme: Theme { Theme(appearance: appearance, accent: accent) }

    init() {
        let defaults = UserDefaults.standard
        appearance = Appearance(rawValue: defaults.string(forKey: "zanki.appearance") ?? "") ?? .dark
        accent = Accent(rawValue: defaults.string(forKey: "zanki.accent") ?? "") ?? .orange
    }
}
