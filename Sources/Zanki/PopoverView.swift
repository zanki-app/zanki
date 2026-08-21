import AppKit
import ServiceManagement
import SwiftUI

struct PopoverView: View {
    let state: AppState
    let onRefresh: () -> Void
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
                    usageRow(limit, color: theme.donutColor(forPercent: limit.percent))
                }
            } else if state.errorText == nil {
                Text("取得中…").foregroundStyle(subtle)
            }

            if state.isCodexAvailable {
                Divider()
                Text("Codex").font(.headline).foregroundStyle(Color(nsColor: Brand.blue))
                if let snapshot = state.codexSnapshot, !snapshot.limits.isEmpty {
                    ForEach(snapshot.limits) { limit in
                        usageRow(limit, color: theme.codexDonutColor(forPercent: limit.percent))
                    }
                } else {
                    Text(state.codexErrorText ?? "取得中…").foregroundStyle(subtle)
                }
            }

            Divider()

            HStack(spacing: 10) {
                Menu {
                    Toggle("ログイン時に起動", isOn: $launchAtLogin)
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
        .environment(\.colorScheme, .dark)
    }

    private func fullName(for limit: RateLimit) -> String {
        switch limit.kind {
        case "session": return "5時間"
        case "weekly_all": return "週間（全モデル）"
        case "codex_session": return "5時間"
        case "codex_weekly": return "週間"
        default: return limit.modelName ?? limit.kind
        }
    }

    private func usageRow(_ limit: RateLimit, color: NSColor) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(fullName(for: limit)).font(.headline).foregroundStyle(foreground)
                Spacer()
                Text("\(limit.percent)%").monospacedDigit().foregroundStyle(foreground)
            }
            ProgressView(value: min(Double(limit.percent) / 100.0, 1.0))
                .tint(Color(nsColor: color))
            Text(StatusLine.resetText(until: limit.resetsAt))
                .font(.caption).foregroundStyle(subtle)
        }
    }
}
