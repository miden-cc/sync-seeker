import Foundation

/// Mac → iPad ファイル転送の公開エントリポイント。
/// usbmuxd 経由でデバイスのポート 2345 に接続し、SyncFrame 形式でファイルを送信する。
public final class FileSender: @unchecked Sendable {

    public init() {}

    /// syncFolder 内の変更ファイルのみを指定デバイスの port に送信する。
    /// 前回送信時のマニフェストと比較し、追加・変更されたファイルだけを転送する。
    /// - Returns: 送信したファイル数 (変更なしの場合は 0、接続もスキップ)
    @discardableResult
    public func send(to device: USBDeviceInfo, from syncFolder: URL, port: UInt16 = 2345) throws -> Int {
        // 1. 現在のマニフェストを構築 (SHA-256 ハッシュ込み)
        let currentManifest = try ManifestBuilder().buildManifest(at: syncFolder)

        // 2. 前回のマニフェストをロード (初回はなし → 全ファイルが "added")
        let previousManifest = loadCachedManifest() ?? emptyManifest(at: syncFolder)

        // 3. 差分計算
        let diff = DiffEngine().computeDiff(source: currentManifest, destination: previousManifest)
        let filesToSend = diff.added + diff.modified

        // 変更なし → ソケット接続せず即 return
        if filesToSend.isEmpty && diff.deleted.isEmpty { return 0 }

        // 4. usbmuxd 接続
        let socket = POSIXUsbmuxdSocket()
        try socket.connect(to: "/var/run/usbmuxd")
        defer { socket.disconnect() }

        // usbmuxd Connect リクエスト
        let connectRequest = try UsbmuxdPacket.encodeConnectRequest(deviceID: device.id, port: port)
        try socket.send(connectRequest)

        // レスポンス確認
        let header = try socket.receive(length: 16)
        let totalLength = header.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self).littleEndian }
        let bodyLength = Int(totalLength) - 16
        let body = bodyLength > 0 ? try socket.receive(length: bodyLength) : Data()
        let response = try UsbmuxdPacket.decode(header + body)
        if case .result(let code) = response, code != 0 {
            throw UsbmuxdError.resultError(code: code)
        }

        // 変更ファイル + 削除ファイルを送信
        var payload = SyncFrameEncoder.encodeHeader(fileCount: filesToSend.count, deleteCount: diff.deleted.count)
        for entry in filesToSend {
            let url = syncFolder.appendingPathComponent(entry.relativePath)
            let data = try Data(contentsOf: url)
            let xattrs = XattrIO.readAll(at: url)
            payload += try SyncFrameEncoder.encodeFile(entry: entry, fileData: data, xattrs: xattrs)
        }
        for entry in diff.deleted {
            payload += SyncFrameEncoder.encodeDeletion(path: entry.relativePath)
        }
        payload += SyncFrameEncoder.encodeDone()
        try socket.send(payload)

        // 5. 成功後にマニフェストをキャッシュ保存
        saveCachedManifest(currentManifest)
        return filesToSend.count
    }

    // MARK: - Manifest cache

    private static let cacheURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("SyncSeeker")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("last_manifest.json")
    }()

    private func loadCachedManifest() -> FileManifest? {
        guard let data = try? Data(contentsOf: Self.cacheURL) else { return nil }
        return try? JSONDecoder().decode(FileManifest.self, from: data)
    }

    private func saveCachedManifest(_ manifest: FileManifest) {
        guard let data = try? JSONEncoder().encode(manifest) else { return }
        try? data.write(to: Self.cacheURL)
    }

    private func emptyManifest(at root: URL) -> FileManifest {
        FileManifest(rootPath: root, entries: [], createdAt: .distantPast)
    }
}

/// USB デバイス検出の公開ラッパー。AppState から使用する。
public final class USBDeviceMonitor: @unchecked Sendable, USBConnectionDelegate {

    public var onStateChanged: ((ConnectionState) -> Void)?
    public var onDeviceConnected: ((USBDeviceInfo) -> Void)?
    public var onDeviceDisconnected: ((USBDeviceInfo) -> Void)?

    private let connection: USBMuxdConnection

    public init() {
        connection = USBMuxdConnection()
        connection.delegate = self
    }

    public func startMonitoring() { connection.startMonitoring() }
    public func stopMonitoring() { connection.stopMonitoring() }

    // MARK: - USBConnectionDelegate

    public func connectionDidChangeState(_ newState: ConnectionState) {
        onStateChanged?(newState)
    }

    public func connectionDidDetectDevice(_ device: USBDeviceInfo) {
        onDeviceConnected?(device)
    }

    public func connectionDidLoseDevice(_ device: USBDeviceInfo) {
        onDeviceDisconnected?(device)
    }
}
