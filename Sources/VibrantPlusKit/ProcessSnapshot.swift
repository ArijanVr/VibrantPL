// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Darwin
import Foundation

public struct ProcessUsage: Sendable, Equatable, Identifiable {
    public var pid: Int32
    public var name: String
    public var memoryBytes: UInt64
    public var id: Int32 { pid }
    public init(pid: Int32, name: String, memoryBytes: UInt64) {
        self.pid = pid; self.name = name; self.memoryBytes = memoryBytes
    }
}

/// Resident size of running processes via libproc. No private sysctl keys.
public enum ProcessSnapshot {
    public static func heaviest(limit: Int, excluding skip: pid_t = 0) -> [ProcessUsage] {
        let bytesNeeded = proc_listallpids(nil, 0)
        guard bytesNeeded > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: max(1, Int(bytesNeeded) / MemoryLayout<pid_t>.size))
        let filled = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.stride * pids.count))
        guard filled > 0 else { return [] }
        var rows: [ProcessUsage] = []
        let cap = min(Int(filled), pids.count)
        for i in 0..<cap {
            let process = pids[i]
            if process <= 0 || process == skip { continue }
            var info = proc_taskinfo()
            let got = proc_pidinfo(process, PROC_PIDTASKINFO, 0, &info, Int32(MemoryLayout<proc_taskinfo>.size))
            guard got >= Int32(MemoryLayout<proc_taskinfo>.size) else { continue }
            var path = [CChar](repeating: 0, count: 4_096)
            guard proc_pidpath(process, &path, 4_096) > 0 else { continue }
            let name = URL(fileURLWithPath: String(decoding: path.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)).lastPathComponent
            guard !name.isEmpty else { continue }
            rows.append(ProcessUsage(pid: process, name: name, memoryBytes: UInt64(info.pti_resident_size)))
        }
        rows.sort { $0.memoryBytes > $1.memoryBytes }
        return Array(rows.prefix(max(0, limit)))
    }
}

public enum MemoryPressurePlan {
    /// Share of used pages that sit in the compressor. 0…1.
    public static func compressorShare(compressor: UInt64, wired: UInt64, internalPages: UInt64) -> Double {
        let used = compressor + wired + internalPages
        guard used > 0 else { return 0 }
        return min(1, Double(compressor) / Double(used))
    }
}

public enum BatteryHealthPlan {
    public static func percent(maxCapacity: Int?, designCapacity: Int?) -> Int? {
        guard let maxCapacity, let designCapacity, designCapacity > 0, maxCapacity >= 0 else { return nil }
        return min(100, Int((Double(maxCapacity) / Double(designCapacity) * 100).rounded()))
    }
}

public enum ZoomPlan {
    /// Top-left display-local rectangle covering `fraction` of the display, centred on `mouse`.
    public static func sourceRect(display: CGRect, mouse: CGPoint, fraction: CGFloat = 0.5) -> CGRect {
        let f = min(1, max(0.2, fraction.isFinite ? fraction : 0.5))
        let w = display.width * f, h = display.height * f
        let local = CGPoint(x: mouse.x - display.minX, y: display.maxY - mouse.y)
        let x = min(max(0, local.x - w / 2), max(0, display.width - w))
        let y = min(max(0, local.y - h / 2), max(0, display.height - h))
        return CGRect(x: x, y: y, width: max(2, w), height: max(2, h))
    }
}

public enum TiltWheel {
    /// Discrete mouse tilt (axis 2), not a trackpad. −1 left, 1 right, 0 none.
    public static func direction(vertical: Double, horizontal: Double, continuous: Bool) -> Int {
        guard !continuous, abs(horizontal) > abs(vertical), abs(horizontal) >= 1 else { return 0 }
        return horizontal > 0 ? 1 : -1
    }
}
