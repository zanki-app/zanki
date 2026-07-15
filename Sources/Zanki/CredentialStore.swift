import Foundation

enum CredentialError: Error, Equatable {
    case notFound
    case malformed
}

enum CredentialStore {
    /// Keychain の "Claude Code-credentials" から accessToken を読む。
    /// トークンはメモリ内でのみ扱い、ログ・ディスクに出さないこと。
    static func accessToken() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CredentialError.notFound }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return try parseToken(from: data)
    }

    static func parseToken(from data: Data) throws -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data),
              let dict = root as? [String: Any],
              let oauth = dict["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else {
            throw CredentialError.malformed
        }
        return token
    }
}
