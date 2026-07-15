import Foundation

enum UsageError: Error, Equatable {
    case loginRequired
    case http(Int)
    case network
}

struct UsageClient {
    var session: URLSession = .shared
    /// テスト時に差し替えるためのフック。既定はKeychain読取
    var tokenProvider: () throws -> String = { try CredentialStore.accessToken() }

    init(session: URLSession = .shared, tokenProvider: (() throws -> String)? = nil) {
        self.session = session
        if let tokenProvider { self.tokenProvider = tokenProvider }
    }

    func fetch() async throws -> UsageSnapshot {
        guard let token = try? tokenProvider() else { throw UsageError.loginRequired }
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw UsageError.network
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        switch status {
        case 200: return try UsageSnapshot.decode(from: data)
        case 401: throw UsageError.loginRequired
        default: throw UsageError.http(status)
        }
    }
}
