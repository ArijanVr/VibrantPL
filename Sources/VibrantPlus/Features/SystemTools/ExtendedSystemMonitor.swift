// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Darwin
import IOKit
import IOKit.ps
import Observation
import UserNotifications
import VibrantPlusKit

@Observable
final class ExtendedSystemMonitor {
    static let shared = ExtendedSystemMonitor()
    struct Sample: Identifiable {
        let date: Date
        let cpu: Double?
        let memoryGB: Double?
        let diskFreeGB: Double?
        let battery: Int?
        let onPower: Bool
        let receivedPerSecond: Double?
        let sentPerSecond: Double?
        let thermal: Int
        var id: Date { date }
    }
    private(set) var history: [Sample] = []
    private(set) var notices: [String] = []
    private(set) var running = false
    private(set) var notificationError: String?
    private(set) var sessionReceived: UInt64 = 0
    private(set) var sessionSent: UInt64 = 0
    private(set) var localAddresses: [String] = []
    private(set) var connectedDevices: [String] = []
    private(set) var remainingMinutes: Int?
    private(set) var processes: [ProcessUsage] = []
    private(set) var compressorShare: Double?
    private(set) var diskReadPerSecond: Double?
    private(set) var diskWritePerSecond: Double?
    private(set) var batteryHealth: Int?
    private(set) var batteryCycles: Int?
    var latest: Sample? { history.last }
    var totalMemoryGB: Double { Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824 }
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var cpuTicks: (busy: UInt64, total: UInt64)?
    @ObservationIgnored private var previousNetwork: (NetworkTotals, Date)?
    @ObservationIgnored private var previousDisk: (NetworkTotals, Date)?
    @ObservationIgnored private var cpuThreshold = SustainedThreshold()
    @ObservationIgnored private var lastAlert: [String: Date] = [:]
    /// Results of the off-main reads, applied on the next tick.
    @ObservationIgnored private var slowTask: Task<Void, Never>?
    @ObservationIgnored private var slowTick = 0
    @ObservationIgnored private var slow: (processes: [ProcessUsage], compressor: Double?)?
    @ObservationIgnored private var diskFreeGB: Double?

    func start() {
        guard !running else { return }
        running = true; sessionReceived = 0; sessionSent = 0; previousNetwork = nil
        preferencesChanged()
    }
    func stop() {
        running = false; timer?.invalidate(); timer = nil; previousNetwork = nil; previousDisk = nil; cpuTicks = nil
        slowTask?.cancel(); slowTask = nil; slow = nil; diskFreeGB = nil
    }
    func preferencesChanged() {
        guard running else { return }
        let p = SystemToolPreferences.shared
        let need = p.monitorCPU || p.monitorMemory || p.monitorDisk || p.monitorNetwork || p.monitorPower || p.alertCPU || p.alertMemory || p.alertDisk || p.alertBattery
        if p.monitorDevices { refreshDevices() } else { connectedDevices = [] }
        if !need { timer?.invalidate(); timer = nil; return }
        if timer == nil {
            timer = Timer.repeating(every: 2) { [weak self] _ in MainActor.assumeIsolated { self?.sample() } }
        }
        sample()
    }
    func sample() {
        guard running else { return }
        let p = SystemToolPreferences.shared, now = Date.now
        refreshSlowValues(p)
        if !p.monitorCPU && !p.alertCPU { cpuTicks = nil }
        let cpu = p.monitorCPU || p.alertCPU ? SystemStats.cpuUsage(&cpuTicks) : nil
        let memory = p.monitorMemory || p.alertMemory ? SystemStats.memoryUsedGB() : nil
        let disk = p.monitorDisk || p.alertDisk ? diskFreeGB : nil
        let battery = p.monitorPower || p.alertBattery ? SystemStats.batteryState().0 : nil
        let power = Self.onExternalPower()
        var incoming: Double?, outgoing: Double?
        if p.monitorNetwork {
            let network = Self.networkCounters()
            localAddresses = network.addresses
            if let previousNetwork {
                let rates = network.totals.rate(since: previousNetwork.0, seconds: now.timeIntervalSince(previousNetwork.1))
                incoming = rates.received; outgoing = rates.sent
                if network.totals.received >= previousNetwork.0.received { sessionReceived += network.totals.received - previousNetwork.0.received }
                if network.totals.sent >= previousNetwork.0.sent { sessionSent += network.totals.sent - previousNetwork.0.sent }
            }
            previousNetwork = (network.totals, now)
        } else { previousNetwork = nil; localAddresses = [] }
        if p.monitorMemory {
            processes = slow?.processes ?? processes
            compressorShare = slow?.compressor ?? compressorShare
        } else { processes = []; compressorShare = nil }
        if p.monitorDisk {
            let io = Self.diskIO()
            if let previousDisk {
                let rates = io.rate(since: previousDisk.0, seconds: now.timeIntervalSince(previousDisk.1))
                diskReadPerSecond = rates.received
                diskWritePerSecond = rates.sent
            }
            previousDisk = (io, now)
        } else { previousDisk = nil; diskReadPerSecond = nil; diskWritePerSecond = nil }
        if p.monitorPower {
            let health = SystemStats.batteryHealth()
            batteryHealth = health.percent
            batteryCycles = health.cycles
        } else { batteryHealth = nil; batteryCycles = nil }
        let estimate = IOPSGetTimeRemainingEstimate()
        remainingMinutes = estimate > 0 && estimate.isFinite ? Int(estimate / 60) : nil
        let sample = Sample(date: now, cpu: cpu, memoryGB: memory, diskFreeGB: disk, battery: battery,
                            onPower: power, receivedPerSecond: incoming, sentPerSecond: outgoing,
                            thermal: ProcessInfo.processInfo.thermalState.rawValue)
        history.append(sample)
        if history.count > 180 { history.removeFirst(history.count - 180) }
        checkAlerts(sample)
    }

    /// Free space, the process list and the compressor share are read off the main thread.
    /// The volume query wakes CacheDelete, and the process sweep asks the kernel about every
    /// process on the Mac. Both ran here every two seconds and made the app feel dead while
    /// the monitor was on: late hot keys, a frozen island, audio dropouts. The values are one
    /// tick old, which nobody sees in a system monitor.
    private func refreshSlowValues(_ p: SystemToolPreferences) {
        guard slowTask == nil else { return }
        let wantProcesses = p.monitorMemory
        let wantDisk = p.monitorDisk || p.alertDisk
        guard wantProcesses || wantDisk else { return }
        slowTick += 1
        // The sweep is by far the most expensive read; every fourth tick is enough for a
        // list of the heaviest processes.
        let sweep = wantProcesses && slowTick % 4 == 1
        slowTask = Task.detached(priority: .utility) {
            let processes = sweep ? ProcessSnapshot.heaviest(limit: 8, excluding: getpid()) : []
            let compressor = sweep ? SystemStats.compressorShare() : nil
            let disk = wantDisk ? (try? URL(fileURLWithPath: "/")
                .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                .volumeAvailableCapacityForImportantUsage).map { Double($0) / 1_000_000_000 } : nil
            await MainActor.run {
                if sweep { self.slow = (processes, compressor) }
                if let disk { self.diskFreeGB = disk }
                self.slowTask = nil
            }
        }
    }

    private func checkAlerts(_ value: Sample) {
        let p = SystemToolPreferences.shared
        let highCPU = cpuThreshold.evaluate(exceeded: p.alertCPU && (value.cpu ?? 0) > 0.9, now: value.date, duration: 20)
        var next: [String] = []
        if highCPU { next.append("CPU seit mindestens 20 Sekunden über 90 %") }
        if p.alertMemory, (value.memoryGB ?? 0) / max(1, totalMemoryGB) > 0.9 { next.append("Mehr als 90 % des Arbeitsspeichers belegt") }
        if p.alertDisk, let free = value.diskFreeGB, free < 10 { next.append("Weniger als 10 GB auf dem Startvolume frei") }
        if p.alertBattery, let battery = value.battery, battery <= 15, !value.onPower { next.append("Akku bei \(battery) %") }
        notices = next
        for text in next where lastAlert[text].map({ value.date.timeIntervalSince($0) >= 300 }) ?? true {
            lastAlert[text] = value.date
            IslandModel.shared.show(Toast(symbol: "exclamationmark.triangle", text: text, warm: true), seconds: 6)
            if p.notify {
                let content = UNMutableNotificationContent()
                content.title = "Vibrant+ · Systemmonitor"; content.body = text; content.sound = .default
                UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "vibrant-health-" + text, content: content, trigger: nil)) { @Sendable [weak self] error in
                    guard error != nil else { return }
                    Task { @MainActor in self?.notificationError = "Die Systemmitteilung konnte nicht zugestellt werden. Prüfe die Mitteilungsfreigabe." }
                }
            }
        }
    }
    func refreshDevices() {
        guard running, SystemToolPreferences.shared.monitorDevices else { return }
        var names = NSScreen.screens.map { "Bildschirm · " + $0.localizedName }
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey, .volumeIsEjectableKey]
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: .skipHiddenVolumes) ?? []
        for volume in volumes {
            guard let values = try? volume.resourceValues(forKeys: Set(keys)), values.volumeIsRemovable == true || values.volumeIsEjectable == true else { continue }
            names.append("Datenträger · " + (values.volumeName ?? volume.lastPathComponent))
        }
        var iterator: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOUSBHostDevice"), &iterator) == KERN_SUCCESS {
            defer { IOObjectRelease(iterator) }
            var device = IOIteratorNext(iterator)
            while device != 0 {
                let name = IORegistryEntryCreateCFProperty(device, "USB Product Name" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
                if let name { names.append("USB · " + name) }
                IOObjectRelease(device)
                device = IOIteratorNext(iterator)
            }
        }
        connectedDevices = names.sorted()
    }
    nonisolated static func diskIO() -> NetworkTotals {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) == KERN_SUCCESS else {
            return NetworkTotals(received: 0, sent: 0)
        }
        defer { IOObjectRelease(iterator) }
        var read: UInt64 = 0, write: UInt64 = 0
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service); service = IOIteratorNext(iterator) }
            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = props?.takeRetainedValue() as? [String: Any],
                  let stats = dict["Statistics"] as? [String: Any] else { continue }
            read += (stats["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
            write += (stats["Bytes (Written)"] as? NSNumber)?.uint64Value ?? 0
        }
        return NetworkTotals(received: read, sent: write)
    }
    nonisolated static func onExternalPower() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else { return false }
        return type as String == kIOPSACPowerValue
    }
    nonisolated static func networkCounters() -> (totals: NetworkTotals, addresses: [String]) {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return (NetworkTotals(received: 0, sent: 0), []) }
        defer { freeifaddrs(list) }
        var received: UInt64 = 0, sent: UInt64 = 0, addresses: Set<String> = []
        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let item = current {
            defer { current = item.pointee.ifa_next }
            let interface = item.pointee
            guard interface.ifa_flags & UInt32(IFF_LOOPBACK) == 0, interface.ifa_flags & UInt32(IFF_UP) != 0,
                  let address = interface.ifa_addr else { continue }
            if address.pointee.sa_family == UInt8(AF_INET) || address.pointee.sa_family == UInt8(AF_INET6) {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                    addresses.insert(String(decoding: host.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self))
                }
            }
        }
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var size = 0
        if sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0, size > 0 {
            var bytes = [UInt8](repeating: 0, count: size)
            if sysctl(&mib, u_int(mib.count), &bytes, &size, nil, 0) == 0 {
                bytes.withUnsafeBytes { buffer in
                    var offset = 0
                    while offset + MemoryLayout<if_msghdr2>.size <= size {
                        let message = buffer.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                        let length = Int(message.ifm_msglen)
                        guard length > 0, offset + length <= size else { break }
                        if message.ifm_type == RTM_IFINFO2, message.ifm_flags & IFF_LOOPBACK == 0 {
                            received += message.ifm_data.ifi_ibytes
                            sent += message.ifm_data.ifi_obytes
                        }
                        offset += length
                    }
                }
            }
        }
        return (NetworkTotals(received: received, sent: sent), addresses.sorted())
    }
}
