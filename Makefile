.PHONY: mac ipad test

## Mac メニューバーアプリを起動
mac:
	swift run SyncSeekerApp

## iPad Xcode プロジェクトを開く
ipad:
	open SyncSeekerPad/SyncSeekerPad.xcodeproj

## 全テスト実行
test:
	swift test
