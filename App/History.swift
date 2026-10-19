import Foundation
import SQLite3

/// Persisted CPU / memory / network samples (one per machine per minute, kept 7 days) in a local SQLite
/// file, so the History page survives restarts.
@MainActor
enum History {
    static let sampleEvery: TimeInterval = 60
    static let keepSeconds: TimeInterval = 7 * 86400

    private static var db: OpaquePointer?
    private static var last: [UUID: Date] = [:]

    static func open(at url: URL) {
        sqlite3_close(db); db = nil
        guard sqlite3_open(url.path, &db) == SQLITE_OK else { db = nil; return }
        sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS samples (machine TEXT, ts REAL, cpu REAL, mem REAL, net REAL);" +
                     "CREATE INDEX IF NOT EXISTS samples_idx ON samples (machine, ts);" +
                     "DELETE FROM samples WHERE ts < \(Date().timeIntervalSince1970 - keepSeconds);", nil, nil, nil)
    }

    private static func ensureOpen() {
        guard db == nil else { return }
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        open(at: dir.appendingPathComponent("history.db"))
    }

    static func record(_ s: MachineSession, now: Date = Date()) {
        if let l = last[s.id], now.timeIntervalSince(l) < sampleEvery { return }
        last[s.id] = now
        ensureOpen()
        record(machine: s.id.uuidString, ts: now.timeIntervalSince1970, cpu: s.cpuPercent,
               mem: s.memTotal > 0 ? s.memUsedFraction : nil, net: s.netTotalRate)
    }

    static func record(machine: String, ts: Double, cpu: Double?, mem: Double?, net: Double?) {
        var st: OpaquePointer?
        guard sqlite3_prepare_v2(db, "INSERT INTO samples VALUES (?,?,?,?,?)", -1, &st, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(st) }
        sqlite3_bind_text(st, 1, machine, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_double(st, 2, ts)
        for (i, v) in [cpu, mem, net].enumerated() {
            if let v { sqlite3_bind_double(st, Int32(3 + i), v) } else { sqlite3_bind_null(st, Int32(3 + i)) }
        }
        sqlite3_step(st)
    }

    struct Series { var cpu: [Double] = [], mem: [Double] = [], net: [Double] = [] }

    /// Averaged per time bucket, oldest first. Buckets with no samples are skipped, not zero-filled
    /// (shortcut: gaps while the machine was offline are not drawn, upgrade if a gap marker is wanted).
    static func series(machine: String, seconds: TimeInterval, buckets: Int = 240, now: Date = Date()) -> Series {
        ensureOpen()
        let since = now.timeIntervalSince1970 - seconds
        var st: OpaquePointer?
        let sql = "SELECT CAST((ts - ?1) / ?2 AS INTEGER) b, AVG(cpu), AVG(mem), AVG(net) FROM samples WHERE machine = ?3 AND ts >= ?1 GROUP BY b ORDER BY b"
        guard sqlite3_prepare_v2(db, sql, -1, &st, nil) == SQLITE_OK else { return Series() }
        defer { sqlite3_finalize(st) }
        sqlite3_bind_double(st, 1, since)
        sqlite3_bind_double(st, 2, seconds / Double(buckets))
        sqlite3_bind_text(st, 3, machine, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        var out = Series()
        func col(_ i: Int32) -> Double? { sqlite3_column_type(st, i) == SQLITE_NULL ? nil : sqlite3_column_double(st, i) }
        while sqlite3_step(st) == SQLITE_ROW {
            if let v = col(1) { out.cpu.append(v) }
            if let v = col(2) { out.mem.append(v) }
            if let v = col(3) { out.net.append(v) }
        }
        return out
    }
}
