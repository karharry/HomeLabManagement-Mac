import AppKit

/// Export / import of the machine list as JSON. Passwords and API secrets live in the Keychain and are never exported.
@MainActor
enum MachineTransfer {
    private struct File: Codable { var machines: [Machine] }

    static func export(_ machines: [Machine]) {
        let p = NSSavePanel()
        p.nameFieldStringValue = "homelab-machines.json"
        p.allowedContentTypes = [.json]
        guard p.runModal() == .OK, let url = p.url else { return }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try enc.encode(File(machines: machines)).write(to: url)
            alert("Exported", "Saved without passwords or API secrets \u{2014} re-enter those after importing on another Mac.")
        } catch { alert("Export failed", error.localizedDescription) }
    }

    static func importFile(into model: AppModel) {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.json]
        guard p.runModal() == .OK, let url = p.url else { return }
        do {
            let f = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
            model.importMachines(f.machines)
            alert("Imported", "Added \(f.machines.count) machine(s). Edit each one to enter its password.")
        } catch { alert("Import failed", "That doesn't look like an exported machine list: \(error.localizedDescription)") }
    }

    private static func alert(_ title: String, _ text: String) {
        let a = NSAlert()
        a.messageText = title; a.informativeText = text
        a.runModal()
    }
}
