import Foundation

/// usbmuxd ソケット I/O を抽象化するプロトコル。テスト時はモックに差し替え可能。
protocol UsbmuxdSocketProtocol {
    var isConnected: Bool { get }
    func connect(to path: String) throws
    /// 指定バイト数を正確に読み取る（short-read をループで補完）。
    func receive(length: Int) throws -> Data
    func send(_ data: Data) throws
    func disconnect()
}

// MARK: - POSIX implementation

/// 実機用: POSIX Unix ドメインソケットで /var/run/usbmuxd に接続する。
final class POSIXUsbmuxdSocket: UsbmuxdSocketProtocol {

    private var fd: Int32 = -1
    private(set) var isConnected = false

    func connect(to path: String) throws {
        let sockFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sockFd >= 0 else {
            throw UsbmuxdError.connectionFailed("socket() failed: \(errno)")
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = path.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            Darwin.close(sockFd)
            throw UsbmuxdError.connectionFailed("Socket path too long")
        }
        withUnsafeMutableBytes(of: &addr.sun_path) { dst in
            pathBytes.withUnsafeBytes { src in
                dst.copyMemory(from: src)
            }
        }

        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(sockFd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            Darwin.close(sockFd)
            throw UsbmuxdError.connectionFailed("connect() failed: \(errno)")
        }

        fd = sockFd
        isConnected = true
    }

    func receive(length: Int) throws -> Data {
        guard isConnected, fd >= 0 else {
            throw UsbmuxdError.connectionFailed("Not connected")
        }
        var buffer = Data(count: length)
        var totalRead = 0

        try buffer.withUnsafeMutableBytes { ptr in
            while totalRead < length {
                let n = read(fd, ptr.baseAddress!.advanced(by: totalRead), length - totalRead)
                if n <= 0 {
                    throw UsbmuxdError.connectionFailed("read() failed or EOF: \(errno)")
                }
                totalRead += n
            }
        }
        return buffer
    }

    func send(_ data: Data) throws {
        guard isConnected, fd >= 0 else {
            throw UsbmuxdError.connectionFailed("Not connected")
        }
        try data.withUnsafeBytes { ptr in
            var totalSent = 0
            while totalSent < data.count {
                let n = write(fd, ptr.baseAddress!.advanced(by: totalSent), data.count - totalSent)
                if n < 0 {
                    throw UsbmuxdError.connectionFailed("write() failed: \(errno)")
                }
                totalSent += n
            }
        }
    }

    func disconnect() {
        if fd >= 0 {
            Darwin.close(fd)
            fd = -1
        }
        isConnected = false
    }
}
