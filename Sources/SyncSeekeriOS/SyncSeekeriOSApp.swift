import SwiftUI
import SyncSeeker

@main
struct SyncSeekeriOSApp: App {
    var body: some Scene {
        WindowGroup {
            SyncReceiverView()
        }
    }
}

struct SyncReceiverView: View {
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
