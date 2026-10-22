import SwiftUI

@main
struct HomeLabManagementApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(model)
                .frame(minWidth: 820, minHeight: 560)
                .onAppear {
                    model.startAll()
                    MenuBar.openMainWindow = { openWindow(id: "main") }
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Export Machines\u{2026}") { MachineTransfer.export(model.machines) }
                Button("Import Machines\u{2026}") { MachineTransfer.importFile(into: model) }
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates\u{2026}") { Task { await UpdateCheck.presentResult(verbose: true) } }
            }
        }

        Settings {
            SettingsPage()
        }
    }
}
