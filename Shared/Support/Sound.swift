// Sound.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Every effect is synthesized into a buffer at first use; there are no audio files.

import AVFoundation

@MainActor
final class Sound {
    enum Effect: CaseIterable {
        case plip
        case chime
        case buzz
    }

    static let shared = Sound()

    private let engine = AVAudioEngine()
    private var players: [Effect: AVAudioPlayerNode] = [:]
    private var buffers: [Effect: AVAudioPCMBuffer] = [:]
    private var isConnected = false

    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: StorageKey.soundOn)
    }

    func play(_ effect: Effect) {
        guard isEnabled, start(), let player = players[effect], let buffer = buffers[effect] else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying {
            player.play()
        }
    }

    func stop() {
        engine.stop()
    }

    private func start() -> Bool {
        if !isConnected {
            guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) else { return false }
            try? AVAudioSession.sharedInstance().setCategory(.ambient)
            for effect in Effect.allCases {
                let player = AVAudioPlayerNode()
                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: format)
                players[effect] = player
                buffers[effect] = Self.synthesize(effect, format: format)
            }
            isConnected = true
        }
        if engine.isRunning { return true }
        do {
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    private static func synthesize(_ effect: Effect, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let rate = format.sampleRate
        let duration = switch effect {
        case .plip: 0.07
        case .chime: 0.4
        case .buzz: 0.3
        }
        let count = AVAudioFrameCount(duration * rate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = count
        var phase = 0.0
        for index in 0..<Int(count) {
            let t = Double(index) / rate
            let attack = min(1, t / 0.004)
            let value: Double
            switch effect {
            case .plip:
                phase += 2 * .pi * 1400 * exp(-t * 10) / rate
                value = 0.22 * attack * exp(-t * 45) * sin(phase)
            case .chime:
                value = 0.18 * attack * exp(-t * 9) * (sin(2 * .pi * 1320 * t) + 0.5 * sin(2 * .pi * 1980 * t)
                                                     + 0.25 * sin(2 * .pi * 2640 * t))
            case .buzz:
                phase += 2 * .pi * (175 + 12 * sin(2 * .pi * 7 * t)) / rate
                let tone = sin(phase) + 0.5 * sin(2 * phase) + 0.3 * sin(3 * phase) + 0.2 * sin(4 * phase)
                let fade = min(1, (duration - t) / 0.05)
                value = 0.1 * attack * fade * (0.7 + 0.3 * sin(2 * .pi * 32 * t)) * tone
            }
            samples[index] = Float(value)
        }
        return buffer
    }
}
