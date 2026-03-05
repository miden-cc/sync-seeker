# SyncSeeker Project Memory

## 2026-03-06 進捗

### 実装完了
- **自動ファイル監視機能** - FileWatcherService を実装
  - DispatchSourceFileSystemObject で ~/SyncSeeker フォルダを監視
  - ファイル変更（write, delete, rename, attrib）を検出
  - AppState に統合、0.5秒デバウンス機構付き
  - ファイル更新時に自動的に loadAll() を実行

### アーキテクチャ確認
- Phase 1（MVP）: USB-C同期基盤・Foundation Models統合
- Phase 2: Vision OCR・ベクター検索
- Phase 3: Shortcuts・Widget・双方向同期

### 優先事項
**PDF プレビュー・OCR は Phase 2** → 現在は Phase 1 の USB-C 同期基盤を優先

### 次のタスク
1. USB-C 接続検出（usbmuxd）
2. QUIC 差分転送
3. ネイティブ注釈（xattr）

## プロジェクト構成
- `Sources/SyncSeeker/Services/FileWatcherService.swift` - ファイル監視
- `Sources/SyncSeekerApp/App/AppState.swift` - UI状態管理 + 自動更新
- `plan.md` - 全体実装計画
