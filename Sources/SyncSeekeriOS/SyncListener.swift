import Foundation
import Network
import SyncSeeker

/// iPad 側で usbmuxd 経由の接続（Macからの同期）を受け付けるリスナー
@MainActor
final class SyncListener: ObservableObject {
    @Published var isListening = false
    @Published var statusText = "Ready to receive sync..."
    @Published var receivedFilesCount = 0
    
    // usbmuxd 経由で待ち受けるためには、iPad側は通常の localhost tcp ポートを開く
    private var listener: NWListener?
    private let port: NWEndpoint.Port = 2345
    private let syncDirectory: URL
    
    init() {
        // iPad のドキュメントディレクトリを同期先に設定
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        syncDirectory = docs.appendingPathComponent("SyncSeeker_Received")
        
        if !fm.fileExists(atPath: syncDirectory.path) {
            try? fm.createDirectory(at: syncDirectory, withIntermediateDirectories: true)
        }
    }
    
    func start() {
        do {
            listener = try NWListener(using: .tcp, on: port)
            
            listener?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self?.isListening = true
                        self?.statusText = "Listening on port \(self?.port.rawValue ?? 2345)..."
                    case .failed(let error):
                        self?.statusText = "Listener failed: \(error.localizedDescription)"
                        self?.stop()
                    case .cancelled:
                        self?.isListening = false
                        self?.statusText = "Stopped listening."
                    default:
                        break
                    }
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handleNewConnection(connection)
                }
            }
            
            listener?.start(queue: .global(qos: .userInitiated))
        } catch {
            statusText = "Failed to start listener: \(error.localizedDescription)"
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        isListening = false
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        
        Task { @MainActor in
            statusText = "Receiving sync data from Mac..."
        }
        
        receiveNextChunk(on: connection, accumulatedData: Data())
    }
    
    private func receiveNextChunk(on connection: NWConnection, accumulatedData: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }
            
            var newData = accumulatedData
            if let content = content {
                newData.append(content)
            }
            
            if isComplete || error != nil {
                // 通信終了（DONE）またはエラーで切断された場合、溜まったデータを一気にデコード
                Task { @MainActor in self.processReceivedData(newData) }
                connection.cancel()
            } else {
                // まだデータが続く場合は再帰的に受信を続ける
                Task { @MainActor in self.receiveNextChunk(on: connection, accumulatedData: newData) }
            }
        }
    }
    
    private func processReceivedData(_ data: Data) {
        Task { @MainActor in
            do {
                if data.isEmpty { return }
                
                // ヘッダー + 全ファイルのデコードを試みる
                let stream = try SyncFrameDecoder.decodeStream(data)
                
                let fm = FileManager.default
                for fileFrame in stream.files {
                    let fileURL = syncDirectory.appendingPathComponent(fileFrame.relativePath)
                    
                    let dir = fileURL.deletingLastPathComponent()
                    if !fm.fileExists(atPath: dir.path) {
                        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
                    }
                    
                    try fileFrame.fileData.write(to: fileURL)
                    self.receivedFilesCount += 1
                }
                
                statusText = "Successfully received \(stream.files.count) files!"
            } catch {
                statusText = "Sync error: \(error.localizedDescription)"
            }
        }
    }
}
