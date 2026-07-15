import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private var controller: StatusBarController?
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = StatusBarController(state: state) { [weak self] in self?.refresh() }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        Task { @MainActor in
            do {
                state.snapshot = try await UsageClient().fetch()
                state.errorText = nil
                state.lastUpdated = Date()
                state.loginRequired = false
            } catch UsageError.loginRequired {
                state.snapshot = nil
                state.errorText = "要ログイン"
                state.loginRequired = true
            } catch {
                // 一時的な失敗: 直前の値は残し、値が無ければ "--%" になる
                state.errorText = state.snapshot == nil ? "--%" : nil
            }
            controller?.render()
        }
    }
}
