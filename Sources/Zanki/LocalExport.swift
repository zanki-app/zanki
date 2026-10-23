import Foundation

// 同じ Mac のほかの道具が読めるよう、取得のたびに使用率を手元のファイルへ書く（中身は Scriptable 向けと同じ）
enum LocalExport {
    static var defaultFile: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
            "Library/Application Support/Zanki/usage.json")
    }

    static func write(state: AppState, to file: URL = defaultFile) {
        guard let data = try? JSONEncoder().encode(ScriptableExport.payload(from: state)) else { return }
        let manager = FileManager.default
        try? manager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true,
                                     attributes: [.posixPermissions: 0o700])
        guard (try? data.write(to: file, options: .atomic)) != nil else { return }
        try? manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
}
