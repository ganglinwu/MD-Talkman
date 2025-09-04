# InterjectionManager Architecture Guide

## Overview

The InterjectionManager provides context-aware voice announcements during TTS playback, designed to enhance the listening experience with contrasting voice interjections for code blocks and other content transitions. It coordinates closely with TTSManager to deliver seamless audio interruptions without disrupting the main speech flow.

## Architecture Design

### Core Responsibilities

- **Contextual Voice Announcements**: Provide language-specific code block notifications
- **Voice Contrast Management**: Use different voices (typically female) from main TTS voice
- **Audio Coordination**: Manage TTS pause/resume cycles for clean interjections
- **Event Processing**: Handle various interjection event types
- **Tone Integration**: Coordinate audio tones with voice announcements
- **Settings Integration**: Respect user preferences for interjection styles

### Design Patterns Used

#### 1. **Event-Driven Architecture**
```swift
enum InterjectionEvent {
    case codeBlockStart(language: String?, section: ContentSection)
    case codeBlockEnd(section: ContentSection)
    
    // Phase 4 Extensions for Claude AI integration
    case claudeInsight(text: String, context: String)
    case userQuestion(query: String)
    case contextualHelp(topic: String)
}
```

#### 2. **Strategy Pattern for Notification Styles**
```swift
enum CodeBlockNotificationStyle: String, CaseIterable {
    case smartDetection = "smart_detection"  // Context-aware audio
    case voiceOnly = "voice_only"           // Voice announcements only
    case tonesOnly = "tones_only"           // Audio tones only
    case both = "both"                      // Voice + tones combined
}
```

#### 3. **Delegate Pattern for Speech Synthesis**
```swift
private class InterjectionSpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    private let completion: () -> Void
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        completion()
    }
}
```

## Key Components

### Event Handling System

**Primary Event Handler**
```swift
func handleInterjection(_ event: InterjectionEvent, 
                      ttsManager: TTSManager,
                      completion: @escaping () -> Void) {
    // Ensure main thread execution
    guard Thread.isMainThread else {
        DispatchQueue.main.async { [weak self] in
            self?.handleInterjection(event, ttsManager: ttsManager, completion: completion)
        }
        return
    }
    
    // Process specific event types
    switch event {
    case .codeBlockStart(let language, let section):
        executeCodeBlockStart(language: language, section: section, ttsManager: ttsManager, completion: completion)
    case .codeBlockEnd(let section):
        executeCodeBlockEnd(section: section, ttsManager: ttsManager, completion: completion)
    }
}
```

### Voice Selection System

**Female Voice Detection**
```swift
private func getInterjectionVoice() -> AVSpeechSynthesisVoice? {
    // Try user-selected voice first
    if let selectedVoice = settingsManager.getSelectedInterjectionVoice() {
        return selectedVoice
    }
    
    // Fallback to default female voice
    return settingsManager.getDefaultInterjectionVoice()
}
```

**Siri Voice Compatibility Check**
```swift
private func findNonSiriVoice() -> AVSpeechSynthesisVoice? {
    let femaleVoices = settingsManager.getAvailableFemaleVoices()
    
    // Find first non-Siri voice (Siri voices incompatible with AVSpeechSynthesizer)
    for voice in femaleVoices {
        if !voice.identifier.contains("siri") && !voice.identifier.contains("ttsbundle") {
            return voice
        }
    }
    return nil
}
```

### Audio Coordination

**Shared Synthesizer Integration**
```swift
private func performInterjectionSpeech(_ text: String, 
                                     voice: AVSpeechSynthesisVoice?, 
                                     synthesizer: AVSpeechSynthesizer, 
                                     completion: @escaping () -> Void) {
    assert(Thread.isMainThread, "Interjection speech must run on main thread")
    
    // Create optimized interjection utterance
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = voice
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.0
    utterance.volume = 0.85
    utterance.preUtteranceDelay = 0.1
    utterance.postUtteranceDelay = 0.2
    
    // Strong delegate retention for speech completion
    let delegate = InterjectionSpeechDelegate(completion: completion)
    synthesizer.delegate = delegate
    objc_setAssociatedObject(synthesizer, "interjectionDelegate", delegate, .OBJC_ASSOCIATION_RETAIN)
    
    synthesizer.speak(utterance)
}
```

## Core Functionality

### Code Block Interjections

**Start Interjection Flow**
```swift
private func executeCodeBlockStart(language: String?, 
                                 section: ContentSection, 
                                 ttsManager: TTSManager, 
                                 completion: @escaping () -> Void) {
    let notificationStyle = settingsManager.codeBlockNotificationStyle
    
    switch notificationStyle {
    case .smartDetection:
        // Language notification only if enabled
        if settingsManager.isCodeBlockLanguageNotificationEnabled,
           let language = language {
            provideLanguageNotification(language, ttsManager: ttsManager, completion: completion)
        }
        
    case .tonesOnly:
        // Audio tone with extended pause
        playCodeBlockToneWithPause(.codeBlockStart, completion: completion)
        
    case .both:
        // Tone followed by voice announcement
        playCodeBlockToneWithPause(.codeBlockStart) {
            self.provideLanguageNotification(language, ttsManager: ttsManager, completion: completion)
        }
        
    case .voiceOnly:
        // Voice announcement only
        provideLanguageNotification(language, ttsManager: ttsManager, completion: completion)
    }
}
```

**Language Notification**
```swift
private func provideLanguageNotification(_ language: String, 
                                       ttsManager: TTSManager, 
                                       completion: @escaping () -> Void) {
    guard let sharedSynthesizer = ttsManager.getSynthesizer() else {
        completion()
        return
    }
    
    let interjectionVoice = getInterjectionVoice()
    
    // Check for Siri voice compatibility
    if let voice = interjectionVoice, voice.identifier.contains("siri") {
        let fallbackVoice = findNonSiriVoice() ?? AVSpeechSynthesisVoice(language: "en-US")
        performInterjectionSpeech("\(language) code", voice: fallbackVoice, 
                                synthesizer: sharedSynthesizer, completion: completion)
    } else {
        let voiceToUse = interjectionVoice ?? AVSpeechSynthesisVoice(language: "en-US")
        performInterjectionSpeech("\(language) code", voice: voiceToUse, 
                                synthesizer: sharedSynthesizer, completion: completion)
    }
}
```

### Audio Tone Integration

**Code Block Tone System**
```swift
private func playCodeBlockToneWithPause(_ feedbackType: AudioFeedbackType, 
                                       completion: @escaping () -> Void) {
    // Play tone using AudioFeedbackManager
    audioFeedback.playFeedback(for: feedbackType)
    
    // Wait for tone completion
    let pauseDuration: TimeInterval = 0.9
    DispatchQueue.main.asyncAfter(deadline: .now() + pauseDuration) {
        completion()
    }
}

private func playEndOfInterjectionTone(completion: @escaping () -> Void) {
    audioFeedback.playFeedback(for: .buttonTap)  // Subtle completion signal
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        completion()
    }
}
```

## Integration Patterns

### TTSManager Coordination

**Shared Synthesizer Access**
- Uses TTSManager's synthesizer via `getSynthesizer()` method
- Avoids multiple synthesizer instance conflicts
- Maintains consistent audio session management

**Event-Driven Communication**
```swift
// TTSManager triggers interjections
interjectionManager.handleInterjection(event, ttsManager: self) {
    // Completion handler for TTS resume coordination
}
```

### SettingsManager Integration

**User Preference Respect**
```swift
// Notification style preference
let notificationStyle = settingsManager.codeBlockNotificationStyle

// Language notification toggle
let languageEnabled = settingsManager.isCodeBlockLanguageNotificationEnabled

// Voice selection
let selectedVoice = settingsManager.getSelectedInterjectionVoice()
```

### AudioFeedbackManager Coordination

**Tone Integration**
- Uses AudioFeedbackManager for consistent tone playback
- Coordinates tone timing with voice announcements
- Provides audio feedback for different interjection styles

## Testing Interface

### Voice Testing Support

**Test Method for UI**
```swift
func testLanguageNotification(_ language: String, 
                            ttsManager: TTSManager, 
                            completion: @escaping () -> Void) {
    assert(Thread.isMainThread, "Test must run on main thread")
    
    // Use production language notification system for testing
    provideLanguageNotification(language, ttsManager: ttsManager, completion: completion)
}
```

## Current Implementation Status

### ✅ Working Components
- Event-driven interjection handling
- Female voice selection and fallback logic
- Siri voice compatibility detection
- Audio tone coordination
- Settings integration for notification styles
- Shared synthesizer integration
- Thread safety with main thread enforcement

### 🔧 Areas Needing Investigation
- **Timing Coordination**: Interjections may not interrupt TTS correctly
- **Voice Synthesis**: Female voice may not be speaking as expected
- **Delegate Lifecycle**: Speech delegate retention may have issues
- **Completion Handling**: Completion callbacks may not be firing correctly

### Debugging Approach
1. **Voice Selection Verification**: Ensure correct female voice is selected
2. **Speech Synthesis Monitoring**: Track delegate callback execution
3. **Timing Analysis**: Verify interjection timing relative to main TTS
4. **Memory Management**: Check delegate retention and cleanup

## Phase 4 Extensions

### Claude AI Integration Ready
The architecture includes placeholder events for future Claude AI features:

```swift
// Future Claude integration events
case claudeInsight(text: String, context: String)     // AI explanations
case userQuestion(query: String)                      // Voice queries  
case contextualHelp(topic: String)                    // Smart assistance
```

### Extensibility Features
- Event-driven design supports new interjection types
- Voice selection system can accommodate specialized voices
- Audio coordination framework supports complex audio sequences
- Settings integration enables per-feature user preferences

This architecture provides a robust foundation for context-aware voice enhancements while maintaining clean separation of concerns and excellent extensibility for future AI-powered features.