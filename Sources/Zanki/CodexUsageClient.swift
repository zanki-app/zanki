import Foundation

enum CodexAvailability: Equatable {
    case unavailable
    case snapshot(UsageSnapshot)
}

enum CodexUsageError: Error {
    case launchFailed
    case rpc(String)
    case timeout
    case malformedResponse
}

enum CodexRateLimitsResponse {
    static func decode(from data: Data) throws -> UsageSnapshot {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CodexUsageError.malformedResponse
        }
        let containers: [[String: Any]]
        if let current = root["rateLimits"] as? [String: Any] {
            containers = [current]
        } else if let byID = root["rateLimitsByLimitId"] as? [String: Any] {
            containers = byID.keys.sorted().compactMap { byID[$0] as? [String: Any] }
        } else {
            containers = []
        }

        let windows = containers.flatMap { [$0["primary"], $0["secondary"]] }
        let limits = windows.compactMap { value -> RateLimit? in
            guard let window = value as? [String: Any],
                  let duration = (window["windowDurationMins"] as? NSNumber)?.intValue,
                  let percent = (window["usedPercent"] as? NSNumber)?.intValue,
                  let resetsAt = (window["resetsAt"] as? NSNumber)?.doubleValue else { return nil }
            let kind: String
            switch duration {
            case 300: kind = "codex_session"
            case 10080: kind = "codex_weekly"
            default: return nil
            }
            return RateLimit(kind: kind, percent: percent,
                             resetsAt: Date(timeIntervalSince1970: resetsAt), modelName: nil)
        }
        let session = limits.first { $0.kind == "codex_session" }
        let weekly = limits.first { $0.kind == "codex_weekly" }
        return UsageSnapshot(limits: [session, weekly].compactMap { $0 })
    }
}

actor CodexUsageClient {
    private enum Flow { case daemonAndProxy, stdio }

    private var transport: CodexRPCTransport?
    private var preferredFlow: Flow?

    func fetch() async throws -> CodexAvailability {
        guard let binary = CodexBinaryResolver.resolve() else {
            stopTransport()
            return .unavailable
        }
        do {
            return .snapshot(try requestSnapshot(binary: binary))
        } catch {
            stopTransport()
            return .snapshot(try requestSnapshot(binary: binary))
        }
    }

    func shutdown() {
        stopTransport()
    }

    private func requestSnapshot(binary: String) throws -> UsageSnapshot {
        if transport == nil || transport?.isRunning != true {
            transport = try startTransport(binary: binary)
        }
        guard let transport else { throw CodexUsageError.launchFailed }
        let result = try transport.request(method: "account/rateLimits/read", params: [:], timeout: 8)
        let data = try JSONSerialization.data(withJSONObject: result)
        return try CodexRateLimitsResponse.decode(from: data)
    }

    private func startTransport(binary: String) throws -> CodexRPCTransport {
        var flows = [Flow]()
        if let preferredFlow { flows.append(preferredFlow) }
        for flow in [Flow.daemonAndProxy, .stdio] where !flows.contains(where: { $0 == flow }) {
            flows.append(flow)
        }
        var lastError: Error = CodexUsageError.launchFailed
        for flow in flows {
            var candidate: CodexRPCTransport?
            do {
                if flow == .daemonAndProxy {
                    try CodexProcessRunner.run(binary: binary,
                                               arguments: ["app-server", "daemon", "start"], timeout: 5)
                }
                let arguments = flow == .daemonAndProxy
                    ? ["app-server", "proxy"] : ["app-server"]
                candidate = try CodexRPCTransport(binary: binary, arguments: arguments)
                guard let candidate else { throw CodexUsageError.launchFailed }
                _ = try candidate.request(
                    method: "initialize",
                    params: ["clientInfo": ["name": "zanki", "version": "1.0"], "capabilities": [:]],
                    timeout: 8)
                try candidate.notify(method: "initialized", params: [:])
                preferredFlow = flow
                return candidate
            } catch {
                candidate?.stop()
                lastError = error
            }
        }
        throw lastError
    }

    private func stopTransport() {
        transport?.stop()
        transport = nil
    }
}

private enum CodexBinaryResolver {
    static func resolve() -> String? {
        if let custom = UserDefaults.standard.string(forKey: "zanki.codexPath"), isExecutable(custom) {
            return custom
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var candidates = [
            "/opt/homebrew/bin/codex", "/usr/local/bin/codex", "/usr/bin/codex",
            "\(home)/.volta/bin/codex", "\(home)/.bun/bin/codex", "\(home)/.asdf/shims/codex",
        ]
        candidates += versionedCandidates(root: "\(home)/.nvm/versions/node")
        candidates += versionedCandidates(root: "\(home)/.local/share/fnm/node-versions", suffix: "installation/bin/codex")
        if let found = candidates.first(where: isExecutable) { return found }
        return resolveFromLoginShell()
    }

    private static func versionedCandidates(root: String, suffix: String = "bin/codex") -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root)) ?? []
        return names.sorted(by: numericVersionDescending).map { "\(root)/\($0)/\(suffix)" }
    }

    private static func numericVersionDescending(_ lhs: String, _ rhs: String) -> Bool {
        lhs.compare(rhs, options: .numeric) == .orderedDescending
    }

    private static func isExecutable(_ path: String) -> Bool {
        path.hasPrefix("/") && FileManager.default.isExecutableFile(atPath: path)
    }

    private static func resolveFromLoginShell() -> String? {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        guard let output = try? CodexProcessRunner.capture(
            binary: shell, arguments: ["-ilc", "command -v codex"], timeout: 3) else { return nil }
        return output.split(whereSeparator: \.isNewline).map(String.init).last(where: isExecutable)
    }
}

private enum CodexProcessRunner {
    static func environment(codexBinary: String? = nil) -> [String: String] {
        let allowed = [
            "HOME", "USER", "LOGNAME", "PATH", "LANG", "LC_ALL", "LC_CTYPE", "TMPDIR",
            "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "CODEX_HOME", "SHELL", "TERM",
        ]
        let parent = ProcessInfo.processInfo.environment
        var environment = Dictionary(uniqueKeysWithValues: allowed.compactMap { key in parent[key].map { (key, $0) } })
        if let codexBinary {
            let directory = URL(fileURLWithPath: codexBinary).deletingLastPathComponent().path
            environment["PATH"] = CodexChildEnvironment.path(
                addingCodexDirectory: directory,
                toParentPath: parent["PATH"])
        }
        return environment
    }

    static func run(binary: String, arguments: [String], timeout: TimeInterval) throws {
        let process = Process()
        let output = Pipe()
        let error = Pipe()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = arguments
        process.environment = environment(codexBinary: binary)
        process.standardOutput = output
        process.standardError = error
        output.fileHandleForReading.readabilityHandler = { _ = $0.availableData }
        error.fileHandleForReading.readabilityHandler = { _ = $0.availableData }
        defer {
            output.fileHandleForReading.readabilityHandler = nil
            error.fileHandleForReading.readabilityHandler = nil
        }
        try process.run()
        try waitOrKill(process, timeout: timeout)
        guard process.terminationStatus == 0 else { throw CodexUsageError.launchFailed }
    }

    static func capture(binary: String, arguments: [String], timeout: TimeInterval) throws -> String {
        let process = Process()
        let output = Pipe()
        let error = Pipe()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = arguments
        process.environment = environment()
        process.standardOutput = output
        process.standardError = error
        // stdout も実行中からドレインする（シェル初期化スクリプトの出力がパイプ容量
        // 64KiB を超えると子が write でブロックし、タイムアウト誤判定になるため）
        let collected = CollectedOutput()
        output.fileHandleForReading.readabilityHandler = { collected.append($0.availableData) }
        error.fileHandleForReading.readabilityHandler = { _ = $0.availableData }
        defer {
            output.fileHandleForReading.readabilityHandler = nil
            error.fileHandleForReading.readabilityHandler = nil
        }
        try process.run()
        try waitOrKill(process, timeout: timeout)
        guard process.terminationStatus == 0 else { throw CodexUsageError.launchFailed }
        // ハンドラを解除してからパイプの残りを回収（ハンドラ消費済み分と重複しない）
        output.fileHandleForReading.readabilityHandler = nil
        collected.append(output.fileHandleForReading.readDataToEndOfFile())
        return String(data: collected.data, encoding: .utf8) ?? ""
    }

    /// タイムアウトまで終了を待ち、超過時は terminate → 猶予0.5秒 → SIGKILL で確実に始末する
    private static func waitOrKill(_ process: Process, timeout: TimeInterval) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.02) }
        guard process.isRunning else { return }
        process.terminate()
        let grace = Date().addingTimeInterval(0.5)
        while process.isRunning && Date() < grace { Thread.sleep(forTimeInterval: 0.02) }
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        throw CodexUsageError.timeout
    }

    private final class CollectedOutput: @unchecked Sendable {
        private let lock = NSLock()
        private var buffer = Data()
        var data: Data { lock.withLock { buffer } }
        func append(_ chunk: Data) {
            guard !chunk.isEmpty else { return }
            lock.withLock { buffer.append(chunk) }
        }
    }
}

/// 子プロセスへ渡す PATH の組み立て。
/// codex はインタプリタ経由で起動されるスクリプトのことがあり（`#!/usr/bin/env node` 等）、
/// PATH にインタプリタが無いと絶対パスで起動しても即座に終了する。ログイン項目から
/// 起動された場合の PATH は最小構成でこれに該当するため、解決済み codex と同じ
/// ディレクトリを先頭に加えて取りこぼしを防ぐ。
enum CodexChildEnvironment {
    private static let systemDefaultPath = "/usr/bin:/bin:/usr/sbin:/sbin"

    static func path(addingCodexDirectory directory: String, toParentPath parentPath: String?) -> String {
        let parentEntries = (parentPath ?? systemDefaultPath)
            .split(separator: ":")
            .map(String.init)
            .filter { $0 != directory }
        return ([directory] + parentEntries).joined(separator: ":")
    }
}

private final class CodexRPCTransport: @unchecked Sendable {
    private let lock = NSLock()
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private let error = Pipe()
    private var buffer = Data()
    private var nextID = 1
    private var responses: [Int: Result<[String: Any], Error>] = [:]
    private var waiters: [Int: DispatchSemaphore] = [:]

    var isRunning: Bool { process.isRunning }

    init(binary: String, arguments: [String]) throws {
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = arguments
        process.environment = CodexProcessRunner.environment(codexBinary: binary)
        process.standardInput = input
        process.standardOutput = output
        process.standardError = error
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.receive(handle.availableData)
        }
        error.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
        process.terminationHandler = { [weak self] _ in self?.handleTermination() }
        try process.run()
    }

    func request(method: String, params: [String: Any], timeout: TimeInterval) throws -> [String: Any] {
        let id: Int
        let semaphore = DispatchSemaphore(value: 0)
        lock.lock()
        id = nextID
        nextID += 1
        waiters[id] = semaphore
        lock.unlock()
        try write(["jsonrpc": "2.0", "id": id, "method": method, "params": params])
        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            lock.withLock { waiters.removeValue(forKey: id); responses.removeValue(forKey: id) }
            throw CodexUsageError.timeout
        }
        let response = lock.withLock { responses.removeValue(forKey: id) }
        return try response?.get() ?? { throw CodexUsageError.malformedResponse }()
    }

    func notify(method: String, params: [String: Any]) throws {
        try write(["jsonrpc": "2.0", "method": method, "params": params])
    }

    func stop() {
        process.terminationHandler = nil
        output.fileHandleForReading.readabilityHandler = nil
        error.fileHandleForReading.readabilityHandler = nil
        if process.isRunning { process.terminate() }
        try? input.fileHandleForWriting.close()
        try? output.fileHandleForReading.close()
        try? error.fileHandleForReading.close()
        failAll()
    }

    private func write(_ object: [String: Any]) throws {
        var data = try JSONSerialization.data(withJSONObject: object)
        data.append(0x0A)
        try input.fileHandleForWriting.write(contentsOf: data)
    }

    private func receive(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[..<newline]
            buffer.removeSubrange(...newline)
            guard let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let id = (message["id"] as? NSNumber)?.intValue,
                  let waiter = waiters.removeValue(forKey: id) else { continue }
            if let rpcError = message["error"] as? [String: Any] {
                responses[id] = .failure(CodexUsageError.rpc(rpcError["message"] as? String ?? "RPC error"))
            } else if let result = message["result"] as? [String: Any] {
                responses[id] = .success(result)
            } else {
                responses[id] = .failure(CodexUsageError.malformedResponse)
            }
            waiter.signal()
        }
        lock.unlock()
    }

    private func failAll() {
        lock.lock()
        let active = waiters
        waiters.removeAll()
        for (id, waiter) in active {
            responses[id] = .failure(CodexUsageError.launchFailed)
            waiter.signal()
        }
        lock.unlock()
    }

    private func handleTermination() {
        output.fileHandleForReading.readabilityHandler = nil
        error.fileHandleForReading.readabilityHandler = nil
        try? input.fileHandleForWriting.close()
        try? output.fileHandleForReading.close()
        try? error.fileHandleForReading.close()
        failAll()
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock(); defer { unlock() }
        return body()
    }
}
