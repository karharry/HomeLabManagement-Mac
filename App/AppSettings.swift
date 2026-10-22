import AppKit
import ServiceManagement

/// Minimizes the main window right after launch when "Open Minimized" is on, and hosts the menu bar item
/// (see MenuBar.swift) that keeps the app running after the window is closed.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBar?

    // Closing the window leaves the app running in the menu bar; Quit lives in that item's menu.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBar(model: .shared)
        Notifier.requestAuthorization()
        Task { try? await Task.sleep(for: .seconds(5)); await UpdateCheck.presentResult(verbose: false) }
        let d = UserDefaults.standard
        guard d.bool(forKey: "openMinimized") || d.bool(forKey: "openInMenuBar") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            // Closing (not minimizing) is what drops the Dock icon and leaves only the menu bar item.
            NSApp.windows.filter(\.canBecomeMain).forEach { d.bool(forKey: "openInMenuBar") ? $0.close() : $0.miniaturize(nil) }
        }
    }
}

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return true
        } catch {
            return false
        }
    }
}
