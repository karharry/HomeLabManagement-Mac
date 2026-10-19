import Darwin
import Foundation

/// Wake-on-LAN magic packet.
enum WakeOnLAN {
    /// The 6 bytes of `mac` (any of `:`, `-`, `.` or spaces as separators), or nil if it isn't a MAC address.
    static func parse(_ mac: String) -> [UInt8]? {
        let hex = mac.filter { !":-. \t".contains($0) }
        guard hex.count == 12, hex.allSatisfy(\.isHexDigit) else { return nil }
        var bytes: [UInt8] = []
        var i = hex.startIndex
        while i < hex.endIndex {
            let j = hex.index(i, offsetBy: 2)
            bytes.append(UInt8(hex[i..<j], radix: 16)!)
            i = j
        }
        return bytes
    }

    static func magicPacket(_ mac: [UInt8]) -> [UInt8] {
        [UInt8](repeating: 0xFF, count: 6) + Array([[UInt8]](repeating: mac, count: 16).joined())
    }

    struct Failure: LocalizedError { var errorDescription: String? }

    static func wake(_ mac: String) throws {
        guard let bytes = parse(mac) else { throw Failure(errorDescription: "\u{201C}\(mac)\u{201D} isn't a valid MAC address (expected like AA:BB:CC:DD:EE:FF).") }
        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { throw Failure(errorDescription: String(cString: strerror(errno))) }
        defer { close(fd) }
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &on, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(9).bigEndian
        addr.sin_addr.s_addr = INADDR_BROADCAST.bigEndian
        let packet = magicPacket(bytes)
        let sent = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                sendto(fd, packet, packet.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard sent == packet.count else { throw Failure(errorDescription: String(cString: strerror(errno))) }
    }
}
