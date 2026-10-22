# HomeLab Management — macOS

> Looking for Windows? See **[HomeLabManagement-Windows](https://github.com/karharry/HomeLabManagement-Windows)**.

A native macOS app for monitoring and managing a home
lab: TrueNAS SCALE, Linux (Debian/Ubuntu, Raspberry Pi OS, Arch), Windows, Mac,
and OPNsense machines, all from one sidebar.

> **Project status:** This is a personal tool I built for my own home lab and
> am sharing as-is, in case it's useful to someone else. I have a full-time
> job with long hours and frequent travel, so please don't expect support,
> frequent updates, or timely responses to issues or pull requests. It works
> for my own setup; your mileage may vary. Forks and PRs are welcome if you
> want to extend it yourself, but I can't commit to maintaining it actively.

The Windows version lives in its own repo: [HomeLabManagement-Windows](https://github.com/karharry/HomeLabManagement-Windows).

## Features

- **Unified dashboard** across every machine kind, with a sidebar switcher and an
  "All Machines" overview grid
- **TrueNAS**: pools, datasets & snapshots, shares, network, apps, VMs (with live
  per-VM stats), containers, services, fan control (custom curve editor), data
  protection (snapshot tasks/replication/rsync/cloud sync/cron), users, console
- **Linux**: CPU/memory/storage, processes, services, scheduled tasks, logs,
  updates (apt/pacman), users, console — plus auto-detected extras: Pi-hole,
  PiKVM, Tailscale, Raspberry Pi telemetry, Docker containers
- **Windows**: CPU (per-core), GPU (multi-adapter, NVIDIA-aware), hardware
  sensors (via LibreHardwareMonitor), startup items, scheduled tasks, installed
  software, updates, event log, users, console
- **macOS** (as a managed target): power & thermal, startup items, installed
  software, updates (softwareupdate + Homebrew), logs, users, console
- **OPNsense**: CPU/memory/storage, network
  interfaces, services, DHCP leases, static DHCP/DNS host management
  (Dnsmasq), firmware update status — managed over OPNsense's native REST API
  rather than SSH
- **VPN**: WireGuard tunnel management (add/connect/disconnect) on Linux,
  Windows, and macOS targets, plus a containerized option for TrueNAS and
  ProtonVPN CLI assist on Linux — works with any provider that exports a
  standard WireGuard config (ProtonVPN, Mullvad, etc.)
- **RDP / Screen Sharing** quick-connect for Windows and Mac targets
- **Desktop widgets** on macOS (WidgetKit: a selected-machine status widget and
  an all-machines overview widget); the Windows build shows the same
  at-a-glance status from a **system tray icon** instead, since Windows has no
  WidgetKit equivalent
- **Open at Login** / **Open Minimized** options on both platforms (the Mac also has **Open in Menu Bar**)
- **Menu bar item** showing the number of machines and alerts. Closing the
  window keeps the app running there (no Dock icon unless you minimize);
  left-click opens the window, right-click gives Show Window / Preferences /
  Quit. Choose **Open Minimized** or **Open in Menu Bar** as the start mode.
- **History**: CPU, memory and network over the last 24 hours or 7 days, kept
  locally in SQLite (one sample per minute per machine)
- **Notifications** when a machine goes offline, comes back, or raises a new
  alert, with configurable storage / memory / offline thresholds in Settings
- **TLS certificate pinning** (trust on first use) for self-signed
  TrueNAS and OPNsense certificates, like the existing SSH host key pinning
- **Wake-on-LAN**, **Open Web UI**, and **export / import** of your machine
  list (passwords and API secrets are never exported)
- **Update check** against GitHub Releases (File menu → Check for Updates)
- Slower background polling while every window is closed or minimized

## Installation

**Homebrew (recommended):**

```bash
brew tap karharry/homelabmanagement
brew install --cask homelabmanagement
```

**Manual:** download the latest macOS release from the
[Releases](../../releases) page, unzip, and move `HomeLab Management.app` to
`/Applications`.

## What's new

**1.3.0** adds a menu bar item with the machine and alert counts that keeps
the app running after the window is closed, and an **Open in Menu Bar** start
option (mutually exclusive with Open Minimized).

**1.2.0** brought the Mac app up to the Windows build's 1.4.0 feature set:
History page, notifications and alert thresholds, TLS certificate pinning,
Wake-on-LAN, Open Web UI, machine export/import, update check, and slower
polling while hidden. If a self-signed TrueNAS/OPNsense certificate is later
renewed, use **Forget pinned SSH host key / TLS certificate** in that
machine's Edit sheet to trust the new one.

See the [release notes](../../releases) for details.

## Building from source

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen generate
open HomeLabManagement.xcodeproj
```

The project uses [Citadel](https://github.com/orlandos-nl/Citadel) for SSH,
resolved automatically via Swift Package Manager on first build.

## Dependencies

Swift packages, resolved automatically by Swift Package Manager (versions as
pinned in `Package.resolved`):

| Package | Version | Used for |
|---|---|---|
| [Citadel](https://github.com/orlandos-nl/Citadel) | 0.12.1 | SSH client (the only direct dependency, declared in `project.yml`) |
| [swift-nio-ssh](https://github.com/Wellz26/swift-nio-ssh) | 0.3.7 | SSH protocol (via Citadel) |
| [swift-nio](https://github.com/apple/swift-nio) | 2.104.0 | Networking (via Citadel) |
| [swift-crypto](https://github.com/apple/swift-crypto) | 3.15.1 | Cryptography (via Citadel) |
| [BigInt](https://github.com/attaswift/BigInt) | 5.7.0 | Big-integer maths for SSH keys (via Citadel) |
| swift-asn1, swift-atomics, swift-collections, swift-log, swift-system | — | Supporting Apple packages (via Citadel / swift-nio) |

Everything else uses Apple frameworks that ship with macOS: SwiftUI, Swift
Charts, WidgetKit, CryptoKit, UserNotifications, SQLite3, and the Keychain.

Build tooling: Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).
Target machines have their own requirements (e.g. an SSH server) — see the
setup hints in each machine's Add Machine sheet.

## How it works

Most machine kinds are managed over SSH (POSIX shell for Linux/macOS,
PowerShell for Windows), with small scripts collecting system state in a
single round trip. TrueNAS is managed natively over its JSON-RPC-over-WebSocket
API, with SSH as an optional add-on for VM stats, containers, and the console.
Machine configuration (host, port, kind) and credentials are stored locally —
in the macOS Keychain + standard app preferences on the Mac build, in a
`settings.json` file beside the exe on the Windows build (there's no Windows
equivalent of the Keychain, so this is a deliberate, simpler trade-off for a
portable single-file app) — nothing is sent anywhere except directly to the
machines you add.

## License

MIT — see [LICENSE](LICENSE).
