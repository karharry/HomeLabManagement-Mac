import SwiftUI

struct SettingsPage: View {
    @AppStorage("openAtLogin") private var openAtLogin = false
    @AppStorage("openMinimized") private var openMinimized = false
    @AppStorage("openInMenuBar") private var openInMenuBar = false
    @AppStorage("notifications") private var notifications = true
    @AppStorage("alertStoragePct") private var storagePct = 85.0
    @AppStorage("alertMemPct") private var memPct = 92.0
    @AppStorage("alertOfflineMinutes") private var offlineMinutes = 0.0
    @State private var loginItemError: String?

    var body: some View {
        Form {
            Section {
                Toggle("Open at Login", isOn: $openAtLogin)
                    .onChange(of: openAtLogin) { _, new in
                        if !LoginItem.setEnabled(new) {
                            loginItemError = "Couldn't update the Login Items setting. You can add or remove it directly in System Settings \u{2192} General \u{2192} Login Items."
                            openAtLogin = LoginItem.isEnabled
                        } else {
                            loginItemError = nil
                        }
                    }
                // The two start modes exclude each other: turning one on turns the other off.
                Toggle("Open Minimized", isOn: $openMinimized)
                    .onChange(of: openMinimized) { _, on in if on { openInMenuBar = false } }
                Toggle("Open in Menu Bar", isOn: $openInMenuBar)
                    .onChange(of: openInMenuBar) { _, on in if on { openMinimized = false } }
                Text("Open Minimized starts minimized to the Dock; Open in Menu Bar starts with no window or Dock icon, just the menu bar item. Only one can be on.")
                    .font(.caption).foregroundStyle(.secondary)
                if let loginItemError {
                    Text(loginItemError).font(.caption).foregroundStyle(.orange)
                }
            }
            Section("Alerts") {
                Toggle("Notify when a machine goes offline or raises an alert", isOn: $notifications)
                Stepper("Storage alert at \(Int(storagePct))% full", value: $storagePct, in: 50...99)
                Stepper("Memory alert at \(Int(memPct))% used", value: $memPct, in: 50...99)
                Stepper(offlineMinutes == 0 ? "Offline alert: immediately" : "Offline alert after \(Int(offlineMinutes)) min",
                        value: $offlineMinutes, in: 0...120)
            }
            Text("HomeLab Management \(UpdateCheck.current)").font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460, height: 470)
        .onAppear { openAtLogin = LoginItem.isEnabled }
    }
}
