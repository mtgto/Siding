import Foundation

/// リポジトリの数値 ID と PR 番号で PR を一意に表すキー。
/// 通知のレスポンスには PR 自体の ID が無いため、リネームやオーナー移管でも変わらない
/// リポジトリの数値 ID (REST の `repository.id` = GraphQL の `fullDatabaseId`) と番号を使う。
nonisolated struct PRKey: Hashable, Sendable, CustomStringConvertible {
    let repositoryID: Int
    let number: Int

    /// `https://api.github.com/repos/{owner}/{repo}/pulls/{number}` 形式の URL から PR 番号を取り出す。
    static func pullRequestNumber(apiURL: URL) -> Int? {
        let parts = apiURL.path.split(separator: "/")
        guard parts.count >= 2, parts[parts.count - 2] == "pulls" else { return nil }
        return Int(parts[parts.count - 1])
    }

    var description: String { "\(repositoryID)#\(number)" }
}

nonisolated struct PullRequest: Identifiable, Hashable, Sendable {
    /// GraphQL の node ID
    let id: String
    let number: Int
    let title: String
    let url: URL
    let updatedAt: Date
    let isDraft: Bool
    /// owner/name (表示と絞り込み用)
    let repository: String
    let repositoryID: Int
    let authorLogin: String?

    var key: PRKey { PRKey(repositoryID: repositoryID, number: number) }
}
