import Foundation

final class RemoteExport {
    struct Configuration {
        let url: URL
        let headers: [String: String]
    }

    static var defaultConfigurationURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
            "Library/Application Support/Zanki/remote-export.json")
    }

    private let configurationURL: URL
    private let session: URLSession
    @MainActor private var isSending = false

    init(configurationURL: URL = RemoteExport.defaultConfigurationURL, session: URLSession = .shared) {
        self.configurationURL = configurationURL
        self.session = session
    }

    static func loadConfiguration(at file: URL) -> Configuration? {
        guard let data = try? Data(contentsOf: file),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let value = json["url"] as? String,
              let url = URL(string: value),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else { return nil }
        let headers = (json["headers"] as? [String: Any] ?? [:]).compactMapValues { $0 as? String }
        return Configuration(url: url, headers: headers)
    }

    static func makeRequest(configuration: Configuration, payload: ScriptableExport.Payload) throws -> URLRequest {
        var request = URLRequest(url: configuration.url, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (name, value) in configuration.headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.httpBody = try JSONEncoder().encode(["payload": payload])
        return request
    }

    @MainActor func send(state: AppState) async {
        guard !isSending,
              let configuration = Self.loadConfiguration(at: configurationURL),
              let request = try? Self.makeRequest(configuration: configuration,
                                                  payload: ScriptableExport.payload(from: state)) else { return }
        isSending = true
        defer { isSending = false }
        _ = try? await session.data(for: request)
    }
}
