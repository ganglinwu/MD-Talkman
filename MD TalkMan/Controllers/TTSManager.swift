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
enum TTSPlaybackState: Equatable {
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
    @Published var playbackSpeed: Float = 1.0
    @Published var currentSectionIndex: Int = 0
    @Published var selectedVoice: AVSpeechSynthesisVoice?
    @Published var pitchMultiplier: Float = 1.0
    @Published var volumeMultiplier: Float = 1.0
    @Published var isVoiceLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let synthesizer = AVSpeechSynthesizer()
    private var audioSession: AVAudioSession?
    private let audioFeedback = AudioFeedbackManager()
    
    // Visual text display integration
    @Published var textWindowManager = TextWindowManager()
    
    // Available enhanced voices
    private var enhancedVoices: [AVSpeechSynthesisVoice] = []
    
    // Settings integration
    private let settingsManager = SettingsManager.shared
    
    // Current content
    private var currentMarkdownFile: MarkdownFile?
    private var currentParsedContent: ParsedContent?
    private var contentSections: [ContentSection] = []
    private var currentUtterance: AVSpeechUtterance?
    private var utteranceStartPosition: Int = 0  // Track where current utterance starts
    private var userRequestedStop: Bool = false  // Track if user explicitly stopped playback
    
    // Volume fading
    private var fadeTimer: Timer?
    private var originalTTSVolume: Float = 1.0
    
    // Navigation
    private var skippableSections: Set<Int> = []
    
    // MARK: - Initialization
    override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
        setupEnhancedVoices()
    }
    
    deinit {
        // Clean up volume fading timer
        fadeTimer?.invalidate()
        fadeTimer = nil
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        
        do {
            // Primary: Try .spokenAudio mode for optimal TTS
            try audioSession?.setCategory(.playback, mode: .spokenAudio, options: [.allowBluetooth])
            try audioSession?.setActive(true)
            print("✅ Audio session setup successful (.spokenAudio)")
        } catch {
            print("⚠️ Primary audio session setup failed: \(error)")
            
            // Fallback 1: Try .playback with .default mode
            do {
                try audioSession?.setCategory(.playback, mode: .default, options: [.allowBluetooth, .duckOthers])
                try audioSession?.setActive(true)
                print("✅ Audio session setup successful (.playback + .default)")
            } catch {
                print("⚠️ Fallback 1 failed: \(error)")
                
                // Fallback 2: Minimal configuration
                do {
                    try audioSession?.setCategory(.playback)
                    try audioSession?.setActive(true)
                    print("✅ Audio session setup successful (minimal .playback)")
                } catch let finalError {
                    print("❌ All audio session setups failed: \(finalError)")
                    // Set error state so the app can handle this gracefully
                    DispatchQueue.main.async { [weak self] in
                        self?.playbackState = .error("Audio setup failed")
                        self?.errorMessage = "Failed to configure audio session: \(finalError.localizedDescription)"
                    }
                }
            }
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
        // In test environment, use basic voices to avoid loading delays
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            print("🧪 Test environment detected - using basic system voice")
            return AVSpeechSynthesisVoice(language: "en-US")
        }
        
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
        
        if currentParsedContent == nil {
            print("⚠️ No ParsedContent found for \(markdownFile.title ?? "file") - using fallback content")
        }
        
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
            
            // Load content into text window manager for visual display
            if let plainText = parsedContent.plainText {
                textWindowManager.loadContent(sections: contentSections, plainText: plainText)
                print("📖 TTSManager: Loaded content into text window manager")
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
            print("❌ No content available for playback")
            playbackState = .error("No content")
            errorMessage = "No content available for playback"
            audioFeedback.playFeedback(for: .error)
            return
        }
        
        // Clear any previous errors and reset stop flag
        errorMessage = nil
        userRequestedStop = false
        
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
            audioFeedback.playFeedback(for: .error)
            return
        }
        
        // Create utterance with enhanced settings
        currentUtterance = AVSpeechUtterance(string: textToSpeak)
        setupUtteranceParameters(currentUtterance!)
        
        // Remember where this utterance starts in the document
        utteranceStartPosition = currentPosition
        
        // Add longer pause to allow tones to complete and create breathing room
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, let utterance = self.currentUtterance else { return }
            self.synthesizer.speak(utterance)
            // Note: State will be updated by delegate methods
        }
    }
    
    func pause() {
        guard playbackState == .playing || playbackState == .preparing else { return }
        
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
        userRequestedStop = true
        
        // Stop any ongoing volume fading
        stopVolumeFading()
        
        synthesizer.stopSpeaking(at: .immediate)
        playbackState = .idle
        currentUtterance = nil
        audioFeedback.playFeedback(for: .playStopped)
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
        
        // Validate section index bounds
        guard currentSectionIndex >= 0 && currentSectionIndex < contentSections.count else {
            print("⚠️ Invalid section index: \(currentSectionIndex), clamping to bounds")
            currentSectionIndex = max(0, min(currentSectionIndex, contentSections.count - 1))
            return
        }
        
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
        
        // Validate section index bounds
        guard currentSectionIndex >= 0 && currentSectionIndex < contentSections.count else {
            print("⚠️ Invalid section index: \(currentSectionIndex), clamping to bounds")
            currentSectionIndex = max(0, min(currentSectionIndex, contentSections.count - 1))
            return
        }
        
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
        let newSpeed = max(0.5, min(2.0, speed))
        
        // Only update if speed actually changed (avoid unnecessary restarts)
        guard abs(playbackSpeed - newSpeed) > 0.05 else { return }
        
        playbackSpeed = newSpeed
        
        // If currently playing, restart with new speed
        if playbackState == .playing {
            restartFromCurrentPosition()
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
                self.audioFeedback.playFeedback(for: .voiceChanged)
                
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
    
    func getAudioFeedbackManager() -> AudioFeedbackManager {
        return audioFeedback
    }
    
    private func setupUtteranceParameters(_ utterance: AVSpeechUtterance) {
        // Use selected voice or fallback to best available
        utterance.voice = selectedVoice ?? getBestAvailableVoice()
        
        // Speech rate (convert user-friendly speed to AVSpeechUtterance rate)
        // User speed: 0.5x-2.0x -> AVSpeech rate: 0.25-1.0 (0.5 = normal)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * playbackSpeed
        
        // Pitch adjustment for more natural sound
        utterance.pitchMultiplier = pitchMultiplier
        
        // Volume control
        utterance.volume = volumeMultiplier
        
        // Extended pre-utterance delay for smoother transitions
        utterance.preUtteranceDelay = 0.3
        
        // Dynamic post-utterance delay based on content type
        utterance.postUtteranceDelay = getPostUtteranceDelay()
    }
    
    private func getPostUtteranceDelay() -> TimeInterval {
        // Check if current section is a code block that might need extra pause time
        guard currentSectionIndex >= 0 && currentSectionIndex < contentSections.count else {
            return 0.4  // Default delay
        }
        
        let currentSection = contentSections[currentSectionIndex]
        
        // If we're in a code block, add extra delay to allow end tones to play
        if currentSection.typeEnum == .codeBlock {
            return 0.8  // Longer delay for code blocks to accommodate end tones
        }
        
        return 0.4  // Standard delay for regular content
    }
    
    // MARK: - Volume Fading
    private func startVolumeFadeIn() {
        originalTTSVolume = volumeMultiplier
        
        // Start from low volume
        volumeMultiplier = 0.1
        
        let fadeSteps = 10
        let stepInterval = 0.03  // 30ms intervals
        let volumeStep = (originalTTSVolume - 0.1) / Float(fadeSteps)
        
        var currentStep = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            currentStep += 1
            self.volumeMultiplier = min(0.1 + volumeStep * Float(currentStep), self.originalTTSVolume)
            
            if currentStep >= fadeSteps {
                timer.invalidate()
                self.fadeTimer = nil
                self.volumeMultiplier = self.originalTTSVolume
            }
        }
    }
    
    private func startVolumeFadeOut(completion: @escaping () -> Void) {
        let fadeSteps = 8
        let stepInterval = 0.05  // 50ms intervals  
        let startVolume = volumeMultiplier
        let volumeStep = startVolume / Float(fadeSteps)
        
        var currentStep = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                completion()
                return
            }
            
            currentStep += 1
            self.volumeMultiplier = max(startVolume - volumeStep * Float(currentStep), 0.1)
            
            if currentStep >= fadeSteps {
                timer.invalidate()
                self.fadeTimer = nil
                completion()
            }
        }
    }
    
    private func stopVolumeFading() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        volumeMultiplier = originalTTSVolume
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
        
        let totalLength = plainText.count
        
        // Ensure currentPosition is within valid bounds
        guard currentPosition >= 0 else {
            print("⚠️ Invalid negative position: \(currentPosition), resetting to 0")
            currentPosition = 0
            return getTextFromCurrentPosition() // Retry with corrected position
        }
        
        let startPos = min(currentPosition, totalLength)
        
        // Check if we're at or past the end
        guard startPos < totalLength else { return "" }
        
        // For memory efficiency, read in chunks instead of entire remaining text
        // Use larger chunks for better TTS flow, but limit memory usage
        let maxChunkSize = 50000  // ~50KB chunks - good balance of performance vs memory
        let endPos = min(startPos + maxChunkSize, totalLength)
        
        guard startPos < endPos else { return "" }
        
        let startIndex = plainText.index(plainText.startIndex, offsetBy: startPos)
        let endIndex = plainText.index(plainText.startIndex, offsetBy: endPos)
        
        let textChunk = String(plainText[startIndex..<endIndex])
        
        // Additional safety: don't return tiny fragments that could cause loops
        let trimmedChunk = textChunk.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedChunk.count < 10 && startPos + textChunk.count >= totalLength {
            // This is a tiny fragment at the end - mark as complete
            return ""
        }
        
        return textChunk
    }
    
    private func hasMoreContentToRead() -> Bool {
        guard let parsedContent = currentParsedContent,
              let plainText = parsedContent.plainText else {
            return false
        }
        
        return currentPosition < plainText.count
    }
    
    private func isAtEndOfContent() -> Bool {
        guard let parsedContent = currentParsedContent,
              let plainText = parsedContent.plainText else {
            return true
        }
        
        // Check if we're within 100 characters of the end to prevent infinite loops
        // This handles edge cases where tiny fragments remain
        let remainingCharacters = plainText.count - currentPosition
        return remainingCharacters <= 100
    }
    
    private func updateCurrentSectionIndex() {
        for (index, section) in contentSections.enumerated() {
            if currentPosition >= section.startIndex && currentPosition < section.endIndex {
                currentSectionIndex = index
                break
            }
        }
        
        // Update text window manager with current position
        textWindowManager.updateWindow(for: currentPosition)
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
        guard currentSectionIndex >= 0 && currentSectionIndex < contentSections.count else { return nil }
        
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
            self?.audioFeedback.playFeedback(for: .playStarted)
            
            // Start volume fade in for smoother audio transition
            self?.startVolumeFadeIn()
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if utterance.speechString.isEmpty {
                self.playbackState = .error("No content to read")
                self.errorMessage = "No content available for playback"
                self.audioFeedback.playFeedback(for: .error)
            } else {
                // Check if user explicitly stopped playback
                if self.userRequestedStop {
                    self.playbackState = .idle
                    self.audioFeedback.playFeedback(for: .playStopped)
                    return
                }
                
                // Update position to end of current utterance
                self.currentPosition = self.utteranceStartPosition + utterance.speechString.count
                
                // Check if we've reached the actual end of content
                if !self.hasMoreContentToRead() || self.isAtEndOfContent() {
                    // Truly finished - mark as completed
                    self.playbackState = .idle
                    
                    if let markdownFile = self.currentMarkdownFile,
                       let progress = markdownFile.readingProgress {
                        progress.isCompleted = true
                        self.saveProgress()
                        self.audioFeedback.playFeedback(for: .playCompleted)
                    } else {
                        self.audioFeedback.playFeedback(for: .playStopped)
                    }
                } else {
                    // Continue reading the next chunk automatically
                    self.play()
                }
            }
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.playbackState = .paused
            self?.audioFeedback.playFeedback(for: .playPaused)
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.playbackState = .playing
            self?.audioFeedback.playFeedback(for: .playStarted)
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        // Calculate absolute position in document
        // characterRange.location is relative to current utterance, not entire document
        let previousSectionIndex = currentSectionIndex
        currentPosition = utteranceStartPosition + characterRange.location  // ✅ Fixed: Set absolute position
        updateCurrentSectionIndex()
        
        // Check if we've moved to a new section
        if currentSectionIndex != previousSectionIndex {
            handleSectionTransition(from: previousSectionIndex, to: currentSectionIndex)
        }
        
        // Save progress periodically (every 10 seconds approximately)
        if currentPosition % 500 == 0 { // Rough estimate
            saveProgress()
        }
    }
    
    // MARK: - Enhanced Section Transition Handling
    private func handleSectionTransition(from fromIndex: Int, to toIndex: Int) {
        guard fromIndex >= 0 && fromIndex < contentSections.count,
              toIndex >= 0 && toIndex < contentSections.count else {
            // Edge case - no audio feedback needed for basic navigation
            return
        }
        
        let fromSection = contentSections[fromIndex]
        let toSection = contentSections[toIndex]
        
        // Handle code block transitions with enhanced feedback
        if toSection.typeEnum == .codeBlock && fromSection.typeEnum != .codeBlock {
            // Entering code block
            handleCodeBlockEntry(toSection)
        } else if toSection.typeEnum != .codeBlock && fromSection.typeEnum == .codeBlock {
            // Exiting code block
            switch settingsManager.codeBlockNotificationStyle {
            case .smartDetection, .tonesOnly, .both:
                audioFeedback.playFeedback(for: .codeBlockEnd)
                // Note: Extended post-utterance delay in setupUtteranceParameters handles timing
            case .voiceOnly:
                // No end tone for voice-only mode
                break
            }
        } else {
            // Regular section change (paragraph to paragraph) - no audio feedback needed
            // Only code blocks get special audio treatment for a cleaner experience
        }
    }
    
    private func handleCodeBlockEntry(_ section: ContentSection) {
        let notificationStyle = settingsManager.codeBlockNotificationStyle
        
        switch notificationStyle {
        case .smartDetection:
            // Play tone synchronously, then provide language notification
            playCodeBlockToneAndWait {
                if self.settingsManager.isCodeBlockLanguageNotificationEnabled,
                   let language = self.extractLanguageFromSection(section) {
                    self.provideSubtleLanguageNotification(language)
                }
            }
            
        case .voiceOnly:
            // Only provide language notification (no tones)
            if settingsManager.isCodeBlockLanguageNotificationEnabled,
               let language = extractLanguageFromSection(section) {
                provideSubtleLanguageNotification(language)
            }
            
        case .tonesOnly:
            // Play tones synchronously (no voice)
            playCodeBlockToneAndWait {}
            
        case .both:
            // Play tones synchronously, then provide language notification
            playCodeBlockToneAndWait {
                if self.settingsManager.isCodeBlockLanguageNotificationEnabled,
                   let language = self.extractLanguageFromSection(section) {
                    self.provideSubtleLanguageNotification(language)
                }
            }
        }
    }
    
    private func playCodeBlockToneAndWait(completion: @escaping () -> Void) {
        // Play tone and wait for actual completion, plus extra breathing room
        audioFeedback.playCodeBlockStartTone { [weak self] in
            // Add extra pause after tone completes before language notification
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                completion()
            }
        }
    }
    
    
    private func extractLanguageFromSection(_ section: ContentSection) -> String? {
        // Extract language from the original text (e.g., "[swift code]" -> "swift")
        let spokenText = section.parsedContent?.plainText ?? ""
        let startIndex = Int(section.startIndex)
        let endIndex = Int(section.endIndex)
        
        guard startIndex < endIndex, startIndex >= 0, endIndex <= spokenText.count else {
            return nil
        }
        
        let sectionText = String(spokenText.dropFirst(startIndex).prefix(endIndex - startIndex))
        
        // Parse language from "[language code]" format
        if sectionText.hasPrefix("[") && sectionText.contains(" code]") {
            let languagePart = sectionText.dropFirst().dropLast(" code]".count)
            return languagePart.trimmingCharacters(in: .whitespaces)
        }
        
        return nil
    }
    
    private func provideSubtleLanguageNotification(_ language: String) {
        guard !language.isEmpty else { return }
        
        // Create a very brief, quiet utterance for the language
        let utterance = AVSpeechUtterance(string: language)
        utterance.volume = volumeMultiplier * 0.3  // Much quieter than main content
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.8  // Faster delivery
        utterance.pitchMultiplier = 1.1  // Slightly higher pitch
        utterance.voice = selectedVoice ?? getBestAvailableVoice()
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = 0.05
        
        synthesizer.speak(utterance)
    }
}