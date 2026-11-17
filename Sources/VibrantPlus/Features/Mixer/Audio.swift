// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import AudioToolbox
import CoreAudio
import Observation
import VibrantPlusKit

/// The Mac's output volume through Core Audio (public API).
nonisolated enum SystemVolume {
    static func defaultOutputDevice() -> AudioObjectID? {
        var id = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id) == noErr, id != 0 else { return nil }
        return id
    }

    private static var volumeAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                                   mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
    }

    static func volume() -> Float? {
        guard let dev = defaultOutputDevice() else { return nil }
        var addr = volumeAddress
        var v = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &v) == noErr else { return nil }
        return v
    }

    @discardableResult
    static func setVolume(_ value: Float) -> Bool {
        guard let dev = defaultOutputDevice() else { return false }
        var addr = volumeAddress
        var v = Float32(max(0, min(1, value)))
        return AudioObjectSetPropertyData(dev, &addr, 0, nil, UInt32(MemoryLayout<Float32>.size), &v) == noErr
    }

    static func isMuted() -> Bool {
        guard let dev = defaultOutputDevice() else { return false }
        var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeOutput,
                                              mElement: kAudioObjectPropertyElementMain)
        var m = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &m) == noErr else { return false }
        return m != 0
    }

    @discardableResult
    static func setMuted(_ on: Bool) -> Bool {
        guard let dev = defaultOutputDevice() else { return false }
        var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeOutput,
                                              mElement: kAudioObjectPropertyElementMain)
        var m = UInt32(on ? 1 : 0)
        return AudioObjectSetPropertyData(dev, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &m) == noErr
    }

    static func deviceUID(_ id: AudioObjectID) -> String? {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var uid: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &uid) == noErr, let u = uid else { return nil }
        return u.takeRetainedValue() as String
    }

    static func deviceID(uid: String) -> AudioObjectID? {
        guard let wanted = MixerPlan.storedOutput(uid) else { return nil }
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr else { return nil }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr else { return nil }
        return ids.first { deviceUID($0) == wanted }
    }
}

/// An app that currently plays sound, as Core Audio sees it.
struct AudioApp: Identifiable, Equatable {
    var id: AudioObjectID       // the Core Audio process object
    var pid: pid_t
    var name: String
    var bundleID: String?
    var icon: NSImage?

    static func == (a: AudioApp, b: AudioApp) -> Bool { a.id == b.id }
}

/// Per-app volume and output with Core Audio process taps (macOS 14.2+, public API).
/// Vibrant+ taps the app (muting the original) and plays it back through a private
/// aggregate device at the chosen level and output. Nothing is recorded or saved.
@Observable
final class AppMixer {
    static let shared = AppMixer()

    private(set) var apps: [AudioApp] = []
    private(set) var levels: [pid_t: Float] = [:]
    private(set) var outputs: [pid_t: String] = [:]
    private(set) var error: String?
    @ObservationIgnored private var taps: [pid_t: ProcessTap] = [:]

    func refresh() {
        apps = Self.playingProcesses()
        let memory = Prefs.shared.mixerMemory
        for app in apps {
            if let bid = app.bundleID {
                if let stored = memory.gains[bid] { levels[app.pid] = MixerPlan.clampedGain(stored) }
                if let uid = MixerPlan.storedOutput(memory.outputs[bid]) { outputs[app.pid] = uid }
            }
            syncTap(app)
        }
        for (pid, tap) in taps where !apps.contains(where: { $0.pid == pid }) {
            tap.stop()
            taps[pid] = nil
            levels[pid] = nil
            outputs[pid] = nil
        }
    }

    func level(of app: AudioApp) -> Float { levels[app.pid] ?? 1 }
    func output(of app: AudioApp) -> String? { MixerPlan.storedOutput(outputs[app.pid]) }
    func isFavorite(_ app: AudioApp) -> Bool {
        guard let bid = app.bundleID else { return false }
        return Prefs.shared.mixerMemory.favorites.contains(bid)
    }

    func setLevel(_ value: Float, for app: AudioApp) {
        let gain = MixerPlan.clampedGain(value)
        levels[app.pid] = gain
        if let bid = app.bundleID, !bid.isEmpty {
            var memory = Prefs.shared.mixerMemory
            memory.gains[bid] = gain
            Prefs.shared.mixerMemory = memory
        }
        syncTap(app)
    }

    func setOutput(_ uid: String?, for app: AudioApp) {
        let stored = MixerPlan.storedOutput(uid)
        if let stored { outputs[app.pid] = stored } else { outputs[app.pid] = nil }
        if let bid = app.bundleID, !bid.isEmpty {
            var memory = Prefs.shared.mixerMemory
            memory.outputs[bid] = stored
            Prefs.shared.mixerMemory = memory
        }
        syncTap(app)
    }

    func toggleFavorite(_ app: AudioApp) {
        guard let bid = app.bundleID, !bid.isEmpty else { return }
        var memory = MixerPlan.togglingFavorite(bid, in: Prefs.shared.mixerMemory)
        if memory.favorites.contains(bid) {
            memory.gains[bid] = level(of: app)
            if let uid = output(of: app) { memory.outputs[bid] = uid }
        }
        Prefs.shared.mixerMemory = memory
    }

    func resetAll() {
        for (_, t) in taps { t.stop() }
        taps = [:]
        levels = [:]
        outputs = [:]
    }

    private func syncTap(_ app: AudioApp) {
        let gain = level(of: app)
        let uid = output(of: app)
        guard MixerPlan.needsTap(gain: gain, outputUID: uid) else {
            taps[app.pid]?.stop()
            taps[app.pid] = nil
            return
        }
        if let tap = taps[app.pid], tap.routedUID == uid {
            tap.gain = gain
            return
        }
        taps[app.pid]?.stop()
        taps[app.pid] = nil
        do {
            taps[app.pid] = try ProcessTap(processObject: app.id, gain: gain, outputUID: uid)
            error = nil
        } catch {
            self.error = "Lautstärke und Routing pro App brauchen die Erlaubnis «Systemaudio-Aufnahme»."
        }
    }

    nonisolated static func playingProcesses() -> [AudioApp] {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList,
                                              mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr else { return [] }
        let me = getpid()
        return ids.compactMap { id -> AudioApp? in
            guard let running: UInt32 = read(id, kAudioProcessPropertyIsRunningOutput), running != 0,
                  let pid: pid_t = read(id, kAudioProcessPropertyPID), pid != me else { return nil }
            let app = NSRunningApplication(processIdentifier: pid)
            // Helper processes (e.g. a browser's audio service) show under their parent app's name when possible.
            let name = app?.localizedName ?? "Prozess \(pid)"
            return AudioApp(id: id, pid: pid, name: name, bundleID: app?.bundleIdentifier, icon: app?.icon)
        }
    }

    nonisolated private static func read<T>(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> T? {
        var addr = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<T>.size)
        let ptr = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { ptr.deallocate() }
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, ptr) == noErr else { return nil }
        return ptr.pointee
    }
}

/// One tap + private aggregate device + IO proc that copies the tapped audio
/// to the output, multiplied by `gain`.
nonisolated final class ProcessTap {
    enum Failure: Error { case tap(OSStatus), aggregate(OSStatus), ioProc(OSStatus), noOutput }

    private var tapID = AudioObjectID(0)
    private var aggregateID = AudioObjectID(0)
    private var procID: AudioDeviceIOProcID?
    /// Read on the real-time audio thread; a plain Float store is atomic on arm64.
    private let gainBox = UnsafeMutablePointer<Float>.allocate(capacity: 1)
    private let queue = DispatchQueue(label: "Vibrant+ mixer", qos: .userInteractive)
    /// The output this tap plays into; compared when the person picks another device.
    let routedUID: String?

    var gain: Float {
        get { gainBox.pointee }
        set { gainBox.pointee = MixerPlan.clampedGain(newValue) }
    }

    init(processObject: AudioObjectID, gain: Float, outputUID: String? = nil) throws {
        let chosen = MixerPlan.storedOutput(outputUID)
        routedUID = chosen
        gainBox.initialize(to: MixerPlan.clampedGain(gain))
        let desc = CATapDescription(stereoMixdownOfProcesses: [processObject])
        desc.uuid = UUID()
        desc.muteBehavior = .mutedWhenTapped
        desc.isPrivate = true
        desc.name = "Vibrant+ Mixer"
        var status = AudioHardwareCreateProcessTap(desc, &tapID)
        guard status == noErr else { throw Failure.tap(status) }

        let outUID: String
        if let chosen, SystemVolume.deviceID(uid: chosen) != nil {
            outUID = chosen
        } else if let out = SystemVolume.defaultOutputDevice(), let uid = SystemVolume.deviceUID(out) {
            outUID = uid
        } else {
            AudioHardwareDestroyProcessTap(tapID)
            throw Failure.noOutput
        }
        let dict: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Vibrant+ Mixer",
            kAudioAggregateDeviceUIDKey: "ch.arjo.vibrantplus.mixer.\(UUID().uuidString)",
            kAudioAggregateDeviceMainSubDeviceKey: outUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outUID]],
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapDriftCompensationKey: true,
                                               kAudioSubTapUIDKey: desc.uuid.uuidString]],
        ]
        status = AudioHardwareCreateAggregateDevice(dict as CFDictionary, &aggregateID)
        guard status == noErr else {
            AudioHardwareDestroyProcessTap(tapID)
            throw Failure.aggregate(status)
        }
        let box = gainBox
        status = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue) { _, input, _, output, _ in
            let g = box.pointee
            let inList = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
            let outList = UnsafeMutableAudioBufferListPointer(output)
            for (i, out) in outList.enumerated() {
                guard let dst = out.mData?.assumingMemoryBound(to: Float.self) else { continue }
                let count = Int(out.mDataByteSize) / MemoryLayout<Float>.size
                guard inList.count > 0 else { memset(dst, 0, Int(out.mDataByteSize)); continue }
                let src = inList[min(i, inList.count - 1)]
                guard let s = src.mData?.assumingMemoryBound(to: Float.self) else { memset(dst, 0, Int(out.mDataByteSize)); continue }
                let n = min(count, Int(src.mDataByteSize) / MemoryLayout<Float>.size)
                for k in 0..<n { dst[k] = s[k] * g }
                if n < count { memset(dst.advanced(by: n), 0, (count - n) * MemoryLayout<Float>.size) }
            }
        }
        guard status == noErr, let procID else {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            AudioHardwareDestroyProcessTap(tapID)
            throw Failure.ioProc(status)
        }
        status = AudioDeviceStart(aggregateID, procID)
        guard status == noErr else {
            stop()
            throw Failure.ioProc(status)
        }
    }

    func stop() {
        if aggregateID != 0 {
            if let procID {
                AudioDeviceStop(aggregateID, procID)
                AudioDeviceDestroyIOProcID(aggregateID, procID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = 0
        }
        if tapID != 0 {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = 0
        }
        procID = nil
    }

    deinit {
        stop()
        gainBox.deallocate()
    }
}
