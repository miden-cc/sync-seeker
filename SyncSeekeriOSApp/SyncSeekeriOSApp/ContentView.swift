//
//  ContentView.swift
//  SyncSeekeriOSApp
//

import SwiftUI
import Network
import SyncSeeker

struct ContentView: View {
    @StateObject private var listener = SyncListener()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: listener.isListening ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 60))
                    .foregroundColor(listener.isListening ? .green : .gray)
                
                Text(listener.statusText)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()
                
                if listener.receivedFilesCount > 0 {
                    Text("\(listener.receivedFilesCount) files received")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Button(action: toggleListen) {
                    Text(listener.isListening ? "Stop Listening" : "Start Listening")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(listener.isListening ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
            }
            .navigationTitle("SyncSeeker iPad")
        }
    }
    
    private func toggleListen() {
        if listener.isListening {
            listener.stop()
        } else {
            listener.start()
        }
    }
}

/// iPad 側で usbmuxd 経由の接続（Macからの同期）を受け付けるリスナー
@MainActor
final class SyncListener: ObservableObject {
    @Published var isListening = false
    @Published var statusText = "Ready to receive sync..."
    @Published var receivedFilesCount = 0
    
    private var listener: NWListener?
    private let port: NWEndpoint.Port = 2345
    private let syncDirectory: URL
    
    init() {
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
                self?.handleNewConnection(connection)
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
                self.processReceivedData(newData)
                connection.cancel()
            } else {
                self.receiveNextChunk(on: connection, accumulatedData: newData)
            }
        }
    }
    
    private func processReceivedData(_ data: Data) {
        Task { @MainActor in
            do {
                if data.isEmpty { return }
                
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
