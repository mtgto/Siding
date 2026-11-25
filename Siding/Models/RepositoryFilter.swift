import Foundation

/// 対象とする Org/ユーザー と リポジトリ。どちらも空なら全リポジトリが対象。
/// UserDefaults の `WatchedOwners` / `WatchedRepos` (文字列配列) から読む。
nonisolated struct RepositoryFilter: Equatable, Sendable {
    static let ownersKey = "WatchedOwners"
    static let reposKey = "WatchedRepos"
    /// GitHub search のクエリ長の上限
    static let maxQueryLength = 256

    var owners: [String]
    var repos: [String]

    init(owners: [String] = [], repos: [String] = []) {
        self.owners = owners.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
        self.repos = repos.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
    }

    init(defaults: UserDefaults) {
        self.init(
            owners: defaults.stringArray(forKey: Self.ownersKey) ?? [],
            repos: defaults.stringArray(forKey: Self.reposKey) ?? []
        )
    }

    var isEmpty: Bool { owners.isEmpty && repos.isEmpty }

    /// `owner/name` が対象かどうか
    func matches(_ nameWithOwner: String) -> Bool {
        if isEmpty { return true }
        let name = nameWithOwner.lowercased()
        if repos.contains(name) { return true }
        guard let owner = name.split(separator: "/").first else { return false }
        return owners.contains(String(owner))
    }

    /// search クエリに修飾子を足す。長さ制限を超える場合は修飾子なし
    /// (その場合もクライアント側で `matches` により絞り込む)。
    func searchQuery(base: String) -> String {
        if isEmpty { return base }
        let qualifiers = owners.map { "user:\($0)" } + repos.map { "repo:\($0)" }
        let query = ([base] + qualifiers).joined(separator: " ")
        return query.count <= Self.maxQueryLength ? query : base
    }
}
