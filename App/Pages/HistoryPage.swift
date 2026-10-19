import SwiftUI

/// CPU / memory / network over the last 24 hours or 7 days, from the SQLite samples in History.swift.
struct HistoryPage: View {
    @Environment(MachineSession.self) private var s
    @State private var range: TimeInterval = 86400
    @State private var data = History.Series()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Range", selection: $range) {
                    Text("Last 24 hours").tag(TimeInterval(86400))
                    Text("Last 7 days").tag(TimeInterval(7 * 86400))
                }
                .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 320)
                chart("CPU", data.cpu, max: 100, fmt: Fmt.percent)
                chart("Memory", data.mem, max: 1, fmt: { Fmt.percent($0.map { $0 * 100 }) })
                chart("Network", data.net, max: nil, fmt: Fmt.rate)
            }.padding(20)
        }
        .navigationTitle("History")
        .task(id: range) { await every(60) { data = History.series(machine: s.id.uuidString, seconds: range) } }
    }

    private func chart(_ title: String, _ vals: [Double], max: Double?, fmt: (Double?) -> String) -> some View {
        Card(title: title) {
            Sparkline(values: vals, maxValue: max, height: 90)
            Text(vals.isEmpty ? "No samples yet \u{2014} one is saved per minute while the machine is online."
                 : "average \(fmt(vals.reduce(0, +) / Double(vals.count))) \u{00B7} peak \(fmt(vals.max()))")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
