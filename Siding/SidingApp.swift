import SwiftUI

@main
struct SidingApp: App {
    @State private var store = PullRequestStore()

    var body: some Scene {
        Window("Siding", id: "main") {
            ContentView()
                .environment(store)
                .task { store.start() }
        }
        .commands {
            CommandGroup(after: .toolbar) {
                Button("一覧を再読み込み") {
                    Task { await store.refreshAll() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(store)
        }
    }
}
