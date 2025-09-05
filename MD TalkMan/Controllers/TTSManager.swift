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
    
    // MARK: - Shared Instance
    static let shared = TTSManager()
    
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
    private lazy var interjectionManager = InterjectionManager(audioFeedback: audioFeedback)
    
    // Visual text display integration
    @Published var textWindowManager = TextWindowManager()
    
    // MARK: - Queue-Based Architecture Integration
    private let utteranceQueueManager = UtteranceQueueManager()
    private var queuedUtterancesInSynthesizer: Set<ObjectIdentifier> = []
    private var currentQueuedUtterance: QueuedUtterance?
    internal var isQueueMode: Bool = true  // Feature flag for testing - internal for test access
    
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
    
    // Deferred interjections
    private var pendingInterjection: InterjectionEvent?
    
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
            let savedPosition = Int(progress.currentPosition)
            totalDuration = progress.totalDuration
            
            // Check if we're at the end of content (completed) - if so, restart from beginning
            if let plainText = currentParsedContent?.plainText,
               savedPosition >= plainText.count - 10 {  // Within 10 chars of end
                print("🔄 File was completed, restarting from beginning")
                currentPosition = 0
                progress.currentPosition = 0
                progress.isCompleted = false
            } else {
                currentPosition = savedPosition
                print("💫 Resuming from saved position: \(currentPosition)")
            }
            
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
        
        // Handle pause resume
        if playbackState == .paused {
            playbackState = .loading
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                
                if self.synthesizer.continueSpeaking() {
                    self.playbackState = .playing
                } else {
                    // Fallback: restart with queue-based approach
                    if self.isQueueMode {
                        self.startQueueBasedPlayback()
                    } else {
                        self.restartFromCurrentPosition()
                    }
                }
            }
            return
        }
        
        playbackState = .preparing
        
        // Use queue-based or legacy playback
        if isQueueMode {
            startQueueBasedPlayback()
        } else {
            startLegacyPlayback()
        }
    }
    
    // MARK: - Queue-Based Playback
    private func startQueueBasedPlayback() {
        print("🚀 Starting queue-based playback from position \(currentPosition)")
        
        // Pre-generate initial utterances for seamless playback
        preloadUtteranceQueue(from: currentPosition)
        
        // Start playing first utterance
        if let nextUtterance = utteranceQueueManager.fetchNextFromUtteranceQueue() {
            playQueuedUtterance(nextUtterance)
        } else {
            playbackState = .error("No content to queue")
            errorMessage = "Failed to generate initial utterances"
            audioFeedback.playFeedback(for: .error)
        }
    }
    
    private func preloadUtteranceQueue(from startPosition: Int) {
        guard let parsedContent = currentParsedContent,
              let plainText = parsedContent.plainText else { return }
        
        let maxPreloadUtterances = 3
        var position = startPosition
        
        for i in 0..<maxPreloadUtterances {
            print("🔍 Loop \(i): position=\(position), plainText.count=\(plainText.count)")
            guard position < plainText.count else { 
                print("🔍 Breaking: position >= plainText.count")
                break 
            }
            
            // Use existing section-boundary logic
            print("🔍 Finding boundary from \(position)")
            let chunkEndPosition = findNextInterjectionBoundary(from: position, maxSize: 50000)
            print("🔍 Boundary found: \(chunkEndPosition)")
            
            guard position < chunkEndPosition else { 
                print("🔍 Breaking: position >= chunkEndPosition (\(position) >= \(chunkEndPosition))")
                break 
            }
            
            print("🔍 Getting text chunk \(position)-\(chunkEndPosition)")
            // Safe text chunking using String.prefix/dropFirst instead of String.Index
            var textChunk = ""
            if position >= 0 && chunkEndPosition <= plainText.count && position < chunkEndPosition {
                let prefixedText = String(plainText.prefix(chunkEndPosition))
                textChunk = String(prefixedText.dropFirst(position))
            }
            print("🔍 Got text chunk: \(textChunk.count) characters")
            
            // Simple approach: Use the chunk as-is, let each utterance handle its own voice
            // The setupUtteranceParameters function will detect markers and switch voices appropriately
            let actualChunkEndPosition = position + textChunk.count
            print("🔍 Using chunk as-is: \(position)-\(actualChunkEndPosition) (\(textChunk.count) chars)")
            
            guard !textChunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
                print("🔍 Breaking: empty text chunk")
                break 
            }
            
            // Create queued utterance - BUT keep markers for voice detection in setupUtteranceParameters
            print("🔍 Creating AVSpeechUtterance")
            print("🔍 Original text chunk: \"\(textChunk.prefix(50))...\"")
            print("🔍 Contains marker in chunk: \(textChunk.contains("\u{200B}🎤\u{200B}"))")
            let utterance = AVSpeechUtterance(string: textChunk) // Keep markers for now
            print("🔍 Setting up utterance parameters")
            let finalUtterance = setupUtteranceParameters(utterance)
            
            print("🔍 Finding section index")
            let sectionIndex = findSectionIndexForPosition(position)
            print("🔍 Generating metadata")
            let metadata = generateMetadataForPosition(position)
            
            // Language announcements now handled naturally by the parser
            // Parser generates: "Swift code block. [actual code] Swift code block ends."
            // No need for zero-length interjection utterances
            
            print("🔍 Creating QueuedUtterance")
            let queuedUtterance = QueuedUtterance(
                utterance: finalUtterance,
                startPosition: position,
                endPosition: actualChunkEndPosition,
                sectionIndex: sectionIndex,
                isInterjection: false,
                priority: .normal,
                metadata: metadata,
                performance: nil
            )
            
            print("🔍 Appending to queue")
            utteranceQueueManager.appendUtterance(queuedUtterance)
            position = actualChunkEndPosition
            
            print("📝 Pre-loaded utterance \(i+1): \(queuedUtterance.startPosition)-\(queuedUtterance.endPosition)")
        }
        
        print("✅ Pre-loaded \(utteranceQueueManager.queueCount) utterances for seamless playback")
    }
    
    private func playQueuedUtterance(_ queuedUtterance: QueuedUtterance) {
        currentQueuedUtterance = queuedUtterance
        currentPosition = queuedUtterance.startPosition
        updateCurrentSectionIndex()
        
        let utteranceId = ObjectIdentifier(queuedUtterance.utterance)
        queuedUtterancesInSynthesizer.insert(utteranceId)
        
        print("🎵 Playing queued utterance: \(queuedUtterance.startPosition)-\(queuedUtterance.endPosition)")
        
        // Add delay to allow audio session and interjections to settle (same as legacy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.synthesizer.speak(queuedUtterance.utterance)
        }
        
        // Pre-load next utterances if queue is getting low
        if utteranceQueueManager.queueCount <= 1 {
            preloadNextUtterances()
        }
    }
    
    private func preloadNextUtterances() {
        guard let lastUtterance = utteranceQueueManager.getLastUtterance() else { return }
        
        let nextPosition = lastUtterance.endPosition
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.preloadUtteranceQueue(from: nextPosition)
        }
    }
    
    func pause() {
        guard playbackState == .playing || playbackState == .preparing else { return }
        
        playbackState = .loading
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            if self.synthesizer.pauseSpeaking(at: .immediate) {
                self.playbackState = .paused
                
                // Save progress in queue mode
                if self.isQueueMode {
                    self.saveProgress()
                }
            } else {
                // Fallback: stop and save position
                self.synthesizer.stopSpeaking(at: .immediate)
                self.playbackState = .paused
            }
        }
    }
    
    func stop() {
        print("🛑 TTSManager: stop() called - setting userRequestedStop = true")
        print("🛑 Call stack: \(Thread.callStackSymbols.prefix(5))")
        userRequestedStop = true
        
        // Stop any ongoing volume fading
        stopVolumeFading()
        
        // Clear queue state in queue mode
        if isQueueMode {
            queuedUtterancesInSynthesizer.removeAll()
            currentQueuedUtterance = nil
            // Note: We preserve utteranceQueueManager queues for potential resume
        }
        
        synthesizer.stopSpeaking(at: .immediate)
        playbackState = .idle
        currentUtterance = nil
        audioFeedback.playFeedback(for: .playStopped)
    }
    
    func rewind(seconds: TimeInterval = 5.0) {
        if isQueueMode && utteranceQueueManager.hasRecycledContent {
            // Try instant replay from RecycleQueue first
            if let replayUtterances = utteranceQueueManager.findReplayUtterances(seconds: seconds) {
                print("⚡ Instant rewind using RecycleQueue: \(replayUtterances.count) utterances")
                
                // Clear current queue
                utteranceQueueManager.clearMainQueue()
                queuedUtterancesInSynthesizer.removeAll()
                
                // Stop current playback
                synthesizer.stopSpeaking(at: .immediate)
                
                // Create fresh utterances (can't reuse spoken ones)
                for replayUtterance in replayUtterances {
                    let originalText = replayUtterance.utterance.speechString
                    let freshUtterance = AVSpeechUtterance(string: originalText)
                    let finalFreshUtterance = setupUtteranceParameters(freshUtterance)
                    
                    let freshQueuedUtterance = QueuedUtterance(
                        utterance: finalFreshUtterance,
                        startPosition: replayUtterance.startPosition,
                        endPosition: replayUtterance.endPosition,
                        sectionIndex: replayUtterance.sectionIndex,
                        isInterjection: replayUtterance.isInterjection,
                        priority: replayUtterance.priority,
                        metadata: replayUtterance.metadata,
                        performance: nil
                    )
                    
                    utteranceQueueManager.appendUtterance(freshQueuedUtterance)
                }
                
                // Update position and restart
                if let firstUtterance = replayUtterances.first {
                    currentPosition = firstUtterance.startPosition
                    updateCurrentSectionIndex()
                }
                
                // Resume playback if it was playing
                if playbackState == .playing {
                    play()
                }
                
                audioFeedback.playFeedback(for: .buttonTap)  // Use existing feedback type
                return
            }
        }
        
        // Fallback to regeneration approach
        print("🔄 Using regeneration approach for rewind")
        let estimatedWordsPerMinute: Double = 150
        let wordsPerSecond = estimatedWordsPerMinute / 60
        let charactersPerSecond = wordsPerSecond * 5
        
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
    
    /// Get the shared synthesizer for interjection use
    /// - Returns: The synthesizer instance used by this TTS manager
    func getSynthesizer() -> AVSpeechSynthesizer? {
        return synthesizer
    }
    
    /// Get the interjection manager for testing
    /// - Returns: The interjection manager instance
    func getInterjectionManager() -> InterjectionManager {
        return interjectionManager
    }
    
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
    
    // Removed stopSpeakingImmediate - using natural TTS flow instead
    
    private func setupUtteranceParameters(_ utterance: AVSpeechUtterance) -> AVSpeechUtterance {
        // Check for female voice marker (invisible Unicode markers from parser)
        let text = utterance.speechString
        let hasFemaleVoiceMarker = text.contains("\u{200B}🎤\u{200B}")
        
        // Debug logging to understand what we're getting
        print("🔍 Voice Detection Debug:")
        print("  Text length: \(text.count)")
        print("  Text preview: \"\(text.prefix(50))...\"")
        print("  Contains marker: \(hasFemaleVoiceMarker)")
        
        // Create new utterance with cleaned text if needed
        let finalUtterance: AVSpeechUtterance
        if hasFemaleVoiceMarker {
            let cleanedText = text.replacingOccurrences(of: "\u{200B}🎤\u{200B}", with: "")
            finalUtterance = AVSpeechUtterance(string: cleanedText)
            
            // Use female voice for marked announcements
            let femaleVoice = settingsManager.getSelectedInterjectionVoice() 
                           ?? settingsManager.getDefaultInterjectionVoice() 
                           ?? selectedVoice 
                           ?? getBestAvailableVoice()
            finalUtterance.voice = femaleVoice
            print("🎤 Using female voice for marked announcement: \"\(cleanedText.prefix(30))...\"")
        } else {
            finalUtterance = utterance
            // Use selected voice or fallback to best available
            finalUtterance.voice = selectedVoice ?? getBestAvailableVoice()
            print("👨 Using main voice for content")
        }
        
        // Speech rate (convert user-friendly speed to AVSpeechUtterance rate)
        // User speed: 0.5x-2.0x -> AVSpeech rate: 0.25-1.0 (0.5 = normal)
        finalUtterance.rate = AVSpeechUtteranceDefaultSpeechRate * playbackSpeed
        
        // Pitch adjustment for more natural sound
        finalUtterance.pitchMultiplier = pitchMultiplier
        
        // Volume control
        finalUtterance.volume = volumeMultiplier
        
        // Extended pre-utterance delay for smoother transitions
        finalUtterance.preUtteranceDelay = 0.3
        
        // Dynamic post-utterance delay based on content type
        finalUtterance.postUtteranceDelay = getPostUtteranceDelay()
        
        return finalUtterance
    }
    
    private func getPostUtteranceDelay() -> TimeInterval {
        // Check if current section is a code block that might need extra pause time
        guard currentSectionIndex >= 0 && currentSectionIndex < contentSections.count else {
            return 0.4  // Default delay
        }
        
        let currentSection = contentSections[currentSectionIndex]
        
        // If we're in a code block, add extra delay to allow end tones to play
        if currentSection.typeEnum == .codeBlock {
            return 1.2  // Longer delay for code blocks to accommodate end tones
        }
        
        return 0.6  // Standard delay for regular content
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
        
        // Use section-boundary aware chunking for optimal interjection timing
        // This allows interjections to play between natural content segments
        let maxChunkSize = 50000  // ~50KB chunks - good balance of performance vs memory
        let endPos = findNextInterjectionBoundary(from: startPos, maxSize: maxChunkSize)
        
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
    
    /// Find the optimal position to end a TTS chunk, prioritizing section boundaries for interjection insertion
    /// - Parameters:
    ///   - startPos: Current position in text
    ///   - maxSize: Maximum chunk size (fallback)
    /// - Returns: Position where chunk should end
    private func findNextInterjectionBoundary(from startPos: Int, maxSize: Int) -> Int {
        guard let parsedContent = currentParsedContent,
              let plainText = parsedContent.plainText else {
            return startPos + maxSize
        }
        
        let totalLength = plainText.count
        let maxEndPos = min(startPos + maxSize, totalLength)
        
        print("🔍 TTSManager: Finding interjection boundary from \(startPos) to max \(maxEndPos)")
        
        // Find sections that start within this potential chunk range
        let sectionsInRange = contentSections.filter { section in
            Int(section.startIndex) > startPos && Int(section.startIndex) <= maxEndPos
        }.sorted { $0.startIndex < $1.startIndex }
        
        print("🔍 TTSManager: Found \(sectionsInRange.count) sections in range")
        
        // Priority 1: Stop before code blocks to allow interjections
        if let codeBlockSection = sectionsInRange.first(where: { $0.typeEnum == .codeBlock }) {
            let boundaryPos = Int(codeBlockSection.startIndex)
            print("🎯 TTSManager: Found code block boundary at position \(boundaryPos) - chunking will stop here")
            return boundaryPos
        }
        
        // Priority 2: Stop at header boundaries for clean transitions
        if let headerSection = sectionsInRange.first(where: { $0.typeEnum == .header }) {
            let boundaryPos = Int(headerSection.startIndex)
            print("📝 TTSManager: Found header boundary at position \(boundaryPos)")
            return boundaryPos
        }
        
        // Priority 3: Use paragraph boundaries (but not too small chunks)
        let minChunkSize = 1000  // Don't create tiny chunks
        if let paragraphSection = sectionsInRange.first(where: { 
            $0.typeEnum == .paragraph && Int($0.startIndex) - startPos >= minChunkSize 
        }) {
            let boundaryPos = Int(paragraphSection.startIndex)
            print("📄 TTSManager: Found paragraph boundary at position \(boundaryPos)")
            return boundaryPos
        }
        
        // Priority 4: Fallback to original max size approach
        print("⬅️ TTSManager: No suitable section boundary found, using max size \(maxEndPos)")
        return maxEndPos
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
            
            print("🗣️ TTSManager: Utterance finished - speechString length: \(utterance.speechString.count)")
            print("🔍 TTSManager: User requested stop: \(self.userRequestedStop)")
            print("🔍 TTSManager: Synthesizer is speaking: \(self.synthesizer.isSpeaking)")
            print("🔍 TTSManager: Queue mode: \(self.isQueueMode)")
            
            if utterance.speechString.isEmpty {
                self.playbackState = .error("No content to read")
                self.errorMessage = "No content available for playback"
                self.audioFeedback.playFeedback(for: .error)
                return
            }
            
            // Check if user explicitly stopped playback
            if self.userRequestedStop && !self.synthesizer.isSpeaking {
                print("📱 TTSManager: User requested stop and synthesizer stopped - setting to idle")
                self.playbackState = .idle
                self.audioFeedback.playFeedback(for: .playStopped)
                return
            }
            
            if self.isQueueMode {
                self.handleQueueBasedUtteranceCompletion(utterance)
            } else {
                self.handleLegacyUtteranceCompletion(utterance)
            }
        }
    }
    
    private func handleQueueBasedUtteranceCompletion(_ utterance: AVSpeechUtterance) {
        let utteranceId = ObjectIdentifier(utterance)
        queuedUtterancesInSynthesizer.remove(utteranceId)
        
        // Move completed utterance to recycle queue for instant replay
        if let completedUtterance = currentQueuedUtterance,
           ObjectIdentifier(completedUtterance.utterance) == utteranceId {
            
            // Calculate performance metrics
            let performance = UtterancePerformance(
                actualDuration: 0, // Could track actual timing here
                charactersPerSecond: Double(utterance.speechString.count) / 5.0, // Rough estimate
                completedAt: Date()
            )
            
            utteranceQueueManager.moveToRecycleQueue(completedUtterance, performance: performance)
            
            // Update position ONLY for main content, NOT for interjections
            if !completedUtterance.isInterjection {
                currentPosition = completedUtterance.endPosition
                updateCurrentSectionIndex()
                
                // Update text window manager for main content only
                textWindowManager.updateWindow(for: currentPosition)
                
                print("📝 Position updated to: \(currentPosition) (section \(currentSectionIndex))")
            } else {
                print("🎤 Interjection completed - position unchanged: \(currentPosition)")
            }
            
            saveProgress()
        }
        
        // Check for completion
        if utteranceQueueManager.queueCount == 0 && queuedUtterancesInSynthesizer.isEmpty {
            if !hasMoreContentToRead() || isAtEndOfContent() {
                print("✅ TTSManager: Queue completed - marking as finished")
                playbackState = .idle
                
                if let markdownFile = currentMarkdownFile,
                   let progress = markdownFile.readingProgress {
                    progress.isCompleted = true
                    saveProgress()
                    audioFeedback.playFeedback(for: .playCompleted)
                } else {
                    audioFeedback.playFeedback(for: .playStopped)
                }
                return
            } else {
                // Pre-load more content
                preloadNextUtterances()
            }
        }
        
        // Play next utterance from queue
        if let nextUtterance = utteranceQueueManager.fetchNextFromUtteranceQueue() {
            playQueuedUtterance(nextUtterance)
        }
    }
    
    private func handleLegacyUtteranceCompletion(_ utterance: AVSpeechUtterance) {
        // Update position to end of current utterance
        currentPosition = utteranceStartPosition + utterance.speechString.count
        
        // Check if we've reached the actual end of content
        if !hasMoreContentToRead() || isAtEndOfContent() {
            // Truly finished - mark as completed
            print("✅ TTSManager: Reached end of content - marking as completed")
            playbackState = .idle
            
            if let markdownFile = currentMarkdownFile,
               let progress = markdownFile.readingProgress {
                progress.isCompleted = true
                saveProgress()
                audioFeedback.playFeedback(for: .playCompleted)
            } else {
                audioFeedback.playFeedback(for: .playStopped)
            }
        } else {
            print("🔄 TTSManager: Continuing TTS to next section")
            // Continue reading the next chunk automatically
            play()
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
        if isQueueMode {
            // Queue mode: Use queue-based position tracking
            // Position is managed by handleQueueBasedUtteranceCompletion()
            if let currentQueued = currentQueuedUtterance {
                let utterancePosition = currentQueued.startPosition + characterRange.location
                
                // Only update text window for main content, not interjections
                if !currentQueued.isInterjection {
                    textWindowManager.updateWindow(for: utterancePosition)
                }
                
                // Handle section transitions for interjections
                let previousSectionIndex = currentSectionIndex
                if utterancePosition != currentPosition {
                    // Temporarily update for section detection
                    let tempPosition = currentPosition
                    currentPosition = utterancePosition
                    updateCurrentSectionIndex()
                    
                    if currentSectionIndex != previousSectionIndex {
                        handleSectionTransition(from: previousSectionIndex, to: currentSectionIndex)
                    }
                    
                    // Restore position if this was an interjection
                    if currentQueued.isInterjection {
                        currentPosition = tempPosition
                    }
                }
            }
        } else {
            // Legacy mode: Use original single-utterance logic
            let previousSectionIndex = currentSectionIndex
            currentPosition = utteranceStartPosition + characterRange.location
            updateCurrentSectionIndex()
            
            // Update text window in legacy mode
            textWindowManager.updateWindow(for: currentPosition)
            
            // Check if we've moved to a new section
            if currentSectionIndex != previousSectionIndex {
                handleSectionTransition(from: previousSectionIndex, to: currentSectionIndex)
            }
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
        
        // Code block transitions now handled naturally by parser text
        if toSection.typeEnum == .codeBlock && fromSection.typeEnum != .codeBlock {
            // Code block entry - no special handling needed (parser handles announcements)
            print("🎯 TTSManager: Entering code block - handled by parser text")
            
        } else if toSection.typeEnum != .codeBlock && fromSection.typeEnum == .codeBlock {
            // Code block endings now handled naturally by parser text
            // Parser generates: "Swift code block. [code] Swift code block ends."
            print("🎯 TTSManager: Code block section completed - ending handled by parser")
        } else {
            // Regular section change (paragraph to paragraph) - no audio feedback needed
            // Only code blocks get special audio treatment for a cleaner experience
        }
    }
    
    // MARK: - Section-Based Interjection Handling (replaces interference detection)
    
    // MARK: - Interjection Event Handling (Legacy - kept for compatibility)
    private func handleInterjectionEvent(_ event: InterjectionEvent) {
        print("🎯 TTSManager: Executing interjection event immediately")
        
        // Execute interjection immediately during section transitions
        // This avoids the issue of multiple interjections overwriting each other
        interjectionManager.handleInterjection(event, ttsManager: self) {
            print("✅ TTSManager: Interjection completed during section transition")
            // Interjection completed, TTS will continue naturally
        }
    }
    
    
    // MARK: - Smart Chunking Helper
    
    
    // MARK: - Legacy handleCodeBlockEntry removed - now handled by InterjectionManager
    
    // MARK: - Legacy playCodeBlockToneAndWait removed - now handled by InterjectionManager
    
    
    internal func extractLanguageFromSection(_ section: ContentSection) -> String? {
        // Extract language from originalText instead of spokenText since we now include actual code content
        guard section.typeEnum == .codeBlock else {
            print("🔍 extractLanguage: Skipping non-code-block section")
            return nil
        }
        
        // Get the original text from the ParsedSection (stored in Core Data)
        // We need to access this through the section's parsedContent relationship
        // Since ContentSection doesn't directly store originalText, we'll parse from the first line
        
        // Alternative approach: extract from the section's position in the original text
        guard let parsedContent = section.parsedContent,
              let plainText = parsedContent.plainText,
              !plainText.isEmpty else {
            print("🔍 extractLanguage: No parsed content available")
            return nil
        }
        
        // For now, let's check if the spoken text still has language info at the beginning
        // This is a fallback - we might need to store language info differently later
        let startIndex = Int(section.startIndex)
        let endIndex = Int(section.endIndex)
        
        print("🔍 extractLanguage: Checking for language info - start=\(startIndex), end=\(endIndex), textLength=\(plainText.count)")
        
        // Safe bounds checking
        guard startIndex >= 0,
              endIndex > startIndex,
              endIndex <= plainText.count,
              (endIndex - startIndex) < 2000 else {  // Increased limit for actual code content
            print("🔍 extractLanguage: Invalid bounds, returning nil")
            return nil
        }
        
        // Safe text extraction using prefix/dropFirst (no String.Index)
        var sectionText = ""
        if endIndex <= plainText.count && startIndex < endIndex {
            let prefixedText = String(plainText.prefix(endIndex))
            sectionText = String(prefixedText.dropFirst(startIndex))
        }
        
        print("🔍 extractLanguage: Extracted section text: \"\(sectionText.prefix(100))...\" (\(sectionText.count) chars)")
        
        // NEW FORMAT: Parse language from "[language:code]" format  
        if sectionText.hasPrefix("[") && sectionText.contains(":") && sectionText.contains("]") {
            // Extract language from "[language:code content]" format
            if let colonIndex = sectionText.firstIndex(of: ":") {
                let languagePart = String(sectionText[sectionText.index(after: sectionText.startIndex)..<colonIndex])
                let language = languagePart.trimmingCharacters(in: .whitespaces)
                if !language.isEmpty && language != "code" { // Avoid extracting "code" as language
                    print("🔍 extractLanguage: Found language from new format: \"\(language)\"")
                    return language
                }
            }
        }
        
        // FALLBACK 1: Check if old placeholder format still exists (for backward compatibility)
        if sectionText.hasPrefix("[") && sectionText.contains(" code]") {
            let parts = sectionText.components(separatedBy: " code]")
            if let languagePart = parts.first?.dropFirst() { // Remove "["
                let language = String(languagePart).trimmingCharacters(in: .whitespaces)
                print("🔍 extractLanguage: Found language from old placeholder format: \"\(language)\"")
                return language.isEmpty ? nil : language
            }
        }
        
        // FALLBACK 2: Try to detect language from common code patterns
        let detectedLanguage = detectLanguageFromCode(sectionText)
        if let language = detectedLanguage {
            print("🔍 extractLanguage: Detected language from code patterns: \"\(language)\"")
            return language
        }
        
        print("🔍 extractLanguage: No language info found")
        return nil
    }
    
    // MARK: - Language Detection from Code Content
    private func detectLanguageFromCode(_ codeText: String) -> String? {
        let lowercased = codeText.lowercased()
        
        // Swift detection
        if lowercased.contains("func ") || lowercased.contains("var ") || lowercased.contains("let ") || 
           lowercased.contains("import ") || lowercased.contains("struct ") || lowercased.contains("class ") ||
           lowercased.contains("@") && (lowercased.contains("state") || lowercased.contains("binding")) {
            return "swift"
        }
        
        // JavaScript/TypeScript detection
        if lowercased.contains("function ") || lowercased.contains("const ") || lowercased.contains("=> ") || 
           lowercased.contains("console.log") || lowercased.contains("document.") {
            return "javascript"
        }
        
        // Python detection
        if lowercased.contains("def ") || lowercased.contains("import ") || lowercased.contains("print(") ||
           lowercased.contains("if __name__") || lowercased.range(of: "^\\s*#", options: .regularExpression) != nil {
            return "python"
        }
        
        // Java detection
        if lowercased.contains("public class") || lowercased.contains("public static void main") ||
           lowercased.contains("system.out.println") {
            return "java"
        }
        
        // HTML detection
        if lowercased.contains("<html") || lowercased.contains("<!doctype") || 
           lowercased.contains("<body") || lowercased.contains("<div") {
            return "html"
        }
        
        // CSS detection
        if lowercased.contains("{") && lowercased.contains(":") && lowercased.contains(";") &&
           (lowercased.contains("color") || lowercased.contains("margin") || lowercased.contains("padding")) {
            return "css"
        }
        
        return nil
    }
    
    // MARK: - Queue-Based Helper Methods
    
    private func getTextChunk(from plainText: String, start: Int, end: Int) -> String {
        print("🔍 getTextChunk: Called with start=\(start), end=\(end), plainText.count=\(plainText.count)")
        
        guard start < end, start >= 0, end <= plainText.count else { 
            print("🔍 getTextChunk: Invalid bounds, returning empty string")
            return "" 
        }
        
        print("🔍 getTextChunk: Converting to Array")
        // Use safer substring approach to avoid String.Index hang issues
        let textArray = Array(plainText)
        print("🔍 getTextChunk: Array created with \(textArray.count) characters")
        
        guard start < textArray.count && end <= textArray.count else { 
            print("🔍 getTextChunk: Array bounds check failed, returning empty string")
            return "" 
        }
        
        print("🔍 getTextChunk: Extracting substring")
        let result = String(textArray[start..<end])
        print("🔍 getTextChunk: Returning \(result.count) characters")
        return result
    }
    
    private func findSectionIndexForPosition(_ position: Int) -> Int {
        for (index, section) in contentSections.enumerated() {
            if position >= section.startIndex && position < section.endIndex {
                return index
            }
        }
        return currentSectionIndex // Fallback to current
    }
    
    private func generateMetadataForPosition(_ position: Int) -> UtteranceMetadata? {
        print("🔍 generateMetadata: Finding section for position \(position)")
        let sectionIndex = findSectionIndexForPosition(position)
        print("🔍 generateMetadata: Found section index \(sectionIndex)")
        
        guard sectionIndex >= 0 && sectionIndex < contentSections.count else { 
            print("🔍 generateMetadata: Invalid section index, returning nil")
            return nil 
        }
        
        let section = contentSections[sectionIndex]
        print("🔍 generateMetadata: Section type is \(section.typeEnum)")
        
        print("🔍 generateMetadata: About to check if section is codeBlock")
        let isCodeBlock = section.typeEnum == .codeBlock
        print("🔍 generateMetadata: isCodeBlock = \(isCodeBlock)")
        
        // Language extraction disabled - now handled by parser's natural text
        let language: String? = nil
        print("🔍 generateMetadata: Language extraction disabled (handled by parser)")
        
        print("🔍 generateMetadata: Creating UtteranceMetadata object")
        let metadata = UtteranceMetadata(
            contentType: section.typeEnum,
            language: language,
            isSkippable: section.isSkippable,
            interjectionEvents: []
        )
        print("🔍 generateMetadata: UtteranceMetadata created successfully")
        return metadata
    }
    
    // Legacy single-utterance playback (fallback)
    private func startLegacyPlayback() {
        let textToSpeak = getTextFromCurrentPosition()
        print("🎙️ TTSManager: Retrieved chunk of \(textToSpeak.count) characters from position \(currentPosition)")
        
        guard !textToSpeak.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            playbackState = .error("No content at position")
            errorMessage = "No content available at current position"
            audioFeedback.playFeedback(for: .error)
            return
        }
        
        // Create utterance with enhanced settings - keep markers for voice detection
        let tempUtterance = AVSpeechUtterance(string: textToSpeak)
        currentUtterance = setupUtteranceParameters(tempUtterance)
        
        // Remember where this utterance starts in the document
        utteranceStartPosition = currentPosition
        
        // Add longer pause to allow tones to complete and create breathing room
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, let utterance = self.currentUtterance else { return }
            self.synthesizer.speak(utterance)
        }
    }
    
    // MARK: - Context Recovery Features
    func replayLastSection() {
        guard isQueueMode else {
            print("⚠️ Replay features only available in queue mode")
            return
        }
        
        if let lastMainUtterance = utteranceQueueManager.getLastMainContentUtterance() {
            replayFromPosition(lastMainUtterance.startPosition, reason: "last section replay")
        } else {
            audioFeedback.playFeedback(for: .error)
        }
    }
    
    func replayForContext() {
        guard isQueueMode else { return }
        
        let contextUtterances = utteranceQueueManager.getContextReplayUtterances()
        guard !contextUtterances.isEmpty else {
            audioFeedback.playFeedback(for: .error)
            return
        }
        
        if let firstContextUtterance = contextUtterances.first {
            replayFromPosition(firstContextUtterance.startPosition, reason: "context recovery")
        }
    }
    
    private func replayFromPosition(_ position: Int, reason: String) {
        print("🔄 Replaying from position \(position) - \(reason)")
        
        // Clear current queue
        utteranceQueueManager.clearMainQueue()
        queuedUtterancesInSynthesizer.removeAll()
        
        // Stop current playback
        synthesizer.stopSpeaking(at: .immediate)
        
        // Set new position
        currentPosition = position
        updateCurrentSectionIndex()
        
        // Restart playback
        play()
    }
    
    // MARK: - Legacy provideSubtleLanguageNotification removed - now handled by InterjectionManager
}
