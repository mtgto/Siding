import SwiftUI

struct PullRequestListView: View {
    @Environment(PullRequestStore.self) private var store
    let pullRequests: [PullRequest]
    @Binding var selection: PullRequest.ID?

    var body: some View {
        List(pullRequests, selection: $selection) { pr in
            PullRequestRow(pullRequest: pr, isUnread: store.isUnread(pr))
                .tag(pr.id)
        }
        .overlay {
            if pullRequests.isEmpty && !store.isLoading {
                ContentUnavailableView("PR はありません", systemImage: "tray")
            }
        }
        .navigationSplitViewColumnWidth(min: 280, ideal: 340)
    }
}

struct PullRequestRow: View {
    let pullRequest: PullRequest
    let isUnread: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(isUnread ? Color.accentColor : .clear)
                .frame(width: 8, height: 8)
                .accessibilityLabel(isUnread ? "未読" : "")
            VStack(alignment: .leading, spacing: 2) {
                Text(pullRequest.title)
                    .fontWeight(isUnread ? .bold : .regular)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let decision = pullRequest.reviewDecision {
                        ReviewDecisionIcon(decision: decision)
                    }
                    Text("\(pullRequest.repository)#\(pullRequest.number)")
                    if pullRequest.isDraft {
                        Text("Draft")
                            .padding(.horizontal, 4)
                            .background(.quaternary, in: .capsule)
                    }
                    if let author = pullRequest.authorLogin {
                        Text(author)
                    }
                    if pullRequest.commentCount > 0 {
                        Label("\(pullRequest.commentCount)", systemImage: "bubble.left")
                            .labelStyle(.titleAndIcon)
                            .monospacedDigit()
                            .help("コメント \(pullRequest.commentCount) 件 (インラインコメントを含む)")
                    }
                    Spacer()
                    Text(pullRequest.updatedAt, format: .relative(presentation: .named))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// レビュー状態を Octicons で表示する (アイコンは Assets.xcassets、ライセンスは Resources/THIRD_PARTY_NOTICES.txt)。
struct ReviewDecisionIcon: View {
    let decision: ReviewDecision

    var body: some View {
        Image(imageName)
            .renderingMode(.template)
            .resizable()
            .frame(width: 12, height: 12)
            .foregroundStyle(color)
            .help(label)
            .accessibilityLabel(label)
    }

    private var imageName: String {
        switch decision {
        case .approved: "OcticonCheckCircle"
        case .changesRequested: "OcticonFileDiff"
        case .reviewRequired: "OcticonEye"
        }
    }

    private var color: Color {
        switch decision {
        case .approved: .green
        case .changesRequested: .red
        case .reviewRequired: .orange
        }
    }

    private var label: String {
        switch decision {
        case .approved: "Approved"
        case .changesRequested: "Changes requested"
        case .reviewRequired: "Review required"
        }
    }
}
