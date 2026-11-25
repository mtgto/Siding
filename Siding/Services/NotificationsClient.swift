import Foundation
import os

nonisolated struct NotificationThread: Decodable, Sendable {
    struct Subject: Decodable, Sendable {
        let title: String
        let url: URL?
        let type: String
    }
    struct Repository: Decodable, Sendable {
        let fullName: String
        enum CodingKeys: String, CodingKey { case fullName = "full_name" }
    }

    let id: String
    let unread: Bool
    let reason: String
    let updatedAt: Date
    let subject: Subject
    let repository: Repository

    enum CodingKeys: String, CodingKey {
        case id, unread, reason, subject, repository
        case updatedAt = "updated_at"
    }

    var pullRequestKey: PRKey? {
        guard subject.type == "PullRequest", let url = subject.url else { return nil }
        return PRKey(apiURL: url)
    }
}

nonisolated enum NotificationsResult: Sendable {
    case notModified(pollInterval: Int?)
    case updated(threads: [NotificationThread], etag: String?, pollInterval: Int?)
}

/// REST の Notifications API。条件付きリクエストで 304 を受ければ rate limit を消費しない。
/// ドキュメントでは Last-Modified / If-Modified-Since でのポーリングが推奨されているが、実際には 200 が返り
/// rate limit も消費される。ETag (If-None-Match) でのみ 304 を返す (2026-11 に実測)。
/// https://github.com/github/rest-api-description/issues/7474
/// ETag はクエリパラメータ (since 等) に関係なく通知の状態で決まる。
nonisolated struct NotificationsClient: Sendable {
    let token: String

    /// 取得するページ数の上限 (per_page=50 なので最大500件)
    static let maxPages = 10
    static let sinceDaysKey = "NotificationsSinceDays"
    static let defaultSinceDays = 30

    /// UserDefaults の `NotificationsSinceDays` (未設定なら30日) から取得開始日時を決める。
    static func since(defaults: UserDefaults, now: Date = .now) -> Date {
        let days = defaults.integer(forKey: sinceDaysKey)
        return now.addingTimeInterval(-Double(days > 0 ? days : defaultSinceDays) * 24 * 60 * 60)
    }

    static func firstPageURL(since: Date) -> URL {
        GitHubAPI.restBase.appending(path: "notifications").appending(queryItems: [
            URLQueryItem(name: "all", value: "false"),
            URLQueryItem(name: "per_page", value: "50"),
            URLQueryItem(name: "since", value: since.formatted(.iso8601)),
        ])
    }

    func fetchUnread(ifNoneMatch: String?, since: Date) async throws -> NotificationsResult {
        var url: URL? = Self.firstPageURL(since: since)
        var threads: [NotificationThread] = []
        var etag: String?
        var pollInterval: Int?
        var isFirstPage = true
        var pageCount = 0

        while let pageURL = url {
            if pageCount >= Self.maxPages {
                Log.network.notice("notifications: reached max pages (\(Self.maxPages, privacy: .public)), ignoring older threads")
                break
            }
            pageCount += 1
            var request = GitHubAPI.request(url: pageURL, token: token)
            if isFirstPage, let ifNoneMatch {
                request.setValue(ifNoneMatch, forHTTPHeaderField: "If-None-Match")
            }
            let (data, response) = try await GitHubAPI.session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw GitHubError.invalidResponse }
            if isFirstPage {
                pollInterval = http.value(forHTTPHeaderField: "X-Poll-Interval").flatMap(Int.init)
                etag = http.value(forHTTPHeaderField: "ETag")
            }
            Log.network.info("""
                GET notifications status=\(http.statusCode, privacy: .public) \
                ifNoneMatch=\(isFirstPage ? (ifNoneMatch ?? "-") : "-", privacy: .public) \
                etag=\(http.value(forHTTPHeaderField: "ETag") ?? "-", privacy: .public) \
                pollInterval=\(http.value(forHTTPHeaderField: "X-Poll-Interval") ?? "-", privacy: .public) \
                rateLimitUsed=\(http.value(forHTTPHeaderField: "X-RateLimit-Used") ?? "-", privacy: .public)/\(http.value(forHTTPHeaderField: "X-RateLimit-Limit") ?? "-", privacy: .public)
                """)
            switch http.statusCode {
            case 200: break
            case 304 where isFirstPage: return .notModified(pollInterval: pollInterval)
            case 401: throw GitHubError.unauthorized
            default: throw GitHubError.http(status: http.statusCode)
            }
            let page = try await Self.decode(data)
            Log.network.info("notifications page: \(page.count, privacy: .public) threads, PR=\(page.count { $0.subject.type == "PullRequest" }, privacy: .public), unread=\(page.count(where: \.unread), privacy: .public)")
            threads += page
            url = GitHubAPI.nextLink(from: http.value(forHTTPHeaderField: "Link"))
            isFirstPage = false
        }
        return .updated(threads: threads, etag: etag, pollInterval: pollInterval)
    }

    func markRead(threadID: String) async throws {
        let url = GitHubAPI.restBase.appending(path: "notifications/threads/\(threadID)")
        let request = GitHubAPI.request(url: url, token: token, method: "PATCH")
        let (_, response) = try await GitHubAPI.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GitHubError.invalidResponse }
        Log.network.info("PATCH notifications/threads/\(threadID, privacy: .public) status=\(http.statusCode, privacy: .public)")
        switch http.statusCode {
        case 200..<300, 304: return
        case 401: throw GitHubError.unauthorized
        default: throw GitHubError.http(status: http.statusCode)
        }
    }

    @concurrent
    static func decode(_ data: Data) async throws -> [NotificationThread] {
        try GitHubAPI.decoder().decode([NotificationThread].self, from: data)
    }

    /// 未読の PR 通知から `PRKey → thread ID` の表を作る。対象外のリポジトリは除く。
    static func unreadTable(from threads: [NotificationThread], filter: RepositoryFilter) -> [PRKey: String] {
        var table: [PRKey: String] = [:]
        for thread in threads where thread.unread && filter.matches(thread.repository.fullName) {
            if let key = thread.pullRequestKey {
                table[key] = thread.id
            }
        }
        return table
    }
}
