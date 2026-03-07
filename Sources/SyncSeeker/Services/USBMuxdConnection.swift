import Foundation

/// usbmuxd ソケットを使って USB-C 接続された iOS デバイスを検出・接続する。
/// テスト時は `UsbmuxdSocketProtocol` モックを注入して動作を検証できる。
final class USBMuxdConnection: USBConnectionProtocol, @unchecked Sendable {

    private(set) var currentState: ConnectionState = .disconnected
    weak var delegate: USBConnectionDelegate?

    private let socket: UsbmuxdSocketProtocol
    private var monitorThread: Thread?
    private var isMonitoring = false
    private var knownDevices: [Int: USBDeviceInfo] = [:]

    init(socket: UsbmuxdSocketProtocol = POSIXUsbmuxdSocket()) {
        self.socket = socket
    }

    // MARK: - USBConnectionProtocol

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        monitorThread = Thread { [weak self] in self?.runMonitorLoop() }
        monitorThread?.name = "com.miden.usbmuxd-monitor"
        monitorThread?.start()
    }

    func stopMonitoring() {
        isMonitoring = false
        socket.disconnect()
        monitorThread = nil
        knownDevices.removeAll()
    }

    func connectToDevice(_ device: USBDeviceInfo, port: UInt16) throws {
        let request = try UsbmuxdPacket.encodeConnectRequest(deviceID: device.id, port: port)
        try socket.send(request)

        let response = try readPacket()
        if case .result(let code) = response, code != 0 {
            throw UsbmuxdError.resultError(code: code)
        }

        currentState = .connected(device)
        delegate?.connectionDidChangeState(.connected(device))
    }

    func disconnect() {
        socket.disconnect()
        currentState = .disconnected
        delegate?.connectionDidChangeState(.disconnected)
    }

    // MARK: - Monitor loop

    private func runMonitorLoop() {
        do {
            try socket.connect(to: "/var/run/usbmuxd")

            let listenRequest = try UsbmuxdPacket.encodeListenRequest()
            try socket.send(listenRequest)

            // Confirm listen was accepted
            let listenResult = try readPacket()
            if case .result(let code) = listenResult, code != 0 {
                delegate?.connectionDidChangeState(.error("usbmuxd listen rejected (code \(code))"))
                return
            }

            // Event loop
            while isMonitoring {
                let message = try readPacket()
                handleMessage(message)
            }
        } catch {
            if isMonitoring {
                delegate?.connectionDidChangeState(.error(error.localizedDescription))
            }
        }
    }

    // MARK: - Helpers

    /// ヘッダー（16バイト）を読んで、残りの本文と合わせてデコードする。
    private func readPacket() throws -> UsbmuxdMessage {
        let header = try socket.receive(length: 16)
        let totalLength = header.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self).littleEndian }
        let bodyLength = Int(totalLength) - 16
        let body = bodyLength > 0 ? try socket.receive(length: bodyLength) : Data()
        return try UsbmuxdPacket.decode(header + body)
    }

    private func handleMessage(_ message: UsbmuxdMessage) {
        switch message {
        case .deviceAttached(let device):
            knownDevices[device.id] = device
            delegate?.connectionDidDetectDevice(device)
        case .deviceDetached(let deviceID):
            if let device = knownDevices.removeValue(forKey: deviceID) {
                delegate?.connectionDidLoseDevice(device)
            }
        default:
            break
        }
    }
}
