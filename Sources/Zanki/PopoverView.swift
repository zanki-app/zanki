import AppKit
import ServiceManagement
import SwiftUI

struct PopoverView: View {
    let state: AppState
    let onRefresh: () -> Void
    /// 外観・アクセント変更時にメニューバー再描画とポップオーバー外観の更新を頼む
    let onThemeChange: () -> Void
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var theme: Theme { state.theme }
    private var background: Color { Color(nsColor: theme.background) }
    private var foreground: Color { Color(nsColor: theme.foreground) }
    private var subtle: Color { Color(nsColor: theme.subtle) }
    private var accent: Color { Color(nsColor: theme.accentColor) }
    private var onAccent: Color { Color(nsColor: theme.onAccent) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let errorText = state.errorText {
                Text(errorText).foregroundStyle(Color(nsColor: Brand.danger))
            }
            if state.loginRequired {
                Text("ターミナルで claude を実行してログインしてください")
                    .foregroundStyle(subtle)
            }
            if let snapshot = state.snapshot {
                ForEach(snapshot.limits) { limit in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(fullName(for: limit)).font(.headline).foregroundStyle(foreground)
                            Spacer()
                            Text("\(limit.percent)%").monospacedDigit().foregroundStyle(foreground)
                        }
                        ProgressView(value: min(Double(limit.percent) / 100.0, 1.0))
                            .tint(Color(nsColor: theme.donutColor(forPercent: limit.percent)))
                            // 外観切替だけでは入力が変わらず再生成されないため、トラック色が
                            // 旧外観のまま残る。id で外観ごとに作り直して確実に再解決させる
                            .id(state.appearance)
                        Text(StatusLine.resetText(until: limit.resetsAt))
                            .font(.caption).foregroundStyle(subtle)
                    }
                }
            } else if state.errorText == nil {
                Text("取得中…").foregroundStyle(subtle)
            }

            Divider()

            HStack(spacing: 10) {
                Menu {
                    Toggle("ログイン時に起動", isOn: $launchAtLogin)
                    Divider()
                    // onChange だと SwiftUI の再描画後に外観が切り替わり、バーのトラック等
                    // NSAppearance 由来の色が旧外観のまま残るため、Binding の set で
                    // 先に applyTheme（onThemeChange）してから再描画させる
                    Picker("外観", selection: Binding(
                        get: { state.appearance },
                        set: { state.appearance = $0; onThemeChange() }
                    )) {
                        Text("ダーク").tag(Appearance.dark)
                        Text("ライト").tag(Appearance.light)
                    }
                    Picker("アクセント", selection: Binding(
                        get: { state.accent },
                        set: { state.accent = $0; onThemeChange() }
                    )) {
                        Text("オレンジ").tag(Accent.orange)
                        Text("ホワイト").tag(Accent.white)
                    }
                    Divider()
                    Button("Zanki を終了") { NSApp.terminate(nil) }
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(subtle)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
                Spacer()
                if let lastUpdated = state.lastUpdated {
                    Text(lastUpdated, style: .time).font(.caption).foregroundStyle(subtle)
                }
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .offset(y: -1)  // ベースライン配置で下寄りに見えるため光学補正
                        .foregroundStyle(onAccent)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
            }
        }
        .padding(22)
        .frame(width: 272)
        .background(background)
        .environment(\.colorScheme, state.appearance == .dark ? .dark : .light)
    }

    private func fullName(for limit: RateLimit) -> String {
        switch limit.kind {
        case "session": return "5時間"
        case "weekly_all": return "週間（全モデル）"
        default: return limit.modelName ?? limit.kind
        }
    }
}
