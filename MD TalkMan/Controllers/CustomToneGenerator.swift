//
//  CustomToneGenerator.swift
//  MD TalkMan
//
//  Created by Claude on 8/28/25.
//

import AVFoundation
import Foundation

// MARK: - Envelope Types
enum EnvelopeType {
    case gentle
    case sharp
    case sustained
    
    func amplitude(at time: Float, duration: Float) -> Float {
        switch self {
        case .gentle:
            let attack = duration * 0.15    // 15% attack
            let release = duration * 0.4    // 40% release
            
            if time < attack {
                return time / attack  // Fade in
            } else if time > duration - release {
                return (duration - time) / release  // Fade out
            } else {
                return 1.0  // Sustain
            }
            
        case .sharp:
            let attack = duration * 0.05    // 5% attack (quick)
            let release = duration * 0.6    // 60% release (long fade)
            
            if time < attack {
                return time / attack
            } else if time > duration - release {
                return (duration - time) / release
            } else {
                return 1.0
            }
            
        case .sustained:
            let attack = duration * 0.1     // 10% attack
            let release = duration * 0.2    // 20% release
            
            if time < attack {
                return time / attack
            } else if time > duration - release {
                return (duration - time) / release
            } else {
                return 1.0  // Longer sustain
            }
        }
    }
}

// MARK: - Tone Definition
struct ToneDefinition {
    let frequencies: [Float]
    let durations: [Float]
    let envelope: EnvelopeType
    let volume: Float
    
    init(frequencies: [Float], durations: [Float], envelope: EnvelopeType = .gentle, volume: Float = 0.3) {
        self.frequencies = frequencies
        self.durations = durations
        self.envelope = envelope
        self.volume = volume
    }
    
    init(frequency: Float, duration: Float, envelope: EnvelopeType = .gentle, volume: Float = 0.3) {
        self.frequencies = [frequency]
        self.durations = [duration]
        self.envelope = envelope
        self.volume = volume
    }
}

// MARK: - Custom Tone Generator
class CustomToneGenerator {
    
    // MARK: - Properties
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private let masterVolume: Float
    
    // Musical frequencies (Hz) - Equal temperament tuning
    private struct MusicalNotes {
        static let C3: Float = 130.81
        static let C4: Float = 261.63
        static let E4: Float = 329.63
        static let F4: Float = 349.23
        static let G4: Float = 392.00
        static let A4: Float = 440.00
        static let C5: Float = 523.25
    }
    
    // MARK: - Initialization
    init(volume: Float = 0.7) {
        self.masterVolume = max(0.0, min(1.0, volume))
        setupAudioEngine()
    }
    
    deinit {
        stopAudioEngine()
    }
    
    // MARK: - Audio Engine Setup
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        guard let engine = audioEngine, let player = playerNode else { return }
        
        engine.attach(player)
        engine.connect(player, to: engine.outputNode, format: nil)
        
        do {
            try engine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    private func stopAudioEngine() {
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
    }
    
    // MARK: - Tone Generation
    func playTone(_ definition: ToneDefinition, completion: (() -> Void)? = nil) {
        guard let engine = audioEngine, let player = playerNode else {
            print("CustomToneGenerator: Audio engine or player node is nil")
            completion?()
            return
        }
        
        // Ensure engine is running before attempting to play
        if !engine.isRunning {
            do {
                try engine.start()
                print("CustomToneGenerator: Restarted audio engine")
            } catch {
                print("CustomToneGenerator: Failed to restart audio engine: \(error)")
                completion?()
                return
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion?() }
                return
            }
            
            let totalDuration = definition.durations.reduce(0, +)
            var currentTime: Float = 0
            
            for (index, frequency) in definition.frequencies.enumerated() {
                guard index < definition.durations.count else { break }
                
                let duration = definition.durations[index]
                let buffer = self.createToneBuffer(
                    frequency: frequency,
                    duration: duration,
                    envelope: definition.envelope,
                    volume: definition.volume * self.masterVolume
                )
                
                if let buffer = buffer {
                    let delay = currentTime
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(delay)) {
                        // Double-check engine is still running before playing
                        guard let engine = self.audioEngine, engine.isRunning else {
                            print("CustomToneGenerator: Engine stopped, skipping buffer playback")
                            return
                        }
                        
                        player.scheduleBuffer(buffer, completionHandler: nil)
                        if !player.isPlaying {
                            do {
                                player.play()
                            } catch {
                                print("CustomToneGenerator: Player.play() failed: \(error)")
                            }
                        }
                    }
                }
                
                currentTime += duration + 0.05  // Small gap between notes
            }
            
            // Call completion after all notes finish
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(totalDuration + currentTime)) {
                completion?()
            }
        }
    }
    
    private func createToneBuffer(frequency: Float, duration: Float, envelope: EnvelopeType, volume: Float) -> AVAudioPCMBuffer? {
        guard let engine = audioEngine else { return nil }
        
        let sampleRate = Float(engine.outputNode.outputFormat(forBus: 0).sampleRate)
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: engine.outputNode.outputFormat(forBus: 0),
            frameCapacity: frameCount
        ) else { return nil }
        
        buffer.frameLength = frameCount
        guard let samples = buffer.floatChannelData?[0] else { return nil }
        
        for i in 0..<Int(frameCount) {
            let time = Float(i) / sampleRate
            let amplitude = envelope.amplitude(at: time, duration: duration)
            let sample = sin(2.0 * Float.pi * frequency * time) * amplitude * volume
            samples[i] = sample
        }
        
        return buffer
    }
    
    // MARK: - Predefined Tones
    
    /// Pleasant ascending tone for playback start
    func playStartTone(completion: (() -> Void)? = nil) {
        let tone = ToneDefinition(
            frequencies: [MusicalNotes.C4, MusicalNotes.E4],
            durations: [0.15, 0.25],
            envelope: .gentle,
            volume: 0.35
        )
        playTone(tone, completion: completion)
    }
    
    /// Single sustained tone for pause
    func playPauseTone(completion: (() -> Void)? = nil) {
        let tone = ToneDefinition(
            frequency: MusicalNotes.E4,
            duration: 0.3,
            envelope: .sustained,
            volume: 0.3
        )
        playTone(tone, completion: completion)
    }
    
    /// Descending tone for stop/completion
    func playStopTone(completion: (() -> Void)? = nil) {
        let tone = ToneDefinition(
            frequencies: [MusicalNotes.E4, MusicalNotes.C4],
            durations: [0.12, 0.2],
            envelope: .gentle,
            volume: 0.32
        )
        playTone(tone, completion: completion)
    }
    
    /// Completion tone (more triumphant)
    func playCompletionTone(completion: (() -> Void)? = nil) {
        let tone = ToneDefinition(
            frequencies: [MusicalNotes.C4, MusicalNotes.E4, MusicalNotes.G4],
            durations: [0.15, 0.15, 0.3],
            envelope: .gentle,
            volume: 0.4
        )
        playTone(tone, completion: completion)
    }
    
    /// Navigation/section change tone
    func playNavigationTone(completion: (() -> Void)? = nil) {
        let tone = ToneDefinition(
            frequencies: [MusicalNotes.F4, MusicalNotes.A4],
            durations: [0.12, 0.18],
            envelope: .sharp,
            volume: 0.25
        )
        playTone(tone, completion: completion)
    }
    
    /// Voice/settings change tone
    func playSettingsChangeTone(completion: (() -> Void)? = nil) {
        let tone = ToneDefinition(
            frequency: MusicalNotes.G4,
            duration: 0.15,
            envelope: .sharp,
            volume: 0.2
        )
        playTone(tone, completion: completion)
    }
    
    /// Error/alert tone (lower frequency, more attention-getting)
    func playErrorTone(completion: (() -> Void)? = nil) {
        let tone = ToneDefinition(
            frequencies: [MusicalNotes.C3, MusicalNotes.C3],
            durations: [0.2, 0.2],
            envelope: .sustained,
            volume: 0.4
        )
        playTone(tone, completion: completion)
    }
    
    /// Button tap tone (very brief)
    func playButtonTapTone(completion: (() -> Void)? = nil) {
        let tone = ToneDefinition(
            frequency: MusicalNotes.C4,
            duration: 0.08,
            envelope: .sharp,
            volume: 0.15
        )
        playTone(tone, completion: completion)
    }
    
    /// Code block start - distinctive ascending pattern
    func playCodeBlockStartTone(completion: (() -> Void)? = nil) {
        let tone = ToneDefinition(
            frequencies: [MusicalNotes.C4, MusicalNotes.A4, MusicalNotes.C5],
            durations: [0.12, 0.12, 0.16],
            envelope: .sharp,
            volume: 0.28
        )
        playTone(tone, completion: completion)
    }
    
    /// Code block end - mirror of start (descending)
    func playCodeBlockEndTone(completion: (() -> Void)? = nil) {
        let tone = ToneDefinition(
            frequencies: [MusicalNotes.C5, MusicalNotes.A4, MusicalNotes.C4],
            durations: [0.1, 0.1, 0.15],
            envelope: .sharp,
            volume: 0.25
        )
        playTone(tone, completion: completion)
    }
    
    // MARK: - Volume Control
    func updateVolume(_ newVolume: Float) {
        // Note: Volume is applied per-tone, so this would be for future tones
        // Current implementation recreates the generator, but could be enhanced
    }
}