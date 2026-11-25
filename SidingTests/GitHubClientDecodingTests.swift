import Foundation
import Testing
@testable import Siding

struct GitHubClientDecodingTests {
    @Test func parsesSearchResultSortedByUpdatedAtDescending() throws {
        let json = """
        {"data":{"search":{"nodes":[
          {"id":"PR_1","number":1,"title":"Old","url":"https://github.com/o/r/pull/1","updatedAt":"2026-11-01T00:00:00Z","isDraft":false,"repository":{"nameWithOwner":"o/r","fullDatabaseId":"123"},"author":{"login":"alice"}},
          {"id":"PR_2","number":2,"title":"New","url":"https://github.com/o/r/pull/2","updatedAt":"2026-11-20T12:34:56Z","isDraft":true,"repository":{"nameWithOwner":"o/r","fullDatabaseId":"123"},"author":null},
          {}
        ]}}}
        """
        let prs = try GitHubClient.parseSearch(Data(json.utf8))
        #expect(prs.map(\.id) == ["PR_2", "PR_1"])
        #expect(prs[0].isDraft)
        #expect(prs[0].authorLogin == nil)
        #expect(prs[1].authorLogin == "alice")
        #expect(prs[1].key == PRKey(repositoryID: 123, number: 1))
    }

    @Test func throwsGraphQLErrors() {
        let json = #"{"data":null,"errors":[{"message":"Bad credentials"}]}"#
        #expect(throws: GitHubError.self) {
            try GitHubClient.parseSearch(Data(json.utf8))
        }
    }

    @Test func parsesRateLimitHeaders() throws {
        let url = try #require(URL(string: "https://api.github.com/notifications"))
        let response = try #require(HTTPURLResponse(url: url, statusCode: 304, httpVersion: nil, headerFields: [
            "X-RateLimit-Limit": "5000",
            "X-RateLimit-Remaining": "4548",
            "X-RateLimit-Reset": "1800000000",
        ]))
        #expect(RateLimit(response: response) == RateLimit(limit: 5000, remaining: 4548, reset: Date(timeIntervalSince1970: 1_800_000_000)))

        let missing = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: [:]))
        #expect(RateLimit(response: missing) == nil)
    }

    @Test func parsesNextLink() {
        let header = #"<https://api.github.com/notifications?page=2>; rel="next", <https://api.github.com/notifications?page=5>; rel="last""#
        #expect(GitHubAPI.nextLink(from: header) == URL(string: "https://api.github.com/notifications?page=2"))
        #expect(GitHubAPI.nextLink(from: #"<https://api.github.com/notifications?page=1>; rel="prev""#) == nil)
        #expect(GitHubAPI.nextLink(from: nil) == nil)
    }
}

struct RepositoryFilterTests {
    @Test func emptyFilterMatchesEverything() {
        let filter = RepositoryFilter()
        #expect(filter.matches("any/repo"))
        #expect(filter.searchQuery(base: "is:pr") == "is:pr")
    }

    @Test func matchesOwnersOrRepos() {
        let filter = RepositoryFilter(owners: ["MyOrg"], repos: ["someone/Tool"])
        #expect(filter.matches("myorg/app"))
        #expect(filter.matches("Someone/tool"))
        #expect(!filter.matches("someone/other"))
        #expect(filter.searchQuery(base: "is:pr") == "is:pr user:myorg repo:someone/tool")
    }

    @Test func dropsQualifiersWhenQueryTooLong() {
        let repos = (0..<30).map { "owner/repository-\($0)" }
        let filter = RepositoryFilter(repos: repos)
        #expect(filter.searchQuery(base: "is:pr") == "is:pr")
    }
}
