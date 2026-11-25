import Foundation

nonisolated enum GitHubError: LocalizedError, Sendable {
    case unauthorized
    case http(status: Int)
    case graphQL(messages: [String])
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            "GitHub の認証に失敗しました。設定で PAT (classic, repo / notifications スコープ) を確認してください。"
        case .http(let status):
            "GitHub API がエラーを返しました (HTTP \(status))。"
        case .graphQL(let messages):
            "GitHub GraphQL エラー: \(messages.joined(separator: ", "))"
        case .invalidResponse:
            "GitHub API から不正なレスポンスが返りました。"
        }
    }
}

/// レスポンスヘッダ X-RateLimit-* から読む rate limit の状態。
/// REST (core) と GraphQL は上限が別々。
nonisolated struct RateLimit: Equatable, Sendable {
    let limit: Int
    let remaining: Int
    let reset: Date

    init(limit: Int, remaining: Int, reset: Date) {
        self.limit = limit
        self.remaining = remaining
        self.reset = reset
    }

    init?(response: HTTPURLResponse) {
        guard let limit = response.value(forHTTPHeaderField: "X-RateLimit-Limit").flatMap(Int.init),
              let remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining").flatMap(Int.init),
              let reset = response.value(forHTTPHeaderField: "X-RateLimit-Reset").flatMap(TimeInterval.init)
        else { return nil }
        self.init(limit: limit, remaining: remaining, reset: Date(timeIntervalSince1970: reset))
    }
}

nonisolated enum GitHubAPI {
    static let restBase = URL(string: "https://api.github.com")!
    static let graphQLURL = URL(string: "https://api.github.com/graphql")!

    /// 条件付きリクエストを自前で扱うため URLCache を使わないセッション
    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    static func request(url: URL, token: String, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        return request
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// `Link` ヘッダから rel="next" の URL を取り出す。
    static func nextLink(from header: String?) -> URL? {
        guard let header else { return nil }
        for part in header.split(separator: ",") {
            let sections = part.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            guard sections.count >= 2,
                  sections.dropFirst().contains(where: { $0 == "rel=\"next\"" }),
                  sections[0].hasPrefix("<"), sections[0].hasSuffix(">") else { continue }
            return URL(string: String(sections[0].dropFirst().dropLast()))
        }
        return nil
    }
}
