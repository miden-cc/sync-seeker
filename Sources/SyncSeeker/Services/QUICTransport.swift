import Foundation
import Network

/// `TransportProtocol` の実体実装。
/// USB トンネル経由でデバイスに接続し、差分ファイルを転送する。
/// テスト時は `channelFactory` にモックを注入する。
final class QUICTransport: TransportProtocol, @unchecked Sendable {

    weak var delegate: TransportDelegate?

    private let host: NWEndpoint.Host
    private let port: NWEndpoint.Port
    private let channelFactory: (NWEndpoint.Host, NWEndpoint.Port) -> DataChannelProtocol

    private var isCancelled = false
    private var currentChannel: DataChannelProtocol?

    init(
        host: NWEndpoint.Host = "127.0.0.1",
        port: NWEndpoint.Port = 2345,
        channelFactory: @escaping (NWEndpoint.Host, NWEndpoint.Port) -> DataChannelProtocol = TCPDataChannel.make
    ) {
        self.host = host
        self.port = port
        self.channelFactory = channelFactory
    }

    // MARK: - TransportProtocol

    func transferFiles(_ entries: [ManifestEntry], from source: URL) throws {
        isCancelled = false
        let channel = channelFactory(host, port)
        currentChannel = channel

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            self.performTransfer(entries: entries, source: source, channel: channel)
        }
    }

    func cancel() {
        isCancelled = true
        currentChannel?.close()
    }

    // MARK: - Transfer

    private func performTransfer(entries: [ManifestEntry], source: URL, channel: DataChannelProtocol) {
        do {
            try channel.connect()

            let header = SyncFrameEncoder.encodeHeader(fileCount: entries.count)
            try channel.send(header)

            var totalBytes: Int64 = 0

            for (index, entry) in entries.enumerated() {
                guard !isCancelled else { return }

                let fileURL = source.appendingPathComponent(entry.relativePath)
                let fileData = try Data(contentsOf: fileURL)

                let xattrs = entry.hasXattr ? readXattrs(from: fileURL) : [:]

                let frame = try SyncFrameEncoder.encodeFile(
                    entry: entry,
                    fileData: fileData,
                    xattrs: xattrs
                )
                try channel.send(frame)

                totalBytes += Int64(fileData.count)

                let path = entry.relativePath
                notifyProgress(sent: index + 1, total: entries.count, file: path)
            }

            guard !isCancelled else { return }

            try channel.send(SyncFrameEncoder.encodeDone())
            channel.close()

            let count = entries.count
            notifyComplete(fileCount: count, totalBytes: totalBytes)

        } catch {
            channel.close()
            notifyFailure(error.localizedDescription)
        }
    }

    // MARK: - Delegate dispatch (main queue)

    private func notifyProgress(sent: Int, total: Int, file: String) {
        let d = delegate
        DispatchQueue.main.async { d?.transportDidUpdateProgress(sent: sent, total: total, currentFile: file) }
    }

    private func notifyComplete(fileCount: Int, totalBytes: Int64) {
        let d = delegate
        DispatchQueue.main.async { d?.transportDidComplete(fileCount: fileCount, totalBytes: totalBytes) }
    }

    private func notifyFailure(_ message: String) {
        let d = delegate
        DispatchQueue.main.async { d?.transportDidFail(error: message) }
    }

    // MARK: - xattr reading

    private func readXattrs(from url: URL) -> [String: Data] {
        var result: [String: Data] = [:]
        let path = url.path

        let bufSize = listxattr(path, nil, 0, XATTR_NOFOLLOW)
        guard bufSize > 0 else { return result }

        var keysBuf = [Int8](repeating: 0, count: bufSize)
        listxattr(path, &keysBuf, bufSize, XATTR_NOFOLLOW)

        let keysData = Data(bytes: keysBuf, count: bufSize)
        let keys = keysData.split(separator: 0).compactMap { String(data: Data($0), encoding: .utf8) }

        for key in keys {
            let valueSize = getxattr(path, key, nil, 0, 0, XATTR_NOFOLLOW)
            guard valueSize > 0 else { continue }
            var valueBuf = [UInt8](repeating: 0, count: valueSize)
            getxattr(path, key, &valueBuf, valueSize, 0, XATTR_NOFOLLOW)
            result[key] = Data(valueBuf)
        }

        return result
    }
}
