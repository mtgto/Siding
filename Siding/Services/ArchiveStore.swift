import Foundation
import os

/// アーカイブした PR (一覧に表示しない PR) のキーを JSON ファイルに保存する。
/// Jasper と同じく、アーカイブした PR は更新されても一覧に戻さない。
nonisolated enum ArchiveStore {
    /// Application Support/Siding/archived.json (サンドボックスではコンテナ内)
    static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "Siding/archived.json")
    }

    static func load(from url: URL = defaultURL) -> Set<PRKey> {
        guard let data = try? Data(contentsOf: url) else { return [] }
        do {
            return Set(try JSONDecoder().decode([PRKey].self, from: data))
        } catch {
            Log.store.error("failed to decode \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    static func save(_ keys: Set<PRKey>, to url: URL = defaultURL) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let sorted = keys.sorted { ($0.repositoryID, $0.number) < ($1.repositoryID, $1.number) }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(sorted).write(to: url, options: .atomic)
        } catch {
            Log.store.error("failed to save \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
