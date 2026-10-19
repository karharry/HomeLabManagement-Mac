import SwiftUI

@main
struct HomeLabManagementApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .frame(minWidth: 820, minHeight: 560)
                .onAppear { model.startAll() }
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
