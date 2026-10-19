import XCTest
@testable import HomeLabManagement

@MainActor
final class ParserTests: XCTestCase {
    func testPerCoreTicksSkipsAggregateLine() {
        let t = LinuxParse.perCoreTicks(["cpu  100 0 50 800 50 0 0 0", "cpu0 40 0 20 400 40 0 0 0", "cpu1 60 0 30 400 10 0 0 0"])
        XCTAssertEqual(Set(t.keys), ["cpu0", "cpu1"])
        XCTAssertEqual(t["cpu0"]?.total, 500)
        XCTAssertEqual(t["cpu0"]?.busy, 60)   // total 500 − idle (400 + 40)
    }

    func testLocalDNSIgnoresCommentsAndSorts() {
        let r = LinuxParse.localDNS("# comment\n192.168.1.10 nas.lan\n\n192.168.1.2 a.lan extra\nbroken\n")
        XCTAssertEqual(r.map(\.domain), ["a.lan", "nas.lan"])
        XCTAssertEqual(r.first?.ip, "192.168.1.2")
    }

    func testVMsParsesDominfoLines() {
        let v = LinuxParse.vms("VM|haos|running|enable|2|4194304 KiB\nVM|old|shut off|disable|1|1048576 KiB\nnoise\n")
        XCTAssertEqual(v.map(\.name), ["haos", "old"])
        XCTAssertTrue(v[0].isRunning && v[0].autostart)
        XCTAssertEqual(v[0].memoryMiB, 4096)
        XCTAssertFalse(v[1].isRunning)
    }

    func testOPNsenseUptimeFormats() {
        XCTAssertEqual(OPNsenseSession.uptimeSeconds("0+19:22:24"), 69744)
        XCTAssertEqual(OPNsenseSession.uptimeSeconds("3 days, 02:14:05"), 267245)
        XCTAssertEqual(OPNsenseSession.uptimeSeconds("02:14:05"), 8045)
    }

    func testOPNsenseActivitySummaryFromTopHeaders() {
        let s = OPNsenseSession.activitySummary(["headers": [
            "last pid: 11190;  load averages: 0.27, 0.30, 0.30  up 3 days, 02:14:05    23:43:39",
            "CPU:  0.0% user,  0.0% nice,  0.2% system,  1.2% interrupt, 98.6% idle"]])
        XCTAssertEqual(s.uptime, 267245)
        XCTAssertEqual(s.cpu ?? -1, 1.4, accuracy: 0.001)
    }

    func testWakeOnLANParsesMACAndBuildsPacket() {
        XCTAssertEqual(WakeOnLAN.parse("aa-bb-cc-dd-ee-ff"), [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF])
        XCTAssertNil(WakeOnLAN.parse("aa:bb:cc"))
        XCTAssertNil(WakeOnLAN.parse("zz:bb:cc:dd:ee:ff"))
        let p = WakeOnLAN.magicPacket(WakeOnLAN.parse("AA:BB:CC:DD:EE:FF")!)
        XCTAssertEqual(p.count, 102)
        XCTAssertEqual(Array(p.prefix(6)), [UInt8](repeating: 0xFF, count: 6))
    }

    func testTLSPinPinsFirstCertificateThenRejectsAChange() {
        let d = UserDefaults(suiteName: "tlspin-test")!
        d.removePersistentDomain(forName: "tlspin-test")
        XCTAssertTrue(TLSPin.check(Data([1, 2, 3]), host: "h", port: 443, defaults: d))
        XCTAssertTrue(TLSPin.check(Data([1, 2, 3]), host: "h", port: 443, defaults: d))
        XCTAssertFalse(TLSPin.check(Data([9]), host: "h", port: 443, defaults: d))
        XCTAssertNotNil(TLSPin.mismatchMessage(host: "h", port: 443))
        TLSPin.forget(host: "h", port: 443, defaults: d)
        XCTAssertTrue(TLSPin.check(Data([9]), host: "h", port: 443, defaults: d))
    }

    func testUpdateCheckVersionComparison() {
        XCTAssertTrue(UpdateCheck.newer("1.3", than: "1.2.0"))
        XCTAssertTrue(UpdateCheck.newer("v1.2.1", than: "1.2.0"))
        XCTAssertFalse(UpdateCheck.newer("1.2", than: "1.2.0"))
        XCTAssertFalse(UpdateCheck.newer("1.1.9", than: "1.2.0"))
    }

    func testHistoryAveragesSamplesPerMachine() {
        History.open(at: FileManager.default.temporaryDirectory.appendingPathComponent("history-\(UUID()).db"))
        let now = Date().timeIntervalSince1970
        History.record(machine: "a", ts: now - 120, cpu: 10, mem: 0.5, net: nil)
        History.record(machine: "a", ts: now - 60, cpu: 30, mem: 0.7, net: 100)
        History.record(machine: "b", ts: now - 60, cpu: 99, mem: nil, net: nil)
        let r = History.series(machine: "a", seconds: 3600, buckets: 1)
        XCTAssertEqual(r.cpu, [20])
        XCTAssertEqual(r.net, [100])
        XCTAssertEqual(History.series(machine: "a", seconds: 30).cpu, [])
    }

    func testMachineDecodesOldFilesAndComputesWebAddress() throws {
        var m = try JSONDecoder().decode(Machine.self, from: Data(#"{"kind":"opnsense","host":"fw","port":8443}"#.utf8))
        XCTAssertEqual(m.mac, "")
        XCTAssertEqual(m.webAddress?.absoluteString, "https://fw:8443")
        m.webUrl = "https://x/"
        XCTAssertEqual(m.webAddress?.absoluteString, "https://x/")
    }
}
