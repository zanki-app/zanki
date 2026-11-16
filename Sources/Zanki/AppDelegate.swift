import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private var controller: StatusBarController?
    private var timer: Timer?
    private let codexClient = CodexUsageClient()
    private let remoteExport = RemoteExport()
    @MainActor private var gate = RefreshGate()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = StatusBarController(state: state) { [weak self] in self?.refresh() }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    // 表示と手元のファイルは取得が届いた順に更新し、外への送信は両方そろってから1回だけ（RefreshGate）
    func refresh() {
        Task { @MainActor in
            let round = gate.start(fetches: 2)
            Task { @MainActor in
                let result: Result<UsageSnapshot, Error> = await capture { try await UsageClient().fetch() }
                applyClaude(result)
                publishLocally()
                await finishFetch(round: round)
            }
            Task { @MainActor in
                let result: Result<CodexAvailability, Error> = await capture { try await codexClient.fetch() }
                applyCodex(result)
                publishLocally()
                await finishFetch(round: round)
            }
            // 片方が遅い・終わらないときも、更新の周期（60秒）より前に取得済みの状態で1回送る
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: Self.sendDeadlineNanoseconds)
                guard gate.expire(round: round) else { return }
                await remoteExport.send(state: state)
            }
        }
    }

    private static let sendDeadlineNanoseconds: UInt64 = 30 * 1_000_000_000

    @MainActor private func publishLocally() {
        state.lastUpdated = Date()
        controller?.render()
        LocalExport.write(state: state)
        if UserDefaults.standard.bool(forKey: ScriptableExport.preferenceKey) {
            ScriptableExport.write(state: state)
        }
    }

    @MainActor private func finishFetch(round: Int) async {
        guard gate.finish(round: round) else { return }
        await remoteExport.send(state: state)
    }

    func applicationWillTerminate(_ notification: Notification) {
        let stopped = DispatchSemaphore(value: 0)
        Task.detached { [codexClient] in
            await codexClient.shutdown()
            stopped.signal()
        }
        _ = stopped.wait(timeout: .now() + 1)
    }

    private func capture<T>(_ operation: () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await operation()) }
        catch { return .failure(error) }
    }

    @MainActor private func applyClaude(_ result: Result<UsageSnapshot, Error>) {
        switch result {
        case let .success(snapshot):
            state.snapshot = snapshot
            state.claudeFetchedAt = Date()
            state.errorText = nil
            state.loginRequired = false
        case .failure(UsageError.loginRequired):
            state.snapshot = nil
            state.errorText = "要ログイン"
            state.loginRequired = true
        case .failure:
            state.errorText = state.snapshot == nil ? "--%" : nil
        }
    }

    @MainActor private func applyCodex(_ result: Result<CodexAvailability, Error>) {
        switch result {
        case .success(.unavailable):
            state.isCodexAvailable = false
            state.codexSnapshot = nil
            state.codexErrorText = nil
        case let .success(.snapshot(snapshot)):
            state.codexFetchedAt = Date()
            state.isCodexAvailable = true
            state.codexSnapshot = snapshot
            state.codexErrorText = nil
        case .failure:
            state.isCodexAvailable = true
            state.codexErrorText = state.codexSnapshot == nil ? "--%" : nil
        }
    }
}
