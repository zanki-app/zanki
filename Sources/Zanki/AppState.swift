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
}
