import Foundation
import UserNotifications

/// User-tunable alert levels (Settings), shared by the Alerts page and notifications.
struct AlertThresholds {
    var storage = 0.85, memory = 0.92
    var offlineMinutes = 0.0

    static var current: AlertThresholds {
        let d = UserDefaults.standard
        return AlertThresholds(storage: (d.object(forKey: "alertStoragePct") as? Double ?? 85) / 100,
                               memory: (d.object(forKey: "alertMemPct") as? Double ?? 92) / 100,
                               offlineMinutes: d.object(forKey: "alertOfflineMinutes") as? Double ?? 0)
    }
}

/// Notifications on offline/online transitions and newly raised alerts (not for state present at launch).
@MainActor
enum Notifier {
    private static var prevOnline: [UUID: Bool] = [:]
    private static var prevAlerts: [UUID: Set<String>] = [:]

    static var enabled: Bool { UserDefaults.standard.object(forKey: "notifications") as? Bool ?? true }

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func check(_ s: MachineSession) {
        let online: Bool
        switch s.state {
        case .connected: online = true
        case .failed: online = false
        default: return
        }
        let ids = Set(s.alerts.map(\.id))
        defer { prevOnline[s.id] = online; prevAlerts[s.id] = ids }
        guard enabled, let was = prevOnline[s.id] else { return }
        if online != was {
            if case .failed(let m) = s.state { post(s.displayName, "Went offline: \(m)") } else { post(s.displayName, "Back online") }
        } else {
            for a in s.alerts where a.id != "offline" && !(prevAlerts[s.id] ?? []).contains(a.id) {
                post("\(s.displayName): \(a.title)", a.detail)
            }
        }
    }

    private static func post(_ title: String, _ body: String) {
        let c = UNMutableNotificationContent()
        c.title = title; c.body = body; c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }
}
