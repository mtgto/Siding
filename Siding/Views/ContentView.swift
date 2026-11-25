import SwiftUI

enum PRSection: String, CaseIterable, Identifiable, Hashable {
    case reviewRequested
    case mine

    var id: Self { self }

    var title: String {
        switch self {
        case .reviewRequested: "レビュー依頼"
        case .mine: "自分のPR"
        }
    }

    var systemImage: String {
        switch self {
        case .reviewRequested: "eye"
        case .mine: "person"
        }
    }
}

struct ContentView: View {
    @Environment(PullRequestStore.self) private var store
    @State private var section: PRSection? = .reviewRequested
    @State private var selection: PullRequest.ID?

    private var pullRequests: [PullRequest] {
        switch section {
        case .reviewRequested: store.reviewRequested
        case .mine: store.mine
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
        .onChange(of: selection) { _, _ in
            if let pr = selectedPullRequest {
                store.markRead(pr)
            }
        }
    }
}
