import AppKit
import ServiceManagement
import SwiftUI

struct PopoverView: View {
    let state: AppState
    let onRefresh: () -> Void
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var background: Color { Color(nsColor: Brand.dark) }
    private var foreground: Color { Color(nsColor: Brand.light) }
    private var subtle: Color { Color(nsColor: Brand.midGray) }
    private var accent: Color { Color(nsColor: Brand.orange) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let errorText = state.errorText {
                Text(errorText).foregroundStyle(Color(nsColor: Brand.danger))
            }
            if state.loginRequired {
                Button("ターミナルでログイン", action: openTerminalForLogin)
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
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
                            .tint(Color(nsColor: StatusRenderer.donutColor(forPercent: limit.percent)))
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

    /// ターミナルで claude CLI を起動する。アクセストークン失効時はCLIが
    /// リフレッシュトークンで自動更新し、それも無効ならCLIがログイン手順を案内する
    private func openTerminalForLogin() {
        let script = "#!/bin/zsh -il\nclaude\n"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("zanki-login.command")
        guard (try? script.write(to: url, atomically: true, encoding: .utf8)) != nil else { return }
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        NSWorkspace.shared.open(url)
    }

    private func fullName(for limit: RateLimit) -> String {
        switch limit.kind {
        case "session": return "5時間"
        case "weekly_all": return "週間（全モデル）"
        default: return limit.modelName ?? limit.kind
        }
    }
}
