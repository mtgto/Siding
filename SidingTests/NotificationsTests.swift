import Foundation
import Testing
@testable import Siding

struct NotificationsTests {
    @Test func pullRequestNumberFromAPIURL() {
        #expect(PRKey.pullRequestNumber(apiURL: URL(string: "https://api.github.com/repos/Owner/Repo/pulls/42")!) == 42)
        #expect(PRKey.pullRequestNumber(apiURL: URL(string: "https://api.github.com/repos/o/r/issues/42")!) == nil)
        #expect(PRKey.pullRequestNumber(apiURL: URL(string: "https://api.github.com/repos/o/r/pulls/abc")!) == nil)
    }

    @Test func buildsUnreadTableFilteredByRepository() async throws {
        let json = """
        [
          {"id":"1","unread":true,"reason":"review_requested","updated_at":"2026-11-25T00:00:00Z",
           "subject":{"title":"A","url":"https://api.github.com/repos/myorg/app/pulls/10","type":"PullRequest"},
           "repository":{"id":100,"full_name":"myorg/app"}},
          {"id":"2","unread":true,"reason":"mention","updated_at":"2026-11-25T00:00:00Z",
           "subject":{"title":"B","url":"https://api.github.com/repos/myorg/app/issues/11","type":"Issue"},
           "repository":{"id":100,"full_name":"myorg/app"}},
          {"id":"3","unread":true,"reason":"author","updated_at":"2026-11-25T00:00:00Z",
           "subject":{"title":"C","url":"https://api.github.com/repos/other/lib/pulls/3","type":"PullRequest"},
           "repository":{"id":200,"full_name":"other/lib"}},
          {"id":"4","unread":false,"reason":"author","updated_at":"2026-11-25T00:00:00Z",
           "subject":{"title":"D","url":"https://api.github.com/repos/myorg/app/pulls/12","type":"PullRequest"},
           "repository":{"id":100,"full_name":"myorg/app"}},
          {"id":"5","unread":true,"reason":"subscribed","updated_at":"2026-11-25T00:00:00Z",
           "subject":{"title":"E","url":null,"type":"Release"},
           "repository":{"id":100,"full_name":"myorg/app"}}
        ]
        """
        let threads = try await NotificationsClient.decode(Data(json.utf8))
        #expect(threads.count == 5)

        let all = NotificationsClient.unreadTable(from: threads, filter: RepositoryFilter())
        #expect(all == [
            PRKey(repositoryID: 100, number: 10): "1",
            PRKey(repositoryID: 200, number: 3): "3",
        ])

        let filtered = NotificationsClient.unreadTable(from: threads, filter: RepositoryFilter(owners: ["myorg"]))
        #expect(filtered == [PRKey(repositoryID: 100, number: 10): "1"])
    }

    @Test func sinceDefaultsTo30DaysAndIsOverridable() throws {
        let defaults = try #require(UserDefaults(suiteName: "SidingTests-\(UUID())"))
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(NotificationsClient.since(defaults: defaults, now: now) == now.addingTimeInterval(-30 * 86400))
        defaults.set(7, forKey: NotificationsClient.sinceDaysKey)
        #expect(NotificationsClient.since(defaults: defaults, now: now) == now.addingTimeInterval(-7 * 86400))
    }

    @Test func firstPageURLContainsSince() {
        let url = NotificationsClient.firstPageURL(since: Date(timeIntervalSince1970: 0))
        #expect(url.absoluteString == "https://api.github.com/notifications?all=false&per_page=50&since=1970-01-01T00:00:00Z")
    }

    @Test func totalUnreadCountCountsEachPROnce() {
        func pr(_ repositoryID: Int, _ number: Int) -> PullRequest {
            PullRequest(id: "\(repositoryID)-\(number)", number: number, title: "t",
                        url: URL(string: "https://github.com/o/r/pull/\(number)")!, updatedAt: .now, isDraft: false,
                        repository: "o/r", repositoryID: repositoryID, authorLogin: nil, commentCount: 0, reviewDecision: nil)
        }
        let mine = [pr(1, 1), pr(1, 2)]
        let review = [pr(2, 10), pr(1, 2)]
        let unread: Set = [PRKey(repositoryID: 1, number: 2), PRKey(repositoryID: 2, number: 10), PRKey(repositoryID: 9, number: 9)]
        #expect(PullRequestStore.totalUnreadCount(lists: [mine, review], unread: unread) == 2)
        #expect(PullRequestStore.totalUnreadCount(lists: [mine, review], unread: []) == 0)
    }

    @Test func archiveStoreRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "SidingTests-\(UUID())/archived.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        #expect(ArchiveStore.load(from: url).isEmpty)
        let keys: Set = [PRKey(repositoryID: 2, number: 10), PRKey(repositoryID: 1, number: 5)]
        ArchiveStore.save(keys, to: url)
        #expect(ArchiveStore.load(from: url) == keys)
    }
}
