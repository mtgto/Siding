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
        case .reviewRequested: store.unreadCount(in: store.reviewRequested)
        case .mine: store.unreadCount(in: store.mine)
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
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
    }
}
