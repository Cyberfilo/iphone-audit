import Foundation
import Darwin

/// Minimal POSIX Unix-domain socket wrapper. Connects synchronously, exposes
/// raw read/write that the bridge layers newline-delimited JSON-RPC over.
final class UnixSocketConnection {
    enum SocketError: Error, LocalizedError {
        case socketCreate(Int32)
        case pathTooLong
        case connect(Int32)
        case writeFailed(Int32)
        case readFailed(Int32)
        case closed

        var errorDescription: String? {
            switch self {
            case .socketCreate(let err): return "socket(): errno=\(err) — \(String(cString: strerror(err)))"
            case .pathTooLong: return "Socket path is longer than sizeof(sun_path)."
            case .connect(let err): return "connect(): errno=\(err) — \(String(cString: strerror(err)))"
            case .writeFailed(let err): return "write(): errno=\(err) — \(String(cString: strerror(err)))"
            case .readFailed(let err): return "read(): errno=\(err) — \(String(cString: strerror(err)))"
            case .closed: return "Socket closed."
            }
        }
    }

    private var fd: Int32
    private var buffer = Data()
    private let lock = NSLock()

    init(path: String) throws {
        let sock = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sock >= 0 else { throw SocketError.socketCreate(errno) }
        self.fd = sock

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(path.utf8)
        let pathCapacity = MemoryLayout.size(ofValue: addr.sun_path)
        guard pathBytes.count < pathCapacity else {
            close(sock)
            throw SocketError.pathTooLong
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { tuplePtr in
            tuplePtr.withMemoryRebound(to: CChar.self, capacity: pathCapacity) { cPtr in
                for (i, byte) in pathBytes.enumerated() {
                    cPtr[i] = CChar(bitPattern: byte)
                }
                cPtr[pathBytes.count] = 0
            }
        }
        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { ptr in
                Darwin.connect(sock, ptr, addrLen)
            }
        }
        if result != 0 {
            let err = errno
            close(sock)
            throw SocketError.connect(err)
        }
    }

    deinit {
        close(fd)
    }

    /// Atomically write a payload + newline.
    func writeLine(_ data: Data) throws {
        lock.lock(); defer { lock.unlock() }
        var bytes = data
        bytes.append(0x0A)
        try bytes.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            var written: Int = 0
            let total = raw.count
            let base = raw.baseAddress!
            while written < total {
                let n = Darwin.write(fd, base.advanced(by: written), total - written)
                if n < 0 {
                    if errno == EINTR { continue }
                    throw SocketError.writeFailed(errno)
                }
                if n == 0 { throw SocketError.closed }
                written += n
            }
        }
    }

    /// Read exactly one newline-terminated line (newline stripped).
    func readLine() throws -> Data {
        var buf = [UInt8](repeating: 0, count: 8192)
        while true {
            if let nlIdx = buffer.firstIndex(of: 0x0A) {
                let line = buffer.subdata(in: 0 ..< nlIdx)
                buffer.removeSubrange(0 ..< (nlIdx + 1))
                return line
            }
            let n = buf.withUnsafeMutableBufferPointer { bp in
                Darwin.read(fd, bp.baseAddress, bp.count)
            }
            if n < 0 {
                if errno == EINTR { continue }
                throw SocketError.readFailed(errno)
            }
            if n == 0 { throw SocketError.closed }
            buffer.append(contentsOf: buf.prefix(n))
        }
    }
}
