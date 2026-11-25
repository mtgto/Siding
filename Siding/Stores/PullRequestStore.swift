import Foundation
import os
import Observation

/// PR 一覧と未読状態を管理する。
/// - 一覧: GraphQL search (起動時・⌘R・通知に変化があったとき・15分ごとの保険)
/// - 未読と変更検知: Notifications API を X-Poll-Interval ごとに条件付きでポーリング
@Observable
final class PullRequestStore {
    private(set) var mine: [PullRequest] = []
    private(set) var reviewRequested: [PullRequest] = []
    private(set) var unreadThreads: [PRKey: String] = [:]
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var lastUpdated: Date?
    private(set) var hasToken = false

    /// search の保険としての再取得間隔
    static let searchRefreshInterval: Duration = .seconds(15 * 60)
    static let defaultPollInterval = 60

    private var token: String?
    private var filter = RepositoryFilter(defaults: .standard)
    private var etag: String?
    private var pollInterval = defaultPollInterval
    private var lastSearchAt: ContinuousClock.Instant?
    private var pollingTask: Task<Void, Never>?
    private let clock = ContinuousClock()

    init() {
        token = KeychainStore.loadToken()
        hasToken = token != nil
    }

    func isUnread(_ pr: PullRequest) -> Bool {
        unreadThreads[pr.key] != nil
    }

    func unreadCount(in prs: [PullRequest]) -> Int {
        prs.count { isUnread($0) }
    }

    // MARK: - Token

    func updateToken(_ newToken: String) {
        let trimmed = newToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainStore.deleteToken()
            token = nil
        } else {
            KeychainStore.saveToken(trimmed)
            token = trimmed
        }
        hasToken = token != nil
        mine = []
        reviewRequested = []
        unreadThreads = [:]
        lastError = nil
        start()
    }

    // MARK: - Polling

    /// ポーリングを (再) 開始する。最初に一覧と通知を強制取得する。
    func start() {
        pollingTask?.cancel()
        guard token != nil else { return }
        pollingTask = Task { [weak self] in
            await self?.refreshAll()
            while !Task.isCancelled {
                let interval = self?.pollInterval ?? Self.defaultPollInterval
                try? await Task.sleep(for: .seconds(interval))
                if Task.isCancelled { break }
                await self?.poll()
            }
        }
    }

    /// ⌘R: 一覧と通知を条件なしで取得し直す。
    func refreshAll() async {
        guard let token else { return }
        filter = RepositoryFilter(defaults: .standard)
        isLoading = true
        defer { isLoading = false }
        do {
            async let lists: Void = refreshLists(token: token)
            async let notifications: Bool = refreshNotifications(token: token, conditional: false)
            _ = try await (lists, notifications)
            lastError = nil
            lastUpdated = .now
        } catch {
            handle(error)
        }
    }

    private func poll() async {
        guard let token else { return }
        do {
            let newFilter = RepositoryFilter(defaults: .standard)
            let filterChanged = newFilter != filter
            filter = newFilter

            let changed = try await refreshNotifications(token: token, conditional: !filterChanged)
            let searchIsStale = lastSearchAt.map { clock.now - $0 >= Self.searchRefreshInterval } ?? true
            Log.store.info("poll: notificationsChanged=\(changed, privacy: .public) filterChanged=\(filterChanged, privacy: .public) searchIsStale=\(searchIsStale, privacy: .public) next=\(self.pollInterval, privacy: .public)s")
            if changed || filterChanged || searchIsStale {
                try await refreshLists(token: token)
            }
            lastError = nil
            lastUpdated = .now
        } catch {
            handle(error)
        }
    }

    private func refreshLists(token: String) async throws {
        let client = GitHubClient(token: token)
        let filter = self.filter
        async let mineResult = client.searchPullRequests(query: filter.searchQuery(base: GitHubClient.myPullRequestsQuery))
        async let reviewResult = client.searchPullRequests(query: filter.searchQuery(base: GitHubClient.reviewRequestedQuery))
        let (mine, review) = try await (mineResult, reviewResult)
        self.mine = mine.filter { filter.matches($0.repository) }
        self.reviewRequested = review.filter { filter.matches($0.repository) }
        lastSearchAt = clock.now
        Log.store.info("lists: mine=\(self.mine.map(\.key.description), privacy: .public) reviewRequested=\(self.reviewRequested.map(\.key.description), privacy: .public)")
    }

    /// 未読表を更新する。変化があれば true。
    private func refreshNotifications(token: String, conditional: Bool) async throws -> Bool {
        let client = NotificationsClient(token: token)
        let result = try await client.fetchUnread(
            ifNoneMatch: conditional ? etag : nil,
            since: NotificationsClient.since(defaults: .standard)
        )
        switch result {
        case .notModified(let interval):
            if let interval { pollInterval = interval }
            return false
        case .updated(let threads, let etag, let interval):
            if let interval { pollInterval = interval }
            self.etag = etag
            let table = NotificationsClient.unreadTable(from: threads, filter: filter)
            let changed = table != unreadThreads
            unreadThreads = table
            Log.store.info("unread PRs (\(threads.count, privacy: .public) threads fetched): \(table.keys.map(\.description).sorted(), privacy: .public)")
            return changed
        }
    }

    // MARK: - Read

    /// PR を開いたときに呼ぶ。対応する通知スレッドを既読にする。
    func markRead(_ pr: PullRequest) {
        guard let token, let threadID = unreadThreads.removeValue(forKey: pr.key) else { return }
        Task {
            do {
                try await NotificationsClient(token: token).markRead(threadID: threadID)
            } catch {
                handle(error)
            }
        }
    }

    private func handle(_ error: any Error) {
        if error is CancellationError { return }
        if let urlError = error as? URLError, urlError.code == .cancelled { return }
        lastError = error.localizedDescription
    }
}
