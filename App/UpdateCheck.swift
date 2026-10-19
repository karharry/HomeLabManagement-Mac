import AppKit
import Foundation

/// "Is there a newer release?" against GitHub Releases. Only tells you; it never downloads anything.
enum UpdateCheck {
    static let repo = "karharry/HomeLabManagement-Mac"
    static var current: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }

    /// Compares the leading numbers of two version strings ("1.2", "v1.2.0"), missing parts counting as 0.
    static func newer(_ latest: String, than current: String = UpdateCheck.current) -> Bool {
        func parts(_ s: String) -> [Int] {
            let n = s.split { !$0.isNumber }.prefix(3).compactMap { Int($0) }
            return n + [Int](repeating: 0, count: 3 - n.count)
        }
        return parts(current).lexicographicallyPrecedes(parts(latest))
    }

    enum Outcome { case upToDate, available(tag: String, url: URL), failed(String) }

    static func run() async -> Outcome {
        do {
            let (data, resp) = try await URLSession.shared.data(from: URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!)
            guard (resp as? HTTPURLResponse)?.statusCode == 200,
                  let d = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = d["tag_name"] as? String, let url = (d["html_url"] as? String).flatMap(URL.init) else {
                return .failed("GitHub didn't return a release.")
            }
            return newer(tag) ? .available(tag: tag, url: url) : .upToDate
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

extension UpdateCheck {
    /// `verbose`: report "up to date"/errors too (menu click); otherwise only a found update shows (startup).
    @MainActor static func presentResult(verbose: Bool) async {
        let a = NSAlert()
        switch await run() {
        case .available(let tag, let url):
            a.messageText = "Update available"
            a.informativeText = "Version \(tag) is available. Open the download page?"
            a.addButton(withTitle: "Open"); a.addButton(withTitle: "Later")
            if a.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(url) }
        case .upToDate:
            guard verbose else { return }
            a.messageText = "Up to date"; a.informativeText = "You're running the latest version."
            a.runModal()
        case .failed(let m):
            guard verbose else { return }
            a.messageText = "Update check failed"; a.informativeText = m
            a.runModal()
        }
    }
}
