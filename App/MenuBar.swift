import AppKit

/// Menu bar item showing "machines · alerts". Left click opens the window; right click shows Show Window /
/// Preferences / Quit. Also owns the Dock rule: the Dock icon exists only while a window is open or minimized,
/// so closing the window leaves just this item running.
@MainActor
final class MenuBar: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let model: AppModel
    private var timer: Timer?
    /// Set by the App once SwiftUI hands it `openWindow`.
    static var openMainWindow: (() -> Void)?

    init(model: AppModel) {
        self.model = model
        super.init()
        item.button?.target = self
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.refresh() } }
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { _ in
            // After the close finishes: with no window left open or minimized, drop the Dock icon.
            DispatchQueue.main.async { MainActor.assumeIsolated { MenuBar.updateDockPolicy() } }
        }
    }

    private func refresh() {
        let machines = model.machines.count
        let alerts = model.orderedSessions.reduce(0) { $0 + $1.alerts.count }
        item.button?.attributedTitle = Self.label(machines, alerts)
        item.button?.toolTip = "\(machines) machine(s), \(alerts) alert(s)"
    }

    /// Icons and numbers share one font size so the item reads evenly, with a wider gap between the two groups.
    private static func label(_ machines: Int, _ alerts: Int) -> NSAttributedString {
        let font = NSFont.menuBarFont(ofSize: 0)
        let cfg = NSImage.SymbolConfiguration(pointSize: font.pointSize, weight: .regular)
        func icon(_ name: String) -> NSAttributedString {
            let a = NSTextAttachment()
            a.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(cfg)
            return NSAttributedString(attachment: a)
        }
        let out = NSMutableAttributedString()
        for (i, (name, n)) in [("server.rack", machines), ("exclamationmark.triangle", alerts)].enumerated() {
            if i > 0 { out.append(NSAttributedString(string: "    ")) }
            out.append(icon(name))
            out.append(NSAttributedString(string: " \(n)"))
        }
        out.addAttribute(.font, value: font, range: NSRange(location: 0, length: out.length))
        return out
    }

    @objc private func clicked() {
        guard let e = NSApp.currentEvent, e.type == .rightMouseUp || e.modifierFlags.contains(.control) else {
            return Self.showWindow()
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Show Window", action: #selector(show), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Preferences\u{2026}", action: #selector(prefs), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "").target = self
        item.menu = menu
        item.button?.performClick(nil)   // shows the menu under the item
        item.menu = nil                  // so left click keeps going through `clicked`
    }

    @objc private func show() { Self.showWindow() }
    @objc private func prefs() {
        Self.activate()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
    @objc private func quit() { NSApp.terminate(nil) }

    private static func activate() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func showWindow() {
        activate()
        // SwiftUI discards the window when it is closed, so reopen the scene if it is gone.
        guard let w = NSApp.windows.first(where: { $0.canBecomeMain && $0.identifier?.rawValue.contains("Settings") != true }) else {
            return openMainWindow?() ?? ()
        }
        if w.isMiniaturized { w.deminiaturize(nil) }
        w.makeKeyAndOrderFront(nil)
    }

    static func updateDockPolicy() {
        if !NSApp.windows.contains(where: { $0.canBecomeMain && ($0.isVisible || $0.isMiniaturized) }) {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
