import CoreAudio
import Foundation

final class SystemVolume: VolumeIO {
    private func address(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeOutput, channel: UInt32 = 0) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: channel)
    }
    private func check(_ result: OSStatus) throws {
        guard result == noErr else { throw AudioFailure(message: "Core Audio error \(result)") }
    }
    func read() throws -> VolumeState {
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var route = address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
        try check(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &route, 0, nil, &size, &device))
        guard device != 0 else { throw AudioFailure(message: "No output device") }
        func writable(_ channel: UInt32) -> Bool {
            var a = address(kAudioDevicePropertyVolumeScalar, channel: channel)
            var settable = DarwinBoolean(false)
            return AudioObjectHasProperty(device, &a) && AudioObjectIsPropertySettable(device, &a, &settable) == noErr && settable.boolValue
        }
        var channels: [UInt32] = []
        if writable(0) { channels = [0] }
        else {
            var a = address(kAudioDevicePropertyStreamConfiguration)
            var bytes: UInt32 = 0
            try check(AudioObjectGetPropertyDataSize(device, &a, 0, nil, &bytes))
            guard bytes >= MemoryLayout<AudioBufferList>.size else { throw AudioFailure(message: "No output channels") }
            let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(bytes), alignment: MemoryLayout<AudioBufferList>.alignment)
            defer { raw.deallocate() }
            try check(AudioObjectGetPropertyData(device, &a, 0, nil, &bytes, raw))
            let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
            let count = list.reduce(0) { $0 + Int($1.mNumberChannels) }
            guard count > 0, count <= 128 else { throw AudioFailure(message: "Invalid output channels") }
            channels = (1...UInt32(count)).filter { writable($0) }
            guard channels.count == count else { throw AudioFailure(message: "Output has no complete software volume control") }
        }
        let values: [Float] = try channels.map { channel in
            var a = address(kAudioDevicePropertyVolumeScalar, channel: channel)
            var value: Float = 0; var bytes = UInt32(MemoryLayout<Float>.size)
            try check(AudioObjectGetPropertyData(device, &a, 0, nil, &bytes, &value))
            guard value.isFinite, (0...1).contains(value) else { throw AudioFailure(message: "Invalid output volume") }
            return value
        }
        var muteAddress = address(kAudioDevicePropertyMute)
        var mute: UInt32 = 0; var muteBytes = UInt32(MemoryLayout<UInt32>.size)
        let hasMute = AudioObjectHasProperty(device, &muteAddress)
        if hasMute { try check(AudioObjectGetPropertyData(device, &muteAddress, 0, nil, &muteBytes, &mute)) }
        return VolumeState(device: device, channels: channels, values: values, muted: hasMute ? mute != 0 : nil)
    }
    func write(_ state: VolumeState) throws {
        let current = try read()
        guard current.device == state.device, current.channels == state.channels else { throw AudioFailure(message: "Output device changed") }
        for (channel, value) in zip(state.channels, state.values) {
            var a = address(kAudioDevicePropertyVolumeScalar, channel: channel)
            var value = value
            try check(AudioObjectSetPropertyData(state.device, &a, 0, nil, UInt32(MemoryLayout<Float>.size), &value))
        }
    }
}
