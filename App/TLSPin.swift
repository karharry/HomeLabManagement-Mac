import CryptoKit
import Foundation

/// Trust-on-first-use pinning of HTTPS / WSS certificates, the TLS counterpart of the SSH host key pinning in
/// SSH.swift. Used instead of blindly trusting machines with "allow self-signed" on: the first connect pins the
/// certificate's SHA-256, later connects must match.
enum TLSPin {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var mismatched: Set<String> = []

    static func key(host: String, port: Int) -> String { "tlsCert.\(host):\(port)" }

    static func fingerprint(_ der: Data) -> String {
        SHA256.hash(data: der).map { String(format: "%02x", $0) }.joined()
    }

    /// Pins `der` on first sight; false if it differs from the pinned certificate.
    static func check(_ der: Data, host: String, port: Int, defaults: UserDefaults = .standard) -> Bool {
        let k = key(host: host, port: port), fp = fingerprint(der)
        lock.lock(); defer { lock.unlock() }
        guard let pinned = defaults.string(forKey: k) else {
            defaults.set(fp, forKey: k)
            return true
        }
        if pinned == fp { mismatched.remove(k); return true }
        mismatched.insert(k)
        return false
    }

    static func forget(host: String, port: Int, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key(host: host, port: port))
        lock.lock(); mismatched.remove(key(host: host, port: port)); lock.unlock()
    }

    /// The user-facing reason a connection was refused, if it was refused by the pin.
    static func mismatchMessage(host: String, port: Int) -> String? {
        lock.lock(); defer { lock.unlock() }
        guard mismatched.contains(key(host: host, port: port)) else { return nil }
        return "\(host):\(port) is presenting a different TLS certificate than the one first trusted. " +
            "Use \u{201C}Forget pinned host key\u{201D} in the machine's settings if this is expected (e.g. you renewed the certificate)."
    }
}
