import CoreAudio
import Foundation

@MainActor
final class VolumeController {

    private var lastTickDate: Date = .distantPast
    private let throttleInterval: TimeInterval = 0.08
    private let stepSize: Float = 0.0625  // ~6.25% per tick (1/16)

    func scrollTick(increase: Bool) {
        let now = Date()
        guard now.timeIntervalSince(lastTickDate) >= throttleInterval else { return }
        lastTickDate = now

        guard let deviceID = defaultOutputDevice() else { return }
        var volume = getVolume(deviceID: deviceID)
        volume += increase ? stepSize : -stepSize
        volume = max(0.0, min(1.0, volume))
        setVolume(volume, deviceID: deviceID)
    }

    // MARK: - CoreAudio (modern AudioObject API)

    private func defaultOutputDevice() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    private func getVolume(deviceID: AudioDeviceID) -> Float {
        var volume = Float(0)
        var size = UInt32(MemoryLayout<Float>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
        return volume
    }

    private func setVolume(_ volume: Float, deviceID: AudioDeviceID) {
        var vol = volume
        var size = UInt32(MemoryLayout<Float>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &vol)
    }
}
