//
//  AudioFeedbackManager.swift
//  MD TalkMan
//
//  Created by Claude on 8/15/25.
//

import AudioToolbox
import AVFoundation
import Foundation
import UIKit

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
    case codeBlockStart
    case codeBlockEnd
}

// MARK: - Audio Feedback Manager
class AudioFeedbackManager: ObservableObject {
    
    // MARK: - Properties
    @Published var isEnabled: Bool = true
    @Published var volume: Float = 0.7
    
    private var audioPlayer: AVAudioPlayer?
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    private var customToneGenerator: CustomToneGenerator?
    
    // MARK: - Initialization
    init() {
        // Note: Audio session is managed by TTSManager to avoid conflicts
        hapticGenerator.prepare()
        customToneGenerator = CustomToneGenerator(volume: volume)
    }
    
    // MARK: - Public Interface
    func playFeedback(for type: AudioFeedbackType) {
        guard isEnabled else { return }
        
        switch type {
        case .playStarted:
            customToneGenerator?.playStartTone()
            playHaptic(.light)
            
        case .playPaused:
            customToneGenerator?.playPauseTone()
            playHaptic(.medium)
            
        case .playStopped:
            customToneGenerator?.playStopTone()
            playHaptic(.heavy)
            
        case .playCompleted:
            customToneGenerator?.playCompletionTone()
            playHaptic(.success)
            
        case .sectionChanged:
            customToneGenerator?.playNavigationTone()
            playHaptic(.light)
            
        case .voiceChanged:
            customToneGenerator?.playSettingsChangeTone()
            playHaptic(.light)
            
        case .error:
            customToneGenerator?.playErrorTone()
            playHaptic(.error)
            
        case .buttonTap:
            customToneGenerator?.playButtonTapTone()
            playHaptic(.selection)
            
        case .codeBlockStart:
            customToneGenerator?.playCodeBlockStartTone()
            playHaptic(.light)
            
        case .codeBlockEnd:
            customToneGenerator?.playCodeBlockEndTone()
            playHaptic(.light)
        }
    }
    
    // MARK: - System Sound Playback (Legacy - No longer used)
    // System sounds have been replaced with custom Core Audio tones
    // Keeping for potential fallback scenarios
    
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
        // Recreate tone generator with new volume
        customToneGenerator = CustomToneGenerator(volume: self.volume)
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
    
    // MARK: - Legacy Code Block Methods (now using custom tones)
    func playCodeBlockStartTone(completion: (() -> Void)? = nil) {
        guard isEnabled else { 
            completion?()
            return
        }
        customToneGenerator?.playCodeBlockStartTone(completion: completion)
    }
    
    func playCodeBlockEndTone() {
        guard isEnabled else { return }
        customToneGenerator?.playCodeBlockEndTone()
    }
}