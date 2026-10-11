import AVFoundation
import Foundation

/// Keeps the app alive in the background while connected to CarPlay or when the iPhone screen is locked,
/// using a silent audio loop with `.mixWithOthers` so Spotify / Apple Music are never interrupted.
public final class BackgroundAudioKeepAlive {
    public static let shared = BackgroundAudioKeepAlive()
    private var audioPlayer: AVAudioPlayer?

    private init() {}

    public func start() {
        guard audioPlayer == nil || audioPlayer?.isPlaying == false else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            let silentWavData = Self.makeSilentWAVData()
            let player = try AVAudioPlayer(data: silentWavData)
            player.numberOfLoops = -1
            player.volume = 0.0
            player.prepareToPlay()
            player.play()
            self.audioPlayer = player
        } catch {
            print("BackgroundAudioKeepAlive error: \(error.localizedDescription)")
        }
    }

    public func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    /// Generates a valid 1-second 8kHz 16-bit mono PCM silent WAV file in memory.
    private static func makeSilentWAVData() -> Data {
        let sampleRate: UInt32 = 8000
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate: UInt32 = sampleRate * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign: UInt16 = numChannels * (bitsPerSample / 8)
        let dataSize: UInt32 = sampleRate * UInt32(blockAlign) // 1 second of silence
        let chunkSize: UInt32 = 36 + dataSize

        var data = Data()
        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        let subchunk1Size: UInt32 = 16
        let audioFormat: UInt16 = 1 // PCM
        data.append(contentsOf: withUnsafeBytes(of: subchunk1Size.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: audioFormat.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        data.append(Data(count: Int(dataSize)))
        return data
    }
}
