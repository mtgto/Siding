import Foundation
import os

/// GraphQL search で PR 一覧を取得する。ライブラリは使わず URLSession + Codable。
nonisolated struct GitHubClient: Sendable {
    let token: String

    static let myPullRequestsQuery = "is:pr is:open author:@me sort:updated-desc"
    static let reviewRequestedQuery = "is:pr is:open review-requested:@me sort:updated-desc"

    private static let searchDocument = """
    query($q: String!) {
      search(query: $q, type: ISSUE, first: 100) {
        nodes {
          ... on PullRequest {
            id
            number
            title
            url
            updatedAt
            isDraft
            repository { nameWithOwner fullDatabaseId }
            author { login }
            totalCommentsCount
            reviewDecision
          }
        }
      }
    }
    """

    func searchPullRequests(query: String) async throws -> (pullRequests: [PullRequest], rateLimit: RateLimit?) {
        var request = GitHubAPI.request(url: GitHubAPI.graphQLURL, token: token, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(GraphQLRequest(query: Self.searchDocument, variables: ["q": query]))

        let (data, response) = try await GitHubAPI.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GitHubError.invalidResponse }
        Log.network.info("POST graphql search status=\(http.statusCode, privacy: .public) query=\(query, privacy: .public) rateLimitRemaining=\(http.value(forHTTPHeaderField: "X-RateLimit-Remaining") ?? "-", privacy: .public)")
        switch http.statusCode {
        case 200: break
        case 401: throw GitHubError.unauthorized
        default: throw GitHubError.http(status: http.statusCode)
        }
        return (try await Self.decodeSearch(data), RateLimit(response: http))
    }

    @concurrent
    static func decodeSearch(_ data: Data) async throws -> [PullRequest] {
        try parseSearch(data)
    }

    static func parseSearch(_ data: Data) throws -> [PullRequest] {
        let response = try GitHubAPI.decoder().decode(SearchResponse.self, from: data)
        if let errors = response.errors, !errors.isEmpty {
            throw GitHubError.graphQL(messages: errors.map(\.message))
        }
        guard let nodes = response.data?.search.nodes else { throw GitHubError.invalidResponse }
        return nodes.compactMap { node -> PullRequest? in
            guard let node, let id = node.id, let number = node.number, let title = node.title,
                  let url = node.url, let updatedAt = node.updatedAt,
                  let repository = node.repository?.nameWithOwner,
                  let repositoryID = node.repository?.fullDatabaseId.flatMap(Int.init) else { return nil }
            return PullRequest(
                id: id, number: number, title: title, url: url, updatedAt: updatedAt,
                isDraft: node.isDraft ?? false, repository: repository, repositoryID: repositoryID,
                authorLogin: node.author?.login, commentCount: node.totalCommentsCount ?? 0,
                reviewDecision: node.reviewDecision.flatMap(ReviewDecision.init(rawValue:))
            )
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }
}

private nonisolated struct GraphQLRequest: Encodable, Sendable {
    let query: String
    let variables: [String: String]
}

private nonisolated struct SearchResponse: Decodable, Sendable {
    struct DataField: Decodable, Sendable { let search: Search }
    struct Search: Decodable, Sendable { let nodes: [Node?] }
    struct Node: Decodable, Sendable {
        struct Repository: Decodable, Sendable {
            let nameWithOwner: String
            /// BigInt は JSON では文字列で返る。REST の `repository.id` と同じ値。
            let fullDatabaseId: String?
        }
        struct Author: Decodable, Sendable { let login: String }
        let id: String?
        let number: Int?
        let title: String?
        let url: URL?
        let updatedAt: Date?
        let isDraft: Bool?
        let repository: Repository?
        let author: Author?
        let totalCommentsCount: Int?
        /// 未知の値が増えてもデコードが失敗しないよう文字列で受ける
        let reviewDecision: String?
    }
    struct GraphQLErrorItem: Decodable, Sendable { let message: String }

    let data: DataField?
    let errors: [GraphQLErrorItem]?
}
