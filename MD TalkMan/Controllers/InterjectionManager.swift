//
//  InterjectionManager.swift
//  MD TalkMan
//
//  Created by Claude on 8/28/25.
//

import Foundation
import AVFoundation

// MARK: - Interjection Event Types
enum InterjectionEvent {
    case codeBlockStart(language: String?, section: ContentSection)
    case codeBlockEnd(section: ContentSection)
    
    // Phase 4 Extensions (for future Claude AI integration):
    case claudeInsight(text: String, context: String)
    case userQuestion(query: String)
    case contextualHelp(topic: String)
}

// MARK: - Interjection Manager
class InterjectionManager: ObservableObject {
    
    // MARK: - Properties
    private let audioFeedback: AudioFeedbackManager
    private let settingsManager = SettingsManager.shared
    
    // MARK: - Initialization
    init(audioFeedback: AudioFeedbackManager) {
        self.audioFeedback = audioFeedback
    }
    
    // MARK: - Public Interface
    /// Handle an interjection event with proper TTS pause/resume coordination
    /// - Parameters:
    ///   - event: The interjection event to handle
    ///   - ttsManager: Reference to TTS manager for pause/resume coordination
    ///   - completion: Called when interjection is complete and TTS can resume
    func handleInterjection(_ event: InterjectionEvent, 
                          ttsManager: TTSManager,
                          completion: @escaping () -> Void) {
        
        print("🎯 InterjectionManager: Handling interjection event")
        
        // Use natural TTS pauses instead of forcing stops
        print("🎯 InterjectionManager: Using natural pause approach - no TTS interruption")
        
        // Just proceed with the interjection during natural TTS flow
        // TTS will continue normally, interjection happens in post-utterance delay
        
        // Handle the specific interjection type
        switch event {
        case .codeBlockStart(let language, let section):
            executeCodeBlockStart(language: language, section: section) {
                // Natural approach - no TTS manipulation needed
                print("🎯 InterjectionManager: Code block start complete - TTS continues naturally")
                completion()
            }
            
        case .codeBlockEnd(let section):
            executeCodeBlockEnd(section: section) {
                // Natural approach - no TTS manipulation needed
                print("🎯 InterjectionManager: Code block end complete - TTS continues naturally")
                completion()
            }
            
        // Phase 4 extensions - not implemented yet
        case .claudeInsight(let text, let context):
            executeClaudeInsight(text: text, context: context, completion: completion)
            
        case .userQuestion(let query):
            executeUserQuestion(query: query, completion: completion)
            
        case .contextualHelp(let topic):
            executeContextualHelp(topic: topic, completion: completion)
        }
    }
    
    // MARK: - Code Block Interjections
    private func executeCodeBlockStart(language: String?, section: ContentSection, completion: @escaping () -> Void) {
        print("🎯 InterjectionManager: Executing code block start - language: \(language ?? "nil")")
        let notificationStyle = settingsManager.codeBlockNotificationStyle
        print("🎯 InterjectionManager: Notification style: \(notificationStyle)")
        
        switch notificationStyle {
        case .smartDetection:
            // During natural pause - just provide language notification
            if settingsManager.isCodeBlockLanguageNotificationEnabled,
               let language = language {
                provideLanguageNotification(language) {
                    completion()
                }
            } else {
                completion()
            }
            
        case .tonesOnly:
            // Play tone with extended pause only
            playCodeBlockToneWithPause(.codeBlockStart, completion: completion)
            
        case .both:
            // Play tone with extended pause, then language notification
            playCodeBlockToneWithPause(.codeBlockStart) { [weak self] in
                if self?.settingsManager.isCodeBlockLanguageNotificationEnabled == true,
                   let language = language {
                    self?.provideLanguageNotification(language) {
                        completion()
                    }
                } else {
                    completion()
                }
            }
            
        case .voiceOnly:
            // Language notification only (no tone)
            if settingsManager.isCodeBlockLanguageNotificationEnabled,
               let language = language {
                provideLanguageNotification(language, completion: completion)
            } else {
                completion()
            }
        }
    }
    
    private func executeCodeBlockEnd(section: ContentSection, completion: @escaping () -> Void) {
        let notificationStyle = settingsManager.codeBlockNotificationStyle
        
        switch notificationStyle {
        case .smartDetection, .tonesOnly, .both:
            playCodeBlockToneWithPause(.codeBlockEnd, completion: completion)
            
        case .voiceOnly:
            // No end tone for voice-only mode
            completion()
        }
    }
    
    // MARK: - Audio Coordination  
    private func playCodeBlockToneWithPause(_ feedbackType: AudioFeedbackType, completion: @escaping () -> Void) {
        print("🎵 InterjectionManager: Simplified approach - minimal audio load")
        
        // Just add a pause instead of complex tone generation to avoid audio overload
        let pauseDuration: TimeInterval = 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + pauseDuration) {
            print("🎵 InterjectionManager: Pause completed")
            completion()
        }
    }
    
    private func provideLanguageNotification(_ language: String, completion: @escaping () -> Void) {
        print("🗣️ InterjectionManager: Providing language notification: '\(language) code'")
        
        // Create a temporary synthesizer for the interjection
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: "\(language) code")
        
        // Use female voice for code block announcements (distinctive contrast)
        let voice = getFemaleVoice()
        utterance.voice = voice
        print("🗣️ InterjectionManager: Using voice: \(voice?.name ?? "default")")
        
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.1
        utterance.volume = 0.8
        utterance.preUtteranceDelay = 0.2
        utterance.postUtteranceDelay = 0.4  // Pause before end-of-interjection tone
        
        print("🗣️ InterjectionManager: Starting language notification synthesis...")
        
        // Synthesizer delegate to handle completion
        let delegate = InterjectionSynthesizerDelegate { [weak self] in
            // After language announcement, play end-of-interjection tone
            self?.playEndOfInterjectionTone {
                completion()
            }
        }
        synthesizer.delegate = delegate
        
        // Keep delegate alive during synthesis
        objc_setAssociatedObject(synthesizer, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        
        synthesizer.speak(utterance)
    }
    
    // MARK: - Voice Selection
    private func getFemaleVoice() -> AVSpeechSynthesisVoice? {
        print("🔍 InterjectionManager: Searching for female voice...")
        
        // First check basic voices that are always available
        let basicFemaleVoices = [
            AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Samantha-compact"),
            AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.siri_female_en-US_compact"),
            AVSpeechSynthesisVoice(language: "en-US") // System default
        ]
        
        for voice in basicFemaleVoices {
            if let voice = voice {
                print("✅ InterjectionManager: Using basic voice: \(voice.name)")
                return voice
            }
        }
        
        // Fallback: Find any female voice by name
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        print("🔍 InterjectionManager: Checking \(allVoices.count) available voices...")
        
        for voice in allVoices {
            if voice.language.hasPrefix("en") {
                let voiceName = voice.name.lowercased()
                print("   - Voice: \(voice.name) (\(voice.language))")
                
                // Look for explicitly female names
                if voiceName.contains("samantha") || voiceName.contains("ava") || 
                   voiceName.contains("victoria") || voiceName.contains("allison") ||
                   voiceName.contains("susan") || voiceName.contains("zoe") {
                    print("✅ InterjectionManager: Found female voice by name: \(voice.name)")
                    return voice
                }
            }
        }
        
        // Force use a different voice than main TTS for contrast
        print("⚠️ InterjectionManager: No specific female voice found, filtering out male names...")
        let maleNames = ["alex", "daniel", "tom", "fred", "aaron", "arthur", "albert"]
        
        for voice in allVoices {
            if voice.language.hasPrefix("en") {
                let voiceName = voice.name.lowercased()
                let isMale = maleNames.contains { voiceName.contains($0) }
                
                if !isMale {
                    print("✅ InterjectionManager: Using non-male voice: \(voice.name)")
                    return voice
                }
            }
        }
        
        // Last resort: return default voice
        print("⚠️ InterjectionManager: Using default voice as last resort")
        return AVSpeechSynthesisVoice(language: "en-US")
    }
    
    // MARK: - End of Interjection Tone
    private func playEndOfInterjectionTone(completion: @escaping () -> Void) {
        // Play a subtle "completion" tone - descending interval to signal end
        audioFeedback.playFeedback(for: .buttonTap)  // Subtle, brief tone
        
        // Add small pause after tone
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            completion()
        }
    }
    
    // MARK: - Phase 4 Extensions (Stubs)
    private func executeClaudeInsight(text: String, context: String, completion: @escaping () -> Void) {
        // Phase 4: Implement Claude AI insight injection
        print("📝 Phase 4: Claude insight would be spoken here: \(text)")
        completion()
    }
    
    private func executeUserQuestion(query: String, completion: @escaping () -> Void) {
        // Phase 4: Implement user question handling
        print("❓ Phase 4: User question would be processed here: \(query)")
        completion()
    }
    
    private func executeContextualHelp(topic: String, completion: @escaping () -> Void) {
        // Phase 4: Implement contextual help system
        print("💡 Phase 4: Contextual help would be provided here for: \(topic)")
        completion()
    }
}

// MARK: - Interjection Synthesizer Delegate
private class InterjectionSynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    private let completion: () -> Void
    
    init(completion: @escaping () -> Void) {
        self.completion = completion
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        completion()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        completion()
    }
}