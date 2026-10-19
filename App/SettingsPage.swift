import SwiftUI

struct SettingsPage: View {
    @AppStorage("openAtLogin") private var openAtLogin = false
    @AppStorage("openMinimized") private var openMinimized = false
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
                Toggle("Open Minimized", isOn: $openMinimized)
                Text("When on, HomeLab Management starts minimized to the Dock instead of opening a window right away.")
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
        .frame(width: 460, height: 420)
        .onAppear { openAtLogin = LoginItem.isEnabled }
    }
}
