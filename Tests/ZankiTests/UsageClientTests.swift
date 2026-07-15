import Foundation
import Testing
@testable import Zanki

final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var body = Data("{}".utf8)

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!, statusCode: Self.statusCode,
            httpVersion: nil, headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private func stubbedClient() -> UsageClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return UsageClient(session: URLSession(configuration: config), tokenProvider: { "sk-test" })
}

@Suite(.serialized) struct UsageClientTests {
    @Test func 成功時はスナップショットを返す() async throws {
        StubURLProtocol.statusCode = 200
        StubURLProtocol.body = Data(#"{"limits":[{"kind":"session","group":"session","percent":50,"resets_at":"2026-07-14T12:00:00Z","scope":null}]}"#.utf8)
        let snap = try await stubbedClient().fetch()
        #expect(snap.limits.count == 1)
        #expect(snap.limits[0].percent == 50)
    }

    @Test func _401は要ログイン() async {
        StubURLProtocol.statusCode = 401
        StubURLProtocol.body = Data("{}".utf8)
        await #expect(throws: UsageError.loginRequired) {
            _ = try await stubbedClient().fetch()
        }
    }

    @Test func その他のHTTPエラー() async {
        StubURLProtocol.statusCode = 500
        StubURLProtocol.body = Data("{}".utf8)
        await #expect(throws: UsageError.http(500)) {
            _ = try await stubbedClient().fetch()
        }
    }

    @Test func トークン取得失敗も要ログイン() async {
        let client = UsageClient(session: .shared, tokenProvider: { throw CredentialError.notFound })
        await #expect(throws: UsageError.loginRequired) {
            _ = try await client.fetch()
        }
    }
}
