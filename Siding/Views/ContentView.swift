import SwiftUI

enum PRSection: String, CaseIterable, Identifiable, Hashable {
    case reviewRequested
    case mine
    case archived

    var id: Self { self }

    var title: String {
        switch self {
        case .reviewRequested: "レビュー依頼"
        case .mine: "自分のPR"
        case .archived: "アーカイブ"
        }
    }

    var systemImage: String {
        switch self {
        case .reviewRequested: "eye"
        case .mine: "person"
        case .archived: "archivebox"
        }
    }
}

struct ContentView: View {
    @Environment(PullRequestStore.self) private var store
    @State private var section: PRSection? = .reviewRequested
    @State private var selection: PullRequest.ID?

    /// PR を選んでから既読にするまでの時間
    private static let markReadDelay: Duration = .seconds(1)

    private var pullRequests: [PullRequest] {
        switch section {
        case .reviewRequested: store.visibleReviewRequested
        case .mine: store.visibleMine
        case .archived: store.archivedPullRequests
        case nil: []
        }
    }

    private var selectedPullRequest: PullRequest? {
        guard let selection else { return nil }
        return (store.reviewRequested + store.mine).first { $0.id == selection }
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $section)
        } content: {
            if store.hasToken {
                PullRequestListView(pullRequests: pullRequests, selection: $selection)
                    .navigationTitle(section?.title ?? "Siding")
            } else {
                ContentUnavailableView {
                    Label("GitHub トークンが未設定です", systemImage: "key")
                } description: {
                    Text("設定 (⌘,) で classic PAT (repo / notifications スコープ) を入力してください。")
                } actions: {
                    SettingsLink { Text("設定を開く") }
                }
            }
        } detail: {
            if let pr = selectedPullRequest {
                PRWebView(url: pr.url)
            } else {
                ContentUnavailableView("PR を選択してください", systemImage: "arrow.triangle.pull")
            }
        }
        // j/k で通り過ぎただけの PR は既読にしないよう、同じ PR を一定時間選び続けたら既読にする。
        // 選択が変わると task はキャンセルされる。
        .task(id: selection) {
            guard selection != nil else { return }
            do {
                try await Task.sleep(for: Self.markReadDelay)
            } catch {
                return
            }
            if let pr = selectedPullRequest {
                store.markRead(pr)
            }
        }
    }
}
