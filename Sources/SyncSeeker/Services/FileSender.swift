import Foundation

/// Mac → iPad ファイル転送の公開エントリポイント。
/// usbmuxd 経由でデバイスのポート 2345 に接続し、SyncFrame 形式でファイルを送信する。
public final class FileSender: @unchecked Sendable {

    public init() {}

    /// iPad に双方向同期開始シグナル（BSYN フレーム）を送信する。
    /// usbmuxd 経由でデバイスのポート 2345 に接続し、BSYN フレームを送ったら即切断する。
    public func sendBidirInit(to device: USBDeviceInfo, macHost: String, filePort: UInt16 = 2346, manifestPort: UInt16 = 2347) throws {
        let socket = POSIXUsbmuxdSocket()
        try socket.connect(to: "/var/run/usbmuxd")
        defer { socket.disconnect() }

        // usbmuxd Connect リクエスト
        let connectRequest = try UsbmuxdPacket.encodeConnectRequest(deviceID: device.id, port: 2345)
        try socket.send(connectRequest)

        // レスポンス確認
        let headerBytes = try socket.receive(length: 16)
        let totalLength = headerBytes.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self).littleEndian }
        let bodyLength = Int(totalLength) - 16
        let body = bodyLength > 0 ? try socket.receive(length: bodyLength) : Data()
        let response = try UsbmuxdPacket.decode(headerBytes + body)
        if case .result(let code) = response, code != 0 {
            throw UsbmuxdError.resultError(code: code)
        }

        // BSYN フレーム送信
        let bidirFrame = SyncFrameEncoder.encodeBidirInit(macHost: macHost, filePort: filePort, manifestPort: manifestPort)
        try socket.send(bidirFrame)
    }

    /// syncFolder 内の変更ファイルのみを指定デバイスの port に送信する。
    /// 前回送信時のマニフェストと比較し、追加・変更されたファイルだけを転送する。
    /// - Returns: 送信したファイル数 (変更なしの場合は 0、接続もスキップ)
    @discardableResult
    public func send(
        to device: USBDeviceInfo,
        from syncFolder: URL,
        port: UInt16 = 2345,
        onProgress: ((_ sent: Int, _ total: Int, _ currentFile: String) -> Void)? = nil
    ) throws -> Int {
        // デフォルト: キャッシュマニフェストとの差分計算
        let currentManifest = try ManifestBuilder().buildManifest(at: syncFolder)
        let previousManifest = loadCachedManifest() ?? emptyManifest(at: syncFolder)
        let diff = DiffEngine().computeDiff(source: currentManifest, destination: previousManifest)
        return try sendWithPlan(to: device, from: syncFolder, plan: diff, port: port, onProgress: onProgress, saveCache: true)
    }

    /// 指定された差分計画に従ってファイルを送信する（双方向同期用）。
    /// - Returns: 送信したファイル数
    @discardableResult
    public func send(
        to device: USBDeviceInfo,
        from syncFolder: URL,
        plan: DiffResult,
        port: UInt16 = 2345,
        onProgress: ((_ sent: Int, _ total: Int, _ currentFile: String) -> Void)? = nil
    ) throws -> Int {
        return try sendWithPlan(to: device, from: syncFolder, plan: plan, port: port, onProgress: onProgress, saveCache: false)
    }

    // MARK: - Implementation

    private func sendWithPlan(
        to device: USBDeviceInfo,
        from syncFolder: URL,
        plan: DiffResult,
        port: UInt16 = 2345,
        onProgress: ((_ sent: Int, _ total: Int, _ currentFile: String) -> Void)? = nil,
        saveCache: Bool = true
    ) throws -> Int {
        let filesToSend = plan.added + plan.modified

        // 変更なし → ソケット接続せず即 return
        if filesToSend.isEmpty && plan.deleted.isEmpty { return 0 }

        let currentManifest = try ManifestBuilder().buildManifest(at: syncFolder)

        // 4. ファイル読み込みとエラーのスキップ
        var successfulFiles: [(entry: ManifestEntry, data: Data, xattrs: [String: Data])] = []
        for entry in filesToSend {
            do {
                let url = syncFolder.appendingPathComponent(entry.relativePath)
                let data = try Data(contentsOf: url)
                let xattrs = XattrIO.readAll(at: url)
                successfulFiles.append((entry, data, xattrs))
            } catch {
                print("Failed to read file \(entry.relativePath): \(error)")
                continue
            }
        }

        // usbmuxd 接続
        let socket = POSIXUsbmuxdSocket()
        try socket.connect(to: "/var/run/usbmuxd")
        defer { socket.disconnect() }

        // usbmuxd Connect リクエスト
        let connectRequest = try UsbmuxdPacket.encodeConnectRequest(deviceID: device.id, port: port)
        try socket.send(connectRequest)

        // レスポンス確認
        let headerBytes = try socket.receive(length: 16)
        let totalLength = headerBytes.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self).littleEndian }
        let bodyLength = Int(totalLength) - 16
        let body = bodyLength > 0 ? try socket.receive(length: bodyLength) : Data()
        let response = try UsbmuxdPacket.decode(headerBytes + body)
        if case .result(let code) = response, code != 0 {
            throw UsbmuxdError.resultError(code: code)
        }

        // 変更ファイル + 削除ファイルを送信
        let header = SyncFrameEncoder.encodeHeader(fileCount: successfulFiles.count, deleteCount: plan.deleted.count)
        try socket.send(header)

        let total = successfulFiles.count
        for (index, file) in successfulFiles.enumerated() {
            onProgress?(index + 1, total, file.entry.relativePath)
            let frame = try SyncFrameEncoder.encodeFile(entry: file.entry, fileData: file.data, xattrs: file.xattrs)
            try socket.send(frame)
        }

        var deletionPayload = Data()
        for entry in plan.deleted {
            deletionPayload += SyncFrameEncoder.encodeDeletion(path: entry.relativePath)
        }
        deletionPayload += SyncFrameEncoder.encodeDone()
        try socket.send(deletionPayload)

        // 5. 成功後にマニフェストをキャッシュ保存 (saveCache=true の場合のみ)
        if saveCache {
            let failedPaths = Set(filesToSend.map(\.relativePath)).subtracting(successfulFiles.map(\.entry.relativePath))
            let finalEntries = currentManifest.entries.filter { !failedPaths.contains($0.relativePath) }
            let finalManifest = FileManifest(rootPath: currentManifest.rootPath, entries: finalEntries, createdAt: currentManifest.createdAt)
            saveCachedManifest(finalManifest)
        }
        return successfulFiles.count
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
