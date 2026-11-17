// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreAudio
import Observation

@Observable
final class AudioDevices {
    static let shared = AudioDevices()
    struct Device: Identifiable { let id: AudioObjectID; let name: String; let uid: String?; let input: Bool; let output: Bool }
    private(set) var devices: [Device] = []
    private(set) var message: String?
    private(set) var inputLevel: Float = 0
    private(set) var inputMuted = false
    private(set) var selectedInput: AudioObjectID = 0
    private(set) var selectedOutput: AudioObjectID = 0

    func refresh() {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else { return }
        devices = ids.compactMap { id in
            var nameAddress = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            let name = UnsafeMutablePointer<Unmanaged<CFString>?>.allocate(capacity: 1)
            name.initialize(to: nil)
            defer { name.deinitialize(count: 1); name.deallocate() }
            var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(id, &nameAddress, 0, nil, &nameSize, name) == noErr,
                  let value = name.pointee?.takeRetainedValue() else { return nil }
            return Device(id: id, name: value as String, uid: SystemVolume.deviceUID(id),
                          input: Self.hasStreams(id, scope: kAudioDevicePropertyScopeInput),
                          output: Self.hasStreams(id, scope: kAudioDevicePropertyScopeOutput))
        }
        selectedInput = Self.defaultDevice(kAudioHardwarePropertyDefaultInputDevice)
        selectedOutput = Self.defaultDevice(kAudioHardwarePropertyDefaultOutputDevice)
        inputLevel = readInput(kAudioDevicePropertyVolumeScalar, as: Float32(0)) ?? 0
        inputMuted = (readInput(kAudioDevicePropertyMute, as: UInt32(0)) ?? 0) != 0
    }
    var canSetInputLevel: Bool { canSetInput(kAudioDevicePropertyVolumeScalar) }
    var canMuteInput: Bool { canSetInput(kAudioDevicePropertyMute) }
    func selectInput(_ id: AudioObjectID) { select(id, selector: kAudioHardwarePropertyDefaultInputDevice) }
    func selectOutput(_ id: AudioObjectID) { select(id, selector: kAudioHardwarePropertyDefaultOutputDevice) }
    private func select(_ id: AudioObjectID, selector: AudioObjectPropertySelector) {
        var id = id
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        let result = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, UInt32(MemoryLayout<AudioObjectID>.size), &id)
        message = result == noErr ? nil : "Das Audiogerät konnte nicht umgeschaltet werden (\(result))."
        refresh()
    }
    func setLevel(_ value: Float) { writeInput(kAudioDevicePropertyVolumeScalar, value: max(0, min(1, value))) }
    func setMuted(_ value: Bool) { writeInput(kAudioDevicePropertyMute, value: UInt32(value ? 1 : 0)) }
    private func inputAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
        if !AudioObjectHasProperty(selectedInput, &address) { address.mElement = 1 }
        return address
    }
    private func canSetInput(_ selector: AudioObjectPropertySelector) -> Bool {
        var address = inputAddress(selector), settable = DarwinBoolean(false)
        return selectedInput != 0 && AudioObjectIsPropertySettable(selectedInput, &address, &settable) == noErr && settable.boolValue
    }
    private func readInput<T>(_ selector: AudioObjectPropertySelector, as initial: T) -> T? {
        var address = inputAddress(selector), size = UInt32(MemoryLayout<T>.size)
        let value = UnsafeMutablePointer<T>.allocate(capacity: 1)
        value.initialize(to: initial)
        defer { value.deinitialize(count: 1); value.deallocate() }
        guard selectedInput != 0, AudioObjectGetPropertyData(selectedInput, &address, 0, nil, &size, value) == noErr else { return nil }
        return value.pointee
    }
    private func writeInput<T>(_ selector: AudioObjectPropertySelector, value: T) {
        guard canSetInput(selector) else { message = "Dieses Mikrofon bietet keinen Hardware-Regler dafür."; return }
        var address = inputAddress(selector)
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        pointer.initialize(to: value)
        defer { pointer.deinitialize(count: 1); pointer.deallocate() }
        let result = AudioObjectSetPropertyData(selectedInput, &address, 0, nil, UInt32(MemoryLayout<T>.size), pointer)
        message = result == noErr ? nil : "Der Mikrofonregler konnte nicht gesetzt werden (\(result))."
        refresh()
    }
    private static func defaultDevice(_ selector: AudioObjectPropertySelector) -> AudioObjectID {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var result = AudioObjectID(0), size = UInt32(MemoryLayout<AudioObjectID>.size)
        _ = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &result)
        return result
    }
    private static func hasStreams(_ id: AudioObjectID, scope: AudioObjectPropertyScope) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
    }
}
