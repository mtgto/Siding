# Developer ID で署名・公証した配布用の DMG を作る。
#
# 必要なもの:
# - Developer ID Application 証明書
# - notarytool の認証情報をキーチェーンに保存しておく。プロファイル名はアプリごとに分けず、
#   Apple ID 用の App Password として他のアプリと共用する:
#     xcrun notarytool store-credentials notarytool-password --apple-id <Apple ID> --team-id W3A6B7FDC7
#   別の名前で保存してある場合は make release NOTARY_PROFILE=<名前> で指定する。
#
# 使い方:
#   make release   # build/Siding-<version>.dmg を作る
#   make clean

PROJECT := Siding.xcodeproj
SCHEME := Siding
BUILD_DIR := build
ARCHIVE := $(BUILD_DIR)/Siding.xcarchive
EXPORT_DIR := $(BUILD_DIR)/export
APP := $(EXPORT_DIR)/Siding.app
DMG_STAGING := $(BUILD_DIR)/dmg
EXPORT_OPTIONS := scripts/export-options.plist

NOTARY_PROFILE ?= notarytool-password
SIGN_IDENTITY ?= Developer ID Application

# アーカイブ後の Info.plist から読むので、使う時点で評価する
VERSION = $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$(APP)/Contents/Info.plist")
DMG = $(BUILD_DIR)/Siding-$(VERSION).dmg

.PHONY: release archive export dmg clean

release: dmg

archive:
	xcodebuild archive \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination 'generic/platform=macOS' \
		-archivePath $(ARCHIVE)

export: archive
	rm -rf $(EXPORT_DIR)
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE) \
		-exportOptionsPlist $(EXPORT_OPTIONS) \
		-exportPath $(EXPORT_DIR)

# app と /Applications へのリンクだけを入れた DMG を作り、DMG ごと署名・公証する。
# 公証は中の app にも適用されるので、提出は DMG の 1 回だけでよい。
dmg: export
	rm -rf $(DMG_STAGING) $(DMG)
	mkdir -p $(DMG_STAGING)
	ditto $(APP) $(DMG_STAGING)/Siding.app
	ln -s /Applications $(DMG_STAGING)/Applications
	hdiutil create -volname Siding -srcfolder $(DMG_STAGING) -format UDZO -ov $(DMG)
	codesign --sign "$(SIGN_IDENTITY)" --timestamp $(DMG)
	xcrun notarytool submit $(DMG) --keychain-profile $(NOTARY_PROFILE) --wait
	xcrun stapler staple $(DMG)
	spctl --assess --type open --context context:primary-signature --verbose $(DMG)
	@echo "Created $(DMG)"

clean:
	rm -rf $(BUILD_DIR)
