import Foundation
import Testing
@testable import Zanki

@Suite struct CredentialStoreTests {
    @Test func トークンを取り出せる() throws {
        let json = #"{"claudeAiOauth":{"accessToken":"sk-test-123","expiresAt":1750000000}}"#
        let token = try CredentialStore.parseToken(from: Data((json + "\n").utf8))
        #expect(token == "sk-test-123")
    }

    @Test func 構造が違えばmalformed() {
        #expect(throws: CredentialError.malformed) {
            _ = try CredentialStore.parseToken(from: Data(#"{"foo": 1}"#.utf8))
        }
        #expect(throws: CredentialError.malformed) {
            _ = try CredentialStore.parseToken(from: Data("not json".utf8))
        }
    }
}
