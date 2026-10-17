import Foundation
import Testing
@testable import Zanki

@Suite struct RemoteExportTests {
    @Test(arguments: ["{", "[]", "{}", #"{"url":42}"#, #"{"url":"file:///tmp/export"}"#,
                      #"{"url":"/endpoint"}"#, #"{"url":"https://"}"#,
                      #"{"url":"https:///endpoint"}"#])
    func 壊れた設定やHTTP以外のURLは無効(json: String) throws {
        try withConfiguration(json) { file in
            #expect(RemoteExport.loadConfiguration(at: file) == nil)
        }
    }

    @Test func 設定が無い場合や通常ファイルでない場合は無効() throws {
        try withConfiguration("{}") { file in
            #expect(RemoteExport.loadConfiguration(at: file.appendingPathComponent("missing")) == nil)
            #expect(RemoteExport.loadConfiguration(at: file.deletingLastPathComponent()) == nil)
        }
    }

    @Test func 文字列のヘッダーだけを読み設定変更も反映する() throws {
        try withConfiguration(#"{"url":"https://example.com/endpoint","headers":{"apikey":"test","number":1,"flag":true,"null":null,"object":{},"array":[]}}"#) { file in
            let config = try #require(RemoteExport.loadConfiguration(at: file))
            #expect(config.url.absoluteString == "https://example.com/endpoint")
            #expect(config.headers == ["apikey": "test"])
            try Data(#"{"url":"http://example.com/updated"}"#.utf8).write(to: file)
            let updated = try #require(RemoteExport.loadConfiguration(at: file))
            #expect(updated.url.absoluteString == "http://example.com/updated")
            #expect(updated.headers.isEmpty)
        }
    }

    @Test func POSTと既定ヘッダーとversion1の本文を組み立てる() throws {
        let state = AppState()
        state.snapshot = UsageSnapshot(limits: [
            RateLimit(kind: "session", percent: 16, resetsAt: nil, modelName: nil)])
        let payload = ScriptableExport.payload(from: state, at: Date(timeIntervalSince1970: 1_792_206_765))
        let url = try #require(URL(string: "https://example.com/endpoint"))
        let config = RemoteExport.Configuration(url: url, headers: ["apikey": "test"])
        let request = try RemoteExport.makeRequest(configuration: config, payload: payload)
        #expect(request.url == url)
        #expect(request.httpMethod == "POST")
        #expect(request.timeoutInterval == 10)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "apikey") == "test")
        let body = try #require(request.httpBody)
        let root = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(Set(root.keys) == ["payload"])
        let actual = try #require(root["payload"] as? NSDictionary)
        let expected = try JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? NSDictionary
        #expect(actual == expected)
        #expect(actual["version"] as? Int == 1)
        let decoded = try JSONDecoder().decode([String: ScriptableExport.Payload].self, from: body)
        #expect(decoded["payload"]?.claude.limits.first?.percent == 16)
    }

    @Test func 設定のContentTypeは大文字小文字によらず優先する() throws {
        let url = try #require(URL(string: "https://example.com/endpoint"))
        let config = RemoteExport.Configuration(url: url, headers: ["content-type": "application/custom+json"])
        let request = try RemoteExport.makeRequest(configuration: config,
                                                   payload: ScriptableExport.payload(from: AppState()))
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/custom+json")
    }

    private func withConfiguration(_ json: String, _ operation: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("remote-export.json")
        try Data(json.utf8).write(to: file)
        try operation(file)
    }
}
