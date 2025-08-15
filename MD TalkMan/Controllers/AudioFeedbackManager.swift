//
//  AudioFeedbackManager.swift
//  MD TalkMan
//
//  Created by Claude on 8/15/25.
//

import AudioToolbox
import AVFoundation
import Foundation

// MARK: - Audio Feedback Types
enum AudioFeedbackType {
    case playStarted
    case playPaused 
    case playStopped
    case playCompleted
    case sectionChanged
    case voiceChanged
    case error
    case buttonTap
}

// MARK: - Audio Feedback Manager
class AudioFeedbackManager: ObservableObject {
    
    // MARK: - Properties
    @Published var isEnabled: Bool = true
    @Published var volume: Float = 0.7
    
    private var audioPlayer: AVAudioPlayer?
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    // MARK: - Initialization
    init() {
        setupAudioSession()
        hapticGenerator.prepare()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Configure for mixing with TTS
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP]
            )
        } catch {
            print("Failed to setup audio session for feedback: \(error)")
        }
    }
    
    // MARK: - Public Interface
    func playFeedback(for type: AudioFeedbackType) {
        guard isEnabled else { return }
        
        switch type {
        case .playStarted:
            playSystemSound(.begin)
            playHaptic(.light)
            
        case .playPaused:
            playSystemSound(.tweetSent)
            playHaptic(.medium)
            
        case .playStopped:
            playSystemSound(.tweetSent)
            playHaptic(.heavy)
            
        case .playCompleted:
            playSystemSound(.mailSent)
            playHaptic(.success)
            
        case .sectionChanged:
            playSystemSound(.navigationPop)
            playHaptic(.light)
            
        case .voiceChanged:
            playSystemSound(.keyPressed)
            playHaptic(.light)
            
        case .error:
            playSystemSound(.alert)
            playHaptic(.error)
            
        case .buttonTap:
            playSystemSound(.keyPressed)
            playHaptic(.selection)
        }
    }
    
    // MARK: - System Sound Playback
    private func playSystemSound(_ sound: SystemSoundType) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, self.isEnabled else { return }
            
            AudioServicesPlaySystemSoundWithCompletion(sound.rawValue) {
                // Completion handler - could add additional logic here
            }
        }
    }
    
    // MARK: - Haptic Feedback
    private func playHaptic(_ type: HapticType) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isEnabled else { return }
            
            switch type {
            case .selection:
                UISelectionFeedbackGenerator().selectionChanged()
                
            case .light:
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                
            case .medium:
                self.hapticGenerator.impactOccurred()
                
            case .heavy:
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                
            case .success:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                
            case .warning:
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                
            case .error:
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
    
    // MARK: - Custom Audio Playback
    private func playCustomSound(filename: String, volume: Float = 0.7) {
        guard isEnabled else { return }
        
        guard let url = Bundle.main.url(forResource: filename, withExtension: "wav") else {
            print("Could not find audio file: \(filename).wav")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = min(volume * self.volume, 1.0)
            audioPlayer?.play()
        } catch {
            print("Error playing custom sound: \(error)")
        }
    }
    
    // MARK: - Settings
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
    
    func setVolume(_ volume: Float) {
        self.volume = max(0.0, min(1.0, volume))
    }
}

// MARK: - System Sound Types
private enum SystemSoundType: SystemSoundID {
    case keyPressed = 1104
    case tweetSent = 1016
    case mailSent = 1010  
    case begin = 1113
    case navigationPop = 1106
    case alert = 1005
}

// MARK: - Haptic Types
private enum HapticType {
    case selection
    case light
    case medium
    case heavy
    case success
    case warning
    case error
}

// MARK: - Audio Feedback Settings Extension
extension AudioFeedbackManager {
    
    // Preset configurations for different usage scenarios
    func applyDrivingPreset() {
        isEnabled = true
        volume = 0.8
        // Stronger feedback for driving
    }
    
    func applyQuietPreset() {
        isEnabled = true
        volume = 0.3
        // Subtle feedback for quiet environments
    }
    
    func applyOffPreset() {
        isEnabled = false
        // No audio feedback
    }
}