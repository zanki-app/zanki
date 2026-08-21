import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private var controller: StatusBarController?
    private var timer: Timer?
    private let codexClient = CodexUsageClient()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = StatusBarController(state: state) { [weak self] in self?.refresh() }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        Task { @MainActor in
            let result: Result<UsageSnapshot, Error> = await capture { try await UsageClient().fetch() }
            applyClaude(result)
            state.lastUpdated = Date()
            controller?.render()
        }
        Task { @MainActor in
            let result: Result<CodexAvailability, Error> = await capture { try await codexClient.fetch() }
            applyCodex(result)
            state.lastUpdated = Date()
            controller?.render()
        }
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
            state.isCodexAvailable = true
            state.codexSnapshot = snapshot
            state.codexErrorText = nil
        case .failure:
            state.isCodexAvailable = true
            state.codexErrorText = state.codexSnapshot == nil ? "--%" : nil
        }
    }
}
