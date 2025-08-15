//
//  TTSManager.swift
//  MD TalkMan
//
//  Created by Claude on 8/14/25.
//

import AVFoundation
import Foundation
import CoreData

// MARK: - TTS Playback State
enum TTSPlaybackState {
    case idle
    case playing
    case paused
    case preparing
    case loading
    case error(String)
}

// MARK: - TTS Manager
class TTSManager: NSObject, ObservableObject {
    
    // MARK: - Properties
    @Published var playbackState: TTSPlaybackState = .idle
    @Published var currentPosition: Int = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var playbackSpeed: Float = 0.5
    @Published var currentSectionIndex: Int = 0
    @Published var selectedVoice: AVSpeechSynthesisVoice?
    @Published var pitchMultiplier: Float = 1.0
    @Published var volumeMultiplier: Float = 1.0
    @Published var isVoiceLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let synthesizer = AVSpeechSynthesizer()
    private var audioSession: AVAudioSession?
    
    // Available enhanced voices
    private var enhancedVoices: [AVSpeechSynthesisVoice] = []
    
    // Current content
    private var currentMarkdownFile: MarkdownFile?
    private var currentParsedContent: ParsedContent?
    private var contentSections: [ContentSection] = []
    private var currentUtterance: AVSpeechUtterance?
    
    // Navigation
    private var skippableSections: Set<Int> = []
    
    // MARK: - Initialization
    override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
        setupEnhancedVoices()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession?.setCategory(.playback, mode: .spokenAudio, options: [.allowBluetooth, .allowBluetoothA2DP])
            try audioSession?.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Voice Setup
    private func setupEnhancedVoices() {
        // Get all available voices for English
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // Filter for English voices and prioritize enhanced/premium voices
        let englishVoices = allVoices.filter { voice in
            voice.language.hasPrefix("en-") 
        }
        
        // Prioritize enhanced voices (usually have better quality)
        let enhancedEnglishVoices = englishVoices.filter { voice in
            voice.quality == .enhanced
        }
        
        // If no enhanced voices, use premium voices
        let premiumVoices = englishVoices.filter { voice in
            voice.quality == .premium
        }
        
        // Combine enhanced and premium voices
        enhancedVoices = enhancedEnglishVoices + premiumVoices
        
        // If still no good voices, fall back to default voices
        if enhancedVoices.isEmpty {
            enhancedVoices = englishVoices.filter { voice in
                voice.quality == .default
            }
        }
        
        // Set default voice (prefer specific high-quality voices)
        selectedVoice = getBestAvailableVoice()
        
        print("🎵 TTS Setup: Found \(enhancedVoices.count) enhanced voices")
        for voice in enhancedVoices.prefix(5) {
            print("  - \(voice.name) (\(voice.language)) - Quality: \(voice.quality.rawValue)")
        }
    }
    
    private func getBestAvailableVoice() -> AVSpeechSynthesisVoice? {
        // Preferred voice identifiers (these are typically the most natural)
        let preferredVoices = [
            "com.apple.voice.enhanced.en-US.Ava",      // Ava (Neural)
            "com.apple.voice.enhanced.en-US.Samantha", // Samantha (Enhanced)
            "com.apple.voice.enhanced.en-US.Alex",     // Alex (Enhanced)
            "com.apple.voice.premium.en-US.Zoe",       // Zoe (Premium)
            "com.apple.voice.premium.en-US.Evan",      // Evan (Premium)
            "com.apple.voice.enhanced.en-GB.Daniel",   // Daniel (UK Enhanced)
            "com.apple.voice.enhanced.en-AU.Karen"     // Karen (AU Enhanced)
        ]
        
        // Try to find preferred voices first
        for voiceId in preferredVoices {
            if let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
                print("🎵 Selected premium voice: \(voice.name)")
                return voice
            }
        }
        
        // Fall back to best available enhanced voice
        if let firstEnhanced = enhancedVoices.first {
            print("🎵 Selected enhanced voice: \(firstEnhanced.name)")
            return firstEnhanced
        }
        
        // Final fallback to default US voice
        print("🎵 Using default voice")
        return AVSpeechSynthesisVoice(language: "en-US")
    }
    
    // MARK: - Load Content
    func loadMarkdownFile(_ markdownFile: MarkdownFile, context: NSManagedObjectContext) {
        // Stop current playback
        stop()
        
        currentMarkdownFile = markdownFile
        currentParsedContent = markdownFile.parsedContent
        
        // Load content sections
        if let parsedContent = currentParsedContent,
           let sections = parsedContent.contentSection as? Set<ContentSection> {
            contentSections = sections.sorted { $0.startIndex < $1.startIndex }
            
            // Identify skippable sections
            skippableSections.removeAll()
            for (index, section) in contentSections.enumerated() {
                if section.isSkippable {
                    skippableSections.insert(index)
                }
            }
        } else {
            contentSections.removeAll()
            skippableSections.removeAll()
        }
        
        // Load reading progress
        if let progress = markdownFile.readingProgress {
            currentPosition = Int(progress.currentPosition)
            totalDuration = progress.totalDuration
            
            // Find current section based on position
            updateCurrentSectionIndex()
        } else {
            // Create new reading progress
            let progress = ReadingProgress(context: context)
            progress.fileId = markdownFile.id!
            progress.currentPosition = 0
            progress.lastReadDate = Date()
            progress.totalDuration = 0
            progress.isCompleted = false
            progress.markdownFile = markdownFile
            
            do {
                try context.save()
            } catch {
                print("Failed to save reading progress: \(error)")
            }
        }
        
        playbackState = .idle
    }
    
    // MARK: - Playback Controls
    func play() {
        guard let parsedContent = currentParsedContent,
              let plainText = parsedContent.plainText,
              !plainText.isEmpty else {
            playbackState = .error("No content")
            errorMessage = "No content available for playback"
            return
        }
        
        // Clear any previous errors
        errorMessage = nil
        
        if playbackState == .paused {
            playbackState = .loading
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                
                if self.synthesizer.continueSpeaking() {
                    self.playbackState = .playing
                } else {
                    // Fallback: restart from current position
                    self.restartFromCurrentPosition()
                }
            }
            return
        }
        
        playbackState = .preparing
        
        // Get text from current position
        let textToSpeak = getTextFromCurrentPosition()
        
        guard !textToSpeak.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            playbackState = .error("No content at position")
            errorMessage = "No content available at current position"
            return
        }
        
        // Create utterance with enhanced settings
        currentUtterance = AVSpeechUtterance(string: textToSpeak)
        setupUtteranceParameters(currentUtterance!)
        
        // Start speaking with error handling
        do {
            synthesizer.speak(currentUtterance!)
            // Note: State will be updated by delegate methods
        } catch {
            playbackState = .error("Playback failed")
            errorMessage = "Failed to start playback: \(error.localizedDescription)"
        }
    }
    
    func pause() {
        guard playbackState == .playing else { return }
        
        playbackState = .loading
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            if self.synthesizer.pauseSpeaking(at: .immediate) {
                self.playbackState = .paused
            } else {
                // Fallback: stop and save position
                self.synthesizer.stopSpeaking(at: .immediate)
                self.playbackState = .paused
            }
        }
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        playbackState = .idle
        currentUtterance = nil
    }
    
    func rewind(seconds: TimeInterval = 5.0) {
        // Calculate new position (approximate)
        let estimatedWordsPerMinute: Double = 150
        let wordsPerSecond = estimatedWordsPerMinute / 60
        let charactersPerSecond = wordsPerSecond * 5 // Average word length
        
        let charactersToRewind = Int(seconds * charactersPerSecond)
        currentPosition = max(0, currentPosition - charactersToRewind)
        
        updateCurrentSectionIndex()
        
        // Restart playback from new position if currently playing
        if playbackState == .playing {
            stop()
            play()
        }
        
        saveProgress()
    }
    
    func skipToNextSection() {
        guard currentSectionIndex < contentSections.count - 1 else { return }
        
        currentSectionIndex += 1
        currentPosition = Int(contentSections[currentSectionIndex].startIndex)
        
        // If currently playing, restart from new position
        if playbackState == .playing {
            stop()
            play()
        }
        
        saveProgress()
    }
    
    func skipToPreviousSection() {
        guard currentSectionIndex > 0 else { return }
        
        currentSectionIndex -= 1
        currentPosition = Int(contentSections[currentSectionIndex].startIndex)
        
        // If currently playing, restart from new position
        if playbackState == .playing {
            stop()
            play()
        }
        
        saveProgress()
    }
    
    func skipSkippableSections(_ skip: Bool) {
        // This will be used by the UI to enable/disable skipping technical content
        // Implementation will check this flag in the delegate methods
    }
    
    // MARK: - Voice & Audio Control
    func setPlaybackSpeed(_ speed: Float) {
        playbackSpeed = max(0.5, min(2.0, speed))
        
        // If currently playing, restart with new speed
        if playbackState == .playing {
            stop()
            play()
        }
    }
    
    func setVoice(_ voice: AVSpeechSynthesisVoice) {
        isVoiceLoading = true
        errorMessage = nil
        
        let wasPlaying = playbackState == .playing
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Simulate voice loading time and test voice
            Thread.sleep(forTimeInterval: 0.5)
            
            DispatchQueue.main.async {
                self.selectedVoice = voice
                self.isVoiceLoading = false
                
                print("🎵 Voice changed to: \(voice.name) (\(voice.language))")
                
                // If was playing, restart with new voice
                if wasPlaying {
                    self.stop()
                    self.play()
                }
            }
        }
    }
    
    func setPitchMultiplier(_ pitch: Float) {
        pitchMultiplier = max(0.5, min(2.0, pitch))
        
        // If currently playing, restart with new pitch
        if playbackState == .playing {
            restartFromCurrentPosition()
        }
    }
    
    func setVolumeMultiplier(_ volume: Float) {
        volumeMultiplier = max(0.1, min(1.0, volume))
        
        // If currently playing, restart with new volume
        if playbackState == .playing {
            restartFromCurrentPosition()
        }
    }
    
    func getAvailableVoices() -> [AVSpeechSynthesisVoice] {
        return enhancedVoices
    }
    
    private func setupUtteranceParameters(_ utterance: AVSpeechUtterance) {
        // Use selected voice or fallback to best available
        utterance.voice = selectedVoice ?? getBestAvailableVoice()
        
        // Speech rate (optimized for listening while driving)
        utterance.rate = playbackSpeed
        
        // Pitch adjustment for more natural sound
        utterance.pitchMultiplier = pitchMultiplier
        
        // Volume control
        utterance.volume = volumeMultiplier
        
        // Pre-utterance delay (slight pause before speaking)
        utterance.preUtteranceDelay = 0.1
        
        // Post-utterance delay (slight pause after speaking)
        utterance.postUtteranceDelay = 0.1
    }
    
    // MARK: - Private Helpers
    private func restartFromCurrentPosition() {
        let savedPosition = currentPosition
        let savedSectionIndex = currentSectionIndex
        
        stop()
        
        // Restore position
        currentPosition = savedPosition
        currentSectionIndex = savedSectionIndex
        
        // Restart playback
        play()
    }
    
    private func getTextFromCurrentPosition() -> String {
        guard let parsedContent = currentParsedContent,
              let plainText = parsedContent.plainText else {
            return ""
        }
        
        let startIndex = plainText.index(plainText.startIndex, offsetBy: min(currentPosition, plainText.count))
        return String(plainText[startIndex...])
    }
    
    private func updateCurrentSectionIndex() {
        for (index, section) in contentSections.enumerated() {
            if currentPosition >= section.startIndex && currentPosition < section.endIndex {
                currentSectionIndex = index
                break
            }
        }
    }
    
    private func saveProgress() {
        guard let markdownFile = currentMarkdownFile,
              let progress = markdownFile.readingProgress else { return }
        
        progress.currentPosition = Int32(currentPosition)
        progress.lastReadDate = Date()
        
        // Save context (assuming we have access to it)
        // In a real app, you'd inject the context or use a shared context
        do {
            try progress.managedObjectContext?.save()
        } catch {
            print("Failed to save progress: \(error)")
        }
    }
    
    // MARK: - Section Information
    func getCurrentSectionInfo() -> (type: ContentSectionType, level: Int, isSkippable: Bool)? {
        guard currentSectionIndex < contentSections.count else { return nil }
        
        let section = contentSections[currentSectionIndex]
        return (type: section.typeEnum, level: Int(section.level), isSkippable: section.isSkippable)
    }
    
    func canSkipCurrentSection() -> Bool {
        guard let sectionInfo = getCurrentSectionInfo() else { return false }
        return sectionInfo.isSkippable
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension TTSManager: AVSpeechSynthesizerDelegate {
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.playbackState = .playing
            self?.errorMessage = nil
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if utterance.speechString.isEmpty {
                self.playbackState = .error("No content to read")
                self.errorMessage = "No content available for playback"
            } else {
                self.playbackState = .idle
                
                // Mark as completed if we've reached the end
                if let markdownFile = self.currentMarkdownFile,
                   let progress = markdownFile.readingProgress {
                    progress.isCompleted = true
                    self.saveProgress()
                }
            }
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.playbackState = .paused
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.playbackState = .playing
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        // Update current position
        currentPosition += characterRange.location
        updateCurrentSectionIndex()
        
        // Save progress periodically (every 10 seconds approximately)
        if currentPosition % 500 == 0 { // Rough estimate
            saveProgress()
        }
    }
}