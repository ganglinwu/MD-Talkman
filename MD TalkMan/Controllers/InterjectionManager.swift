//
//  InterjectionManager.swift
//  MD TalkMan
//
//  Created by Claude on 8/28/25.
//

import Foundation
import AVFoundation
import UIKit

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
        
        // Ensure all interjection handling runs on main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.handleInterjection(event, ttsManager: ttsManager, completion: completion)
            }
            return
        }
        
        print("🎯 InterjectionManager: Handling interjection event on main thread")
        
        // Use natural TTS pauses instead of forcing stops
        print("🎯 InterjectionManager: Using natural pause approach - no TTS interruption")
        
        // Just proceed with the interjection during natural TTS flow
        // TTS will continue normally, interjection happens in post-utterance delay
        
        // Handle the specific interjection type
        switch event {
        case .codeBlockStart(let language, let section):
            executeCodeBlockStart(language: language, section: section, ttsManager: ttsManager) {
                // Natural approach - no TTS manipulation needed
                print("🎯 InterjectionManager: Code block start complete - TTS continues naturally")
                completion()
            }
            
        case .codeBlockEnd(let section):
            executeCodeBlockEnd(section: section, ttsManager: ttsManager) {
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
    private func executeCodeBlockStart(language: String?, section: ContentSection, ttsManager: TTSManager, completion: @escaping () -> Void) {
        assert(Thread.isMainThread, "Code block start must run on main thread")
        
        print("🎯 InterjectionManager: Executing code block start - language: \(language ?? "nil")")
        let notificationStyle = settingsManager.codeBlockNotificationStyle
        print("🎯 InterjectionManager: Notification style: \(notificationStyle)")
        
        switch notificationStyle {
        case .smartDetection:
            // During natural pause - just provide language notification
            if settingsManager.isCodeBlockLanguageNotificationEnabled,
               let language = language {
                provideLanguageNotification(language, ttsManager: ttsManager) {
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
                    self?.provideLanguageNotification(language, ttsManager: ttsManager) {
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
                provideLanguageNotification(language, ttsManager: ttsManager, completion: completion)
            } else {
                completion()
            }
        }
    }
    
    private func executeCodeBlockEnd(section: ContentSection, ttsManager: TTSManager, completion: @escaping () -> Void) {
        assert(Thread.isMainThread, "Code block end must run on main thread")
        
        print("🎯 InterjectionManager: Executing code block end")
        let notificationStyle = settingsManager.codeBlockNotificationStyle
        print("🎯 InterjectionManager: End notification style: \(notificationStyle)")
        
        switch notificationStyle {
        case .smartDetection:
            // Provide "code section ends" announcement for smart detection
            provideCodeEndNotification(ttsManager: ttsManager, completion: completion)
            
        case .tonesOnly:
            // Play tone only
            playCodeBlockToneWithPause(.codeBlockEnd, completion: completion)
            
        case .both:
            // Play tone first, then voice announcement
            playCodeBlockToneWithPause(.codeBlockEnd) { [weak self] in
                self?.provideCodeEndNotification(ttsManager: ttsManager, completion: completion)
            }
            
        case .voiceOnly:
            // Voice announcement only (no tone)
            provideCodeEndNotification(ttsManager: ttsManager, completion: completion)
        }
    }
    
    // MARK: - Audio Coordination  
    private func playCodeBlockToneWithPause(_ feedbackType: AudioFeedbackType, completion: @escaping () -> Void) {
        print("🎵 InterjectionManager: Playing code block tone - \(feedbackType)")
        
        // Play the actual tone using AudioFeedbackManager
        audioFeedback.playFeedback(for: feedbackType)
        
        // Add a small pause after the tone to let it complete
        let pauseDuration: TimeInterval = 0.9  // Allow time for tone to finish
        
        DispatchQueue.main.asyncAfter(deadline: .now() + pauseDuration) {
            print("🎵 InterjectionManager: Code block tone completed")
            completion()
        }
    }
    
    private func provideLanguageNotification(_ language: String, ttsManager: TTSManager, completion: @escaping () -> Void) {
        assert(Thread.isMainThread, "Language notification must run on main thread")
        
        print("🗣️ InterjectionManager: Providing language notification: '\(language) code'")
        
        // Use the shared TTSManager synthesizer instead of creating a new one
        guard let sharedSynthesizer = ttsManager.getSynthesizer() else {
            print("❌ InterjectionManager: No shared synthesizer available - completing without voice")
            completion()
            return
        }
        
        // Get the selected interjection voice
        let interjectionVoice = getInterjectionVoice()
        
        // Check for Siri voice compatibility
        if let voice = interjectionVoice, voice.identifier.contains("siri") {
            print("⚠️ InterjectionManager: Skipping Siri voice (\(voice.name)) - not compatible with AVSpeechSynthesizer")
            // Find a non-Siri fallback
            let fallbackVoice = findNonSiriVoice() ?? AVSpeechSynthesisVoice(language: "en-US")
            performInterjectionSpeech("\(language) code", voice: fallbackVoice, synthesizer: sharedSynthesizer, completion: completion)
        } else {
            // Use the selected voice or system default
            let voiceToUse = interjectionVoice ?? AVSpeechSynthesisVoice(language: "en-US")
            performInterjectionSpeech("\(language) code", voice: voiceToUse, synthesizer: sharedSynthesizer, completion: completion)
        }
    }
    
    private func provideCodeEndNotification(ttsManager: TTSManager, completion: @escaping () -> Void) {
        assert(Thread.isMainThread, "Code end notification must run on main thread")
        
        print("🗣️ InterjectionManager: Providing code end notification: 'code section ends'")
        
        // Use the shared TTSManager synthesizer instead of creating a new one
        guard let sharedSynthesizer = ttsManager.getSynthesizer() else {
            print("❌ InterjectionManager: No shared synthesizer available - completing without voice")
            completion()
            return
        }
        
        // Get the selected interjection voice
        let interjectionVoice = getInterjectionVoice()
        
        // Check for Siri voice compatibility
        if let voice = interjectionVoice, voice.identifier.contains("siri") {
            print("⚠️ InterjectionManager: Skipping Siri voice (\(voice.name)) - not compatible with AVSpeechSynthesizer")
            // Find a non-Siri fallback
            let fallbackVoice = findNonSiriVoice() ?? AVSpeechSynthesisVoice(language: "en-US")
            performInterjectionSpeech("code section ends", voice: fallbackVoice, synthesizer: sharedSynthesizer, completion: completion)
        } else {
            // Use the selected voice or system default
            let voiceToUse = interjectionVoice ?? AVSpeechSynthesisVoice(language: "en-US")
            performInterjectionSpeech("code section ends", voice: voiceToUse, synthesizer: sharedSynthesizer, completion: completion)
        }
    }
    
    private func performInterjectionSpeech(_ text: String, voice: AVSpeechSynthesisVoice?, synthesizer: AVSpeechSynthesizer, completion: @escaping () -> Void) {
        assert(Thread.isMainThread, "Interjection speech must run on main thread")
        
        print("🗣️ InterjectionManager: Speaking '\(text)' with voice: \(voice?.name ?? "system default")")
        print("🗣️ InterjectionManager: Using shared synthesizer for interjection")
        
        // Create interjection utterance with standard settings
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.0  // Normal speed for clarity
        utterance.volume = 0.85  // Clear volume level
        utterance.preUtteranceDelay = 0.1  // Brief delay
        utterance.postUtteranceDelay = 0.2  // Standard pause
        
        // Create a strong delegate to handle completion
        let delegate = InterjectionSpeechDelegate { [weak self] in
            print("✅ InterjectionManager: Interjection speech completed")
            self?.playEndOfInterjectionTone {
                print("🔄 InterjectionManager: Interjection complete")
                completion()
            }
        }
        
        // Store the delegate to keep it alive during speech
        synthesizer.delegate = delegate
        objc_setAssociatedObject(synthesizer, "interjectionDelegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        
        // Speak the interjection using shared synthesizer
        synthesizer.speak(utterance)
        print("🗣️ InterjectionManager: Interjection utterance added to synthesizer queue")
    }
    
    // MARK: - Testing Interface
    /// Test method for VoiceSettingsView to verify interjection voice functionality
    /// - Parameters:
    ///   - language: The language code to announce (e.g. "swift", "javascript")
    ///   - ttsManager: Reference to TTS manager for shared synthesizer access
    ///   - completion: Called when the test is complete
    func testLanguageNotification(_ language: String, ttsManager: TTSManager, completion: @escaping () -> Void) {
        assert(Thread.isMainThread, "Test language notification must run on main thread")
        
        print("🧪 InterjectionManager: Testing language notification for: '\(language) code'")
        provideLanguageNotification(language, ttsManager: ttsManager, completion: completion)
    }
    
    /// Test method for VoiceSettingsView to verify code end notification functionality
    /// - Parameters:
    ///   - ttsManager: Reference to TTS manager for shared synthesizer access
    ///   - completion: Called when the test is complete
    func testCodeEndNotification(ttsManager: TTSManager, completion: @escaping () -> Void) {
        assert(Thread.isMainThread, "Test code end notification must run on main thread")
        
        print("🧪 InterjectionManager: Testing code end notification: 'code section ends'")
        provideCodeEndNotification(ttsManager: ttsManager, completion: completion)
    }
    
    // MARK: - Voice Selection
    private func getInterjectionVoice() -> AVSpeechSynthesisVoice? {
        print("🔍 InterjectionManager: Getting interjection voice from settings...")
        
        // Try to get user-selected voice first
        if let selectedVoice = settingsManager.getSelectedInterjectionVoice() {
            print("✅ InterjectionManager: Using user-selected voice: \(selectedVoice.name)")
            return selectedVoice
        }
        
        // Fallback to default female voice
        let defaultVoice = settingsManager.getDefaultInterjectionVoice()
        print("✅ InterjectionManager: Using default interjection voice: \(defaultVoice?.name ?? "system default")")
        return defaultVoice
    }
    
    private func findNonSiriVoice() -> AVSpeechSynthesisVoice? {
        let femaleVoices = settingsManager.getAvailableFemaleVoices()
        
        // Find first non-Siri voice
        for voice in femaleVoices {
            if !voice.identifier.contains("siri") && !voice.identifier.contains("ttsbundle") {
                print("🔍 InterjectionManager: Found non-Siri voice: \(voice.name)")
                return voice
            }
        }
        
        print("⚠️ InterjectionManager: No non-Siri voices found")
        return nil
    }
    
    // MARK: - End of Interjection Tone
    private func playEndOfInterjectionTone(completion: @escaping () -> Void) {
        print("🎵 InterjectionManager: Playing end-of-interjection tone")
        
        // Play a subtle "completion" tone to signal end of interjection
        audioFeedback.playFeedback(for: .buttonTap)  // Subtle, brief completion tone
        
        // Add small pause after tone to ensure it completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            print("🎵 InterjectionManager: End-of-interjection tone completed")
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


// MARK: - Interjection Speech Delegate
private class InterjectionSpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    private let completion: () -> Void
    
    init(completion: @escaping () -> Void) {
        self.completion = completion
        super.init()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("🗣️ InterjectionSpeechDelegate: Interjection speech started")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("🗣️ InterjectionSpeechDelegate: Interjection speech finished")
        completion()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("🗣️ InterjectionSpeechDelegate: Interjection speech cancelled")
        completion()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString range: NSRange, utterance: AVSpeechUtterance) {
        print("🗣️ InterjectionSpeechDelegate: Speaking interjection range")
    }
}