import Foundation

/// リポジトリ名 (owner/name) と番号で PR を一意に表すキー。
/// GraphQL と REST で大文字小文字が揺れても一致するよう小文字に正規化する。
nonisolated struct PRKey: Hashable, Sendable, CustomStringConvertible {
    let repository: String
    let number: Int

    init(repository: String, number: Int) {
        self.repository = repository.lowercased()
        self.number = number
    }

    /// `https://api.github.com/repos/{owner}/{repo}/pulls/{number}` 形式の URL から作る。
    init?(apiURL: URL) {
        let parts = apiURL.path.split(separator: "/")
        guard parts.count == 5, parts[0] == "repos", parts[3] == "pulls",
              let number = Int(parts[4]) else { return nil }
        self.init(repository: "\(parts[1])/\(parts[2])", number: number)
    }

    var description: String { "\(repository)#\(number)" }
}

nonisolated struct PullRequest: Identifiable, Hashable, Sendable {
    /// GraphQL の node ID
    let id: String
    let number: Int
    let title: String
    let url: URL
    let updatedAt: Date
    let isDraft: Bool
    /// owner/name
    let repository: String
    let authorLogin: String?

    var key: PRKey { PRKey(repository: repository, number: number) }
}
