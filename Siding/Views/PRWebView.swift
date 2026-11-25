import SwiftUI
import WebKit

/// WebKit for SwiftUI でアプリ内に GitHub を表示する。
/// WebPage は既定で永続的な WKWebsiteDataStore を使うため、github.com のログインは再起動後も残る。
struct PRWebView: View {
    let url: URL
    @State private var page = WebPage()
    @Environment(\.openURL) private var openURL

    var body: some View {
        WebView(page)
            .onAppear { load() }
            .onChange(of: url) { _, _ in load() }
            .toolbar {
                ToolbarItemGroup {
                    Button("戻る", systemImage: "chevron.backward") {
                        if let item = page.backForwardList.backList.last {
                            page.load(item)
                        }
                    }
                    .disabled(page.backForwardList.backList.isEmpty)

                    Button("進む", systemImage: "chevron.forward") {
                        if let item = page.backForwardList.forwardList.first {
                            page.load(item)
                        }
                    }
                    .disabled(page.backForwardList.forwardList.isEmpty)

                    if page.isLoading {
                        Button("中止", systemImage: "xmark") { page.stopLoading() }
                    } else {
                        Button("再読み込み", systemImage: "arrow.clockwise") { page.reload() }
                    }

                    Button("ブラウザで開く", systemImage: "safari") {
                        openURL(page.url ?? url)
                    }
                }
            }
    }

    private func load() {
        page.load(URLRequest(url: url))
    }
}
