# ADR-004: Interjection Event System for Natural TTS Flow Management

**Date**: 2025-08-28  
**Status**: ✅ **ACCEPTED**  
**Context**: Text-to-speech audio enhancement and Claude AI integration preparation

---

## Context

The MD TalkMan app needed a sophisticated way to inject contextual audio announcements (like code block language identification) during TTS playback without disrupting the natural speech flow. Previous implementations caused jarring interruptions, audio artifacts, and poor user experience. Additionally, the architecture needed to be extensible for Phase 4 Claude AI integration where AI insights, user questions, and contextual help would need similar injection capabilities.

The core challenge was **when** to inject audio: immediate interruption caused audio artifacts, while waiting too long made announcements feel disconnected from their context.

## Decision

**We will implement a deferred interjection event system that waits for natural TTS pauses (utterance completion) to execute audio announcements.**

The system uses an event-driven architecture with `InterjectionEvent` enum cases and an `InterjectionManager` that coordinates with the existing `TTSManager` through delegate callbacks.

## Rationale

### Why This Decision Makes Sense
- **Seamless User Experience**: No jarring interruptions or audio artifacts during natural speech flow
- **Technical Correctness**: Uses `AVSpeechSynthesizerDelegate.didFinish` for perfect timing coordination
- **Extensible Architecture**: Event-driven design easily accommodates future Claude AI features
- **Voice Differentiation**: Uses female voice contrast for announcements vs. main content narration
- **Memory Safety**: Temporary synthesizer instances with proper delegate lifecycle management

### Trade-offs Considered

#### Option A: Immediate TTS Interruption ❌
- **Pros**: 
  - Immediate feedback tied directly to content
  - Simple implementation with `synthesizer.stopSpeaking()`
- **Cons**: 
  - Causes audio artifacts and jarring user experience
  - Risks AVAudioSession conflicts with multiple synthesizers
  - Poor accessibility for hands-free driving scenarios

#### Option B: Deferred Interjection Events ✅ **CHOSEN**
- **Pros**:
  - Natural, seamless audio flow without artifacts
  - Professional UX with clear audio boundaries
  - Event-driven architecture extensible for Claude AI
  - Safe memory management with temporary synthesizer instances
- **Cons**:
  - Slight delay between content and announcement
  - More complex implementation with state management

#### Option C: Pre-processing Announcements ❌  
- **Pros**: 
  - Perfect timing by embedding announcements in TTS text
  - No complex state management needed
- **Cons**: 
  - No voice differentiation possible (same voice for everything)
  - Less flexible for dynamic content like Claude insights
  - Harder to make configurable (user preferences for announcement style)

## Consequences

### Positive
- **Professional Audio Experience**: Smooth, artifact-free transitions between content and announcements
- **Accessibility Improvement**: Clear audio boundaries help users in hands-free driving scenarios
- **Future-Ready Architecture**: Phase 4 Claude AI integration can reuse the same event system
- **Voice Contrast**: Female announcements provide clear distinction from main male narration
- **Configurable UX**: Users can choose tones-only, voice-only, or combined approaches

### Negative / Risk Mitigation
- **Timing Disconnect**: Brief delay between content and announcement 
  - *Mitigation*: End-of-interjection tones provide clear audio boundaries
- **Complexity**: More complex state management with deferred events
  - *Mitigation*: Comprehensive unit tests and clear event lifecycle documentation
- **Memory Management**: Multiple synthesizer instances require careful cleanup
  - *Mitigation*: Associated objects pattern with automatic delegate lifecycle

## Implementation Notes

```swift
// Core event system
enum InterjectionEvent {
    case codeBlockStart(language: String?, section: ContentSection)
    case codeBlockEnd(section: ContentSection)
    
    // Phase 4 extensions ready for Claude AI
    case claudeInsight(text: String, context: String)
    case userQuestion(query: String)
    case contextualHelp(topic: String)
}

// Deferred execution pattern
class TTSManager {
    private var pendingInterjection: InterjectionEvent?
    
    // In AVSpeechSynthesizerDelegate.didFinish:
    if let interjection = self.pendingInterjection {
        self.pendingInterjection = nil
        self.interjectionManager.handleInterjection(interjection, ttsManager: self) {
            // Continue TTS after interjection completes
            self.play()
        }
    }
}

// Memory-safe temporary synthesizer pattern
class InterjectionManager {
    private func provideLanguageNotification(_ language: String, completion: @escaping () -> Void) {
        let synthesizer = AVSpeechSynthesizer()
        let delegate = InterjectionSynthesizerDelegate(completion: completion)
        synthesizer.delegate = delegate
        
        // Keep delegate alive during synthesis
        objc_setAssociatedObject(synthesizer, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        
        synthesizer.speak(utterance)
    }
}
```

## Success Metrics

- **Performance**: Zero audio artifacts during interjections (measured by user testing)
- **Maintainability**: Event system successfully extended for Claude AI in Phase 4  
- **User Experience**: Smooth, professional audio transitions that enhance rather than interrupt

## Alternatives Considered

1. **AVAudioPlayer for announcements**: Rejected due to mixing complexity and voice quality inconsistency
2. **Text preprocessing with embedded announcements**: Rejected due to lack of voice differentiation
3. **Timer-based delays**: Rejected due to unreliable timing and potential race conditions

## Review Date

**Next review**: March 2026 (after Phase 4 Claude AI integration completion)  
**Trigger for early review**: User reports of timing issues or when Claude AI integration reveals architectural limitations

## Dependencies

- **Depends on**: AVSpeechSynthesizer delegate system, existing TTSManager architecture
- **Affects**: Code block announcement system, future Claude AI integration, voice settings

---

**Contributors**: Claude AI Assistant, User  
**Related ADRs**: [ADR-002 Visual Text Display](./ADR-002-Visual-Text-Display.md) (coordinate with text highlighting)  
**References**: 
- [AVSpeechSynthesizer Apple Documentation](https://developer.apple.com/documentation/avfoundation/avspeechsynthesizer)
- [iOS Audio Session Programming Guide](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/)