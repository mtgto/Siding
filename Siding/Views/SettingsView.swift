import SwiftUI

struct SettingsView: View {
    @Environment(PullRequestStore.self) private var store
    @State private var token = ""

    var body: some View {
        Form {
            Section {
                SecureField("Personal access token (classic)", text: $token)
                HStack {
                    Spacer()
                    if store.hasToken {
                        Button("削除", role: .destructive) {
                            token = ""
                            store.updateToken("")
                        }
                    }
                    Button("保存") {
                        store.updateToken(token)
                        token = ""
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(token.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("GitHub トークン")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.hasToken ? "トークンは Keychain に保存済みです。" : "トークンが未設定です。")
                    Text("classic PAT に `repo` と `notifications` スコープを付けてください (fine-grained PAT は Notifications API 非対応)。")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("対象の Org / リポジトリ") {
                Text("""
                defaults コマンドで設定します (未設定なら全リポジトリ):
                defaults write net.mtgto.Siding WatchedOwners -array my-org
                defaults write net.mtgto.Siding WatchedRepos -array owner/repo
                """)
                .font(.caption.monospaced())
                .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .padding()
    }
}
