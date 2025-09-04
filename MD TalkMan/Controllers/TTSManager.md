# TTSManager Architecture Guide

## Overview

The TTSManager is the core audio controller for MD TalkMan, providing sophisticated text-to-speech functionality optimized for hands-free markdown reading while driving. It combines SwiftUI reactive patterns with AVFoundation's speech synthesis for a seamless audio experience.

## Architecture Design

### Core Responsibilities

- **Audio Synthesis**: Convert parsed markdown text to natural speech
- **Playback Control**: Play, pause, stop, and navigation controls
- **State Management**: Track playback state and reading progress
- **Voice Customization**: Premium voice selection and parameter tuning
- **Section Navigation**: Smart section jumping and skippable content
- **Progress Persistence**: Save and restore reading position
- **Interjection Coordination**: Manage context-aware voice announcements
- **Section-Boundary Chunking**: Intelligent text chunking for interjection timing

### Design Patterns Used

#### 1. **Observable Object Pattern**
```swift
class TTSManager: NSObject, ObservableObject {
    @Published var playbackState: TTSPlaybackState = .idle
    @Published var currentPosition: Int = 0
    @Published var selectedVoice: AVSpeechSynthesisVoice?
    @Published var playbackSpeed: Float = 0.5
}
```

#### 2. **Delegate Pattern**
```swift
extension TTSManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, 
                          didStart utterance: AVSpeechUtterance)
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, 
                          willSpeakRangeOfSpeechString characterRange: NSRange)
}
```

#### 3. **Strategy Pattern**
```swift
// Different voice selection strategies
private func getBestAvailableVoice() -> AVSpeechSynthesisVoice?
private func setupEnhancedVoices()
private func setupUtteranceParameters(_ utterance: AVSpeechUtterance)
```

## Key Components

### State Management

**TTSPlaybackState Enum**
```swift
enum TTSPlaybackState {
    case idle       // Ready to play
    case playing    // Currently speaking
    case paused     // Temporarily stopped
    case preparing  // Loading content
}
```

**Published Properties**
- `playbackState`: Current audio state for UI updates
- `currentPosition`: Character position in text for progress tracking
- `currentSectionIndex`: Active section for navigation
- `selectedVoice`: Current voice for speech synthesis
- `playbackSpeed`: Speed multiplier (0.5x - 2.0x)
- `pitchMultiplier`: Voice pitch adjustment
- `volumeMultiplier`: Volume control

### Voice Enhancement System

**Premium Voice Selection**
```swift
private func getBestAvailableVoice() -> AVSpeechSynthesisVoice? {
    let preferredVoices = [
        "com.apple.voice.enhanced.en-US.Ava",      // Neural
        "com.apple.voice.enhanced.en-US.Samantha", // Enhanced
        "com.apple.voice.enhanced.en-US.Alex",     // Enhanced
        "com.apple.voice.premium.en-US.Zoe",       // Premium
        "com.apple.voice.premium.en-US.Evan"       // Premium
    ]
}
```

**Voice Quality Prioritization**
1. **Enhanced Voices** - Neural network-based, most natural
2. **Premium Voices** - High-quality synthesis
3. **Standard Voices** - Fallback for compatibility

### Audio Session Configuration

**Driving-Optimized Setup**
```swift
private func setupAudioSession() {
    try audioSession?.setCategory(.playback, 
                                 mode: .spokenAudio, 
                                 options: [.allowBluetooth, .allowBluetoothA2DP])
}
```

**Benefits for Hands-Free Use**
- **Spoken Audio Mode**: Optimized for speech clarity in cars
- **Bluetooth A2DP**: High-quality car audio system compatibility  
- **Background Playback**: Continues during navigation/phone calls
- **CarPlay Integration**: Native steering wheel control support

## Core Functionality

### Content Loading Pipeline

**1. Markdown File Association**
```swift
func loadMarkdownFile(_ markdownFile: MarkdownFile, context: NSManagedObjectContext) {
    currentMarkdownFile = markdownFile
    currentParsedContent = markdownFile.parsedContent
    contentSections = sections.sorted { $0.startIndex < $1.startIndex }
}
```

**2. Section Processing**
- Load content sections from Core Data
- Identify skippable sections (code blocks, technical content)
- Sort sections by position for navigation

**3. Progress Restoration**
- Restore reading position from Core Data
- Calculate current section based on character position
- Resume from exact stopping point

### Playback Control System

**Primary Controls**
```swift
func play()    // Start/resume playback
func pause()   // Temporarily stop
func stop()    // Complete stop and reset
func rewind(seconds: TimeInterval = 5.0)  // Jump back
```

**Navigation Controls**
```swift
func skipToNextSection()     // Jump to next header/section
func skipToPreviousSection() // Jump to previous section
func canSkipCurrentSection() // Check if current section is skippable
```

**Parameter Controls**
```swift
func setPlaybackSpeed(_ speed: Float)      // 0.5x - 2.0x speed
func setVoice(_ voice: AVSpeechSynthesisVoice)  // Change voice
func setPitchMultiplier(_ pitch: Float)    // Adjust voice pitch
func setVolumeMultiplier(_ volume: Float)  // Volume control
```

### Smart Text Processing

**Utterance Parameter Optimization**
```swift
private func setupUtteranceParameters(_ utterance: AVSpeechUtterance) {
    utterance.voice = selectedVoice ?? getBestAvailableVoice()
    utterance.rate = playbackSpeed
    utterance.pitchMultiplier = pitchMultiplier
    utterance.volume = volumeMultiplier
    utterance.preUtteranceDelay = 0.1   // Natural pacing
    utterance.postUtteranceDelay = 0.1  // Breathing room
}
```

## Integration Patterns

### SwiftUI Integration

**Reactive UI Updates**
```swift
struct ReaderView: View {
    @StateObject private var ttsManager = TTSManager()
    
    var body: some View {
        VStack {
            // UI automatically updates when @Published properties change
            Text(playbackStateText)
            Button(playPauseIcon) { togglePlayback() }
        }
    }
}
```

### Core Data Integration

**Progress Persistence**
```swift
private func saveProgress() {
    progress.currentPosition = Int32(currentPosition)
    progress.lastReadDate = Date()
    try progress.managedObjectContext?.save()
}
```

**Section Navigation**
```swift
private func updateCurrentSectionIndex() {
    for (index, section) in contentSections.enumerated() {
        if currentPosition >= section.startIndex && currentPosition < section.endIndex {
            currentSectionIndex = index
            break
        }
    }
}
```

## Performance Optimizations

### Memory Management

**Resource Cleanup**
```swift
func stop() {
    synthesizer.stopSpeaking(at: .immediate)
    currentUtterance = nil  // Release utterance
    playbackState = .idle
}
```

**Lazy Loading**
- Voices loaded once during initialization
- Content sections loaded per file
- Progress saved periodically, not continuously

### Audio Efficiency

**Background Processing**
- Text processing on background queue
- UI updates dispatched to main queue
- Audio session managed automatically

**Smart Buffering**
- Process text from current position forward
- Avoid loading entire document into memory
- Efficient character range tracking

## Usage Examples

### Basic Playback
```swift
// Initialize TTS Manager
@StateObject private var ttsManager = TTSManager()

// Load content
ttsManager.loadMarkdownFile(markdownFile, context: viewContext)

// Control playback
ttsManager.play()
ttsManager.pause()
ttsManager.setPlaybackSpeed(0.7)
```

### Voice Customization
```swift
// Get available voices
let voices = ttsManager.getAvailableVoices()

// Set premium voice
if let avaVoice = voices.first(where: { $0.name == "Ava" }) {
    ttsManager.setVoice(avaVoice)
}

// Adjust parameters
ttsManager.setPitchMultiplier(0.9)  // Slightly lower pitch
ttsManager.setVolumeMultiplier(0.8) // 80% volume
```

### Section Navigation
```swift
// Check current section
if let sectionInfo = ttsManager.getCurrentSectionInfo() {
    print("Current: \(sectionInfo.type) (Level \(sectionInfo.level))")
    
    // Skip technical sections while driving
    if sectionInfo.isSkippable {
        ttsManager.skipToNextSection()
    }
}
```

## Key Benefits

### For Users
- **Natural Speech**: Premium voices sound human-like
- **Driving Safety**: Hands-free operation with CarPlay
- **Learning Continuity**: Resume exactly where you left off
- **Content Awareness**: Skip technical sections when needed

### For Developers  
- **SwiftUI Reactive**: Automatic UI updates via @Published
- **Core Data Integration**: Seamless progress persistence
- **Clean Architecture**: Single responsibility principle
- **Extensible Design**: Easy to add new voice features

### For Maintenance
- **Clear Separation**: Audio logic isolated from UI
- **Comprehensive Testing**: Mockable delegate patterns
- **Error Handling**: Graceful degradation for missing voices
- **Performance**: Efficient memory and battery usage

## Interjection System Architecture

### Overview
The TTSManager coordinates with InterjectionManager to provide context-aware voice announcements during TTS playback, enabling features like code block language announcements in contrasting female voices.

### Section-Based Interjection Flow

**1. Section Transition Detection**
```swift
func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, 
                      willSpeakRangeOfSpeechString characterRange: NSRange, 
                      utterance: AVSpeechUtterance) {
    // Update position tracking
    currentPosition = utteranceStartPosition + characterRange.location
    updateCurrentSectionIndex()
    
    // Detect section transitions
    if currentSectionIndex != previousSectionIndex {
        handleSectionTransition(from: previousSectionIndex, to: currentSectionIndex)
    }
}
```

**2. Code Block Interjection Logic**
```swift
private func handleSectionTransition(from fromIndex: Int, to toIndex: Int) {
    if toSection.typeEnum == .codeBlock && fromSection.typeEnum != .codeBlock {
        // Entering code block - interrupt TTS for immediate interjection
        let language = extractLanguageFromSection(toSection)
        synthesizer.pauseSpeaking(at: .word)  // Clean pause at word boundary
        
        let event = InterjectionEvent.codeBlockStart(language: language, section: toSection)
        interjectionManager.handleInterjection(event, ttsManager: self) {
            // Resume TTS after interjection completes
            DispatchQueue.main.async { [weak self] in
                self?.synthesizer.continueSpeaking()
            }
        }
    }
}
```

**3. Language Extraction**
```swift
private func extractLanguageFromSection(_ section: ContentSection) -> String? {
    // Extract language from code block content like "[swift code]"
    let sectionText = getTextForSection(section)
    if let match = sectionText.range(of: #"\[(\w+) code\]"#, options: .regularExpression) {
        return String(sectionText[match])
    }
    return nil
}
```

### Intelligent Text Chunking

**Section-Boundary Aware Chunking**
```swift
private func getTextFromCurrentPosition() -> String {
    // Use section-boundary aware chunking instead of fixed-size chunks
    let maxChunkSize = 50000
    let endPos = findNextInterjectionBoundary(from: startPos, maxSize: maxChunkSize)
    return String(plainText[startIndex..<endIndex])
}

private func findNextInterjectionBoundary(from startPos: Int, maxSize: Int) -> Int {
    // Priority 1: Stop before code blocks for interjection insertion
    if let codeBlockSection = sectionsInRange.first(where: { $0.typeEnum == .codeBlock }) {
        return Int(codeBlockSection.startIndex)
    }
    // Priority 2-4: Headers, paragraphs, fallback to maxSize
}
```

### InterjectionManager Integration

**Shared Synthesizer Architecture**
- TTSManager provides synthesizer access via `getSynthesizer()`
- InterjectionManager uses shared synthesizer to avoid conflicts
- Coordinated pause/resume prevents audio artifacts

**Event-Driven Communication**
```swift
enum InterjectionEvent {
    case codeBlockStart(language: String?, section: ContentSection)
    case codeBlockEnd(section: ContentSection)
    
    // Future extensions for Claude AI integration
    case claudeInsight(text: String, context: String)
    case userQuestion(query: String)
}
```

## Current Implementation Status

### ✅ Working Components
- Section transition detection via `willSpeakRangeOfSpeechString`
- Code block language extraction from parsed content
- TTS pause/resume coordination
- Female voice selection and synthesis
- Smart boundary-based text chunking

### 🔧 Areas Needing Investigation
- **Timing Issues**: Interjections may still queue instead of interrupting
- **Voice Selection**: Female voice system may not be functioning correctly
- **Resume Logic**: TTS may not auto-resume after interjection completion
- **Multiple Events**: Duplicate interjection events may be firing

### Debugging Approach
1. **Trace Section Transitions**: Log when transitions are detected
2. **Monitor TTS State**: Track pause/resume cycle completion
3. **Verify Voice Selection**: Confirm female voice is being used
4. **Check Event Handling**: Ensure single interjection per transition

This architecture transforms complex AVFoundation speech synthesis into a simple, powerful tool for hands-free markdown consumption while maintaining clean code principles and excellent user experience.