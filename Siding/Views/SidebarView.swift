import SwiftUI

struct SidebarView: View {
    @Environment(PullRequestStore.self) private var store
    @Binding var selection: PRSection?

    var body: some View {
        List(selection: $selection) {
            ForEach(PRSection.allCases) { section in
                Label(section.title, systemImage: section.systemImage)
                    .badge(unreadCount(for: section))
                    .tag(section)
            }
        }
        .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        .safeAreaInset(edge: .bottom) {
            StatusFooter()
        }
    }

    private func unreadCount(for section: PRSection) -> Int {
        switch section {
        case .reviewRequested: store.unreadCount(in: store.visibleReviewRequested)
        case .mine: store.unreadCount(in: store.visibleMine)
        case .archived: 0
        }
    }
}

private struct RateLimitLabel: View {
    let name: String
    let rateLimit: RateLimit?

    var body: some View {
        if let rateLimit {
            Text("\(name): 残り \(rateLimit.remaining) / \(rateLimit.limit)")
                .monospacedDigit()
                .foregroundStyle(rateLimit.remaining * 10 < rateLimit.limit ? .orange : .secondary)
                .help("リセット: \(rateLimit.reset.formatted(date: .omitted, time: .shortened))")
        }
    }
}

private struct StatusFooter: View {
    @Environment(PullRequestStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let error = store.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .lineLimit(3)
            } else if store.isLoading {
                ProgressView().controlSize(.small)
            } else if let updated = store.lastUpdated {
                Text("更新: \(updated, style: .time)")
                    .foregroundStyle(.secondary)
            }
            RateLimitLabel(name: "REST", rateLimit: store.restRateLimit)
            RateLimitLabel(name: "GraphQL", rateLimit: store.graphQLRateLimit)
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
    }
}
