# Siding

自分専用の GitHub PR レビュー用 macOS アプリ (macOS 26+)。

- 自分の PR / 自分にレビュー依頼された PR を更新日時の降順で一覧表示
- 未読は GitHub Notifications API で判定 (github.com 上の既読と同期)
- PR はアプリ内 WebView (WebKit for SwiftUI) で表示

## セットアップ

1. classic PAT を `repo` と `notifications` スコープで作成する (fine-grained PAT は Notifications API 非対応)
2. アプリの設定 (⌘,) で PAT を保存する (Keychain に保存される)
3. 初回は WebView 内で github.com にログインする (Cookie は保持される)

## 対象の Org / リポジトリ

UserDefaults で絞り込める。両方とも未設定なら全リポジトリが対象で、設定した場合はどちらかに一致するものが対象になる。

```sh
defaults write net.mtgto.Siding WatchedOwners -array my-org another-org
defaults write net.mtgto.Siding WatchedRepos -array owner/repo
defaults delete net.mtgto.Siding WatchedOwners
```

設定の変更は次のポーリング (約1分以内) で反映される。

## 未読通知の取得期間

未読判定に使う通知は直近30日分 (最大500件) だけを取得する。期間は変更できる。

```sh
defaults write net.mtgto.Siding NotificationsSinceDays -int 14
```

## TODO

- 通知の取得件数を減らす: 未読の通知が多いと、通知に変化があるたびに最大10ページ (10リクエスト) を取り直している。`participating=true` を付ければ、自分が直接関わっている通知 (author / review_requested / mention / comment など) だけに絞れる。ただし、チーム宛てのレビュー依頼の通知が含まれるかは未確認。rate limit の消費が1時間に1000を超えるようなら対応する。

## 配布用 DMG の作成

Developer ID で署名・公証した DMG を `build/Siding-<version>.dmg` に作る。

```sh
# 初回だけ: 公証用の App Password をキーチェーンに保存する (アプリごとではなく Apple ID 用として共用)
xcrun notarytool store-credentials notarytool-password --apple-id <Apple ID> --team-id W3A6B7FDC7

make release
# 別の名前で保存してある場合
make release NOTARY_PROFILE=<名前>
```
