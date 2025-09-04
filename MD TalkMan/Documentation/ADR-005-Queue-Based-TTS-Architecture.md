# ADR-005: Queue-Based TTS Architecture with Priority Interjections

**Status**: Proposed  
**Date**: 2025-01-09  
**Authors**: Claude & Developer  
**Branch**: `feature/queue-based-tts-architecture`

## Summary

Transform TTSManager from single-utterance processing to sophisticated multi-utterance queue management, enabling seamless playback, priority interjections, and Claude AI integration.

## Context

### Current Architecture Limitations
The existing TTSManager implements single-utterance processing with several issues:

1. **Playback Gaps**: Pauses between content chunks due to single-utterance approach
2. **Manual Restarts**: Voice/speed changes require stopping and restarting playback  
3. **Limited Interjection Control**: Code block announcements use pause/resume patterns
4. **No Look-Ahead**: Cannot pre-generate content for smooth transitions
5. **Claude AI Constraints**: Difficult to integrate priority AI responses

### Research Findings
- **iOS Speech Synthesis Limitation**: Only one `AVSpeechSynthesizer` can be active system-wide
- **AVAudioApplication vs AVAudioSession**: AVAudioApplication doesn't solve multiple speech synthesis
- **Native Queue Support**: `AVSpeechSynthesizer` supports multiple queued utterances natively
- **Current Architecture Strength**: `.spokenAudio` mode with section-boundary chunking is optimal

## Decision

Implement a **Double-Ended Queue Architecture** that leverages `AVSpeechSynthesizer`'s native queueing while adding intelligent priority management for interjections and Claude responses.

### Core Design Principles

1. **Multi-Utterance Pre-Generation**: Queue 2-3 utterances ahead for seamless playback
2. **Priority-Based Front Insertion**: Interrupt for urgent content (Claude responses)  
3. **Lazy Content Loading**: Generate utterances on-demand at queue tail
4. **Zero-Restart Settings**: Apply changes to queued utterances without stopping
5. **Backward Compatibility**: Preserve existing position tracking and section logic

## Technical Architecture

### 1. Queue Data Structures

```swift
private struct QueuedUtterance {
    let utterance: AVSpeechUtterance
    let startPosition: Int
    let endPosition: Int  
    let sectionIndex: Int
    let isInterjection: Bool
    let priority: QueuePriority
    let metadata: UtteranceMetadata?
}

enum QueuePriority: Int {
    case background = 0    // Pre-loaded content
    case normal = 1        // Standard reading
    case interjection = 2  // Code blocks, transitions
    case urgent = 3        // Claude responses, user questions
    case critical = 4      // Emergency stops, errors
}
```

### 2. Double-Ended Queue Management

```swift
// Queue Architecture
private var utteranceQueue: Deque<QueuedUtterance> = []
private var queuedUtterancesInSynthesizer: Set<ObjectIdentifier> = []

// Lazy loading at tail
private func preloadUpcomingContent()

// Priority insertion at head  
private func pauseAndInsertUrgent(_ queuedUtterance: QueuedUtterance)
```

### 3. Key Implementation Patterns

#### Seamless Playback
- **Pre-queue Utterances**: 2-3 utterances queued ahead for gap-free playback
- **Automatic Continuation**: `didFinish` delegate triggers next utterance queuing
- **Section Boundaries**: Preserve existing `findNextInterjectionBoundary()` logic

#### Priority Interjections  
- **Immediate Insertion**: `pauseAndInsertUrgent()` for Claude responses
- **Natural Boundaries**: Code blocks inserted at section transitions
- **Queue Rebuilding**: Smart reconstruction of synthesizer queue after interruptions

#### Dynamic Settings
- **No-Restart Updates**: Voice/speed changes apply to queued utterances
- **Batch Processing**: Update multiple utterances efficiently
- **Smooth Transitions**: Changes take effect at next utterance boundary

### 4. Memory Management

- **Queue Limits**: Max 10 total utterances, max 3 pre-loaded (~150KB total)
- **Automatic Cleanup**: Remove completed utterances and metadata
- **Background Generation**: Utterance creation on utility queue
- **Lazy Loading**: Generate content on-demand, not all at once

## Implementation Plan

### Phase 1: Core Queue Infrastructure
1. Add queue data structures to TTSManager
2. Implement basic multi-utterance queuing
3. Test seamless playbook with existing content

### Phase 2: Priority Management  
1. Add interjection priority system
2. Implement `pauseAndInsertUrgent()` for interruptions
3. Test code block announcements with new queue

### Phase 3: Dynamic Settings
1. Enable voice/speed changes without restart
2. Implement batch utterance updates
3. Test settings changes during playback

### Phase 4: Claude AI Integration
1. Add Claude response handling with priority
2. Implement insertion strategies (immediate, boundary, section)
3. Test full conversation flow with TTS

## Benefits

### User Experience
- **Gap-Free Playback**: Seamless content flow without pauses
- **Instant Settings**: Voice/speed changes without interruption  
- **Smart Interjections**: Code blocks announced at natural boundaries
- **Claude Integration**: AI responses inserted with appropriate priority

### Technical Advantages
- **Leverages iOS Capabilities**: Uses native `AVSpeechSynthesizer` queueing
- **Memory Efficient**: Limited pre-loading with lazy generation
- **Backward Compatible**: Preserves position tracking and section logic
- **Extensible**: Ready for future AI features and conversation patterns

### Development Benefits
- **Evolutionary Upgrade**: Build on existing architecture strengths
- **Testable Components**: Queue operations can be unit tested independently
- **Maintainable Code**: Clear separation between content generation and queue management

## Risks and Mitigations

### Memory Usage
- **Risk**: Large content could consume excessive memory
- **Mitigation**: Strict queue limits (10 utterances max) and automatic cleanup

### Queue Complexity  
- **Risk**: Complex priority logic could introduce bugs
- **Mitigation**: Comprehensive unit tests and gradual rollout

### Position Tracking
- **Risk**: Character positions could become inconsistent across utterances
- **Mitigation**: Preserve existing position tracking logic and add validation

## Success Criteria

1. **Seamless Playback**: No audible gaps between content sections
2. **Instant Settings**: Voice/speed changes apply without stopping playback
3. **Smart Interjections**: Code blocks announced at appropriate times
4. **Memory Efficiency**: Queue memory usage stays under 200KB
5. **Backward Compatibility**: All existing TTS features continue working
6. **Claude Ready**: Priority insertion works for AI responses

## Alternative Approaches Considered

### Multiple AVSpeechSynthesizer Instances
- **Rejected**: iOS limitation - only one active synthesizer system-wide

### AVAudioApplication Migration  
- **Rejected**: Doesn't solve speech synthesis limitations, adds complexity

### Complete Rewrite
- **Rejected**: Current section-boundary logic is sophisticated and working well

## Related Documents

- [TTSManager.swift](../Controllers/TTSManager.swift) - Current implementation
- [InterjectionManager.swift](../Controllers/InterjectionManager.swift) - Existing interjection system
- [ADR-004: Interjection Event System](ADR-004-Interjection-Event-System.md) - Current interjection architecture
- [Phase 4 Implementation Plan](../../Phase-4-Implementation-Plan.md) - Claude AI integration roadmap

## Implementation Notes

### Development Branch
- **Branch**: `feature/queue-based-tts-architecture`  
- **Base**: `main` (current interjection system)
- **Target**: Evolutionary upgrade, not complete rewrite

### Testing Strategy
1. **Unit Tests**: Queue operations, priority management, position tracking
2. **Integration Tests**: Full TTS flow with interjections
3. **Performance Tests**: Memory usage and queue efficiency  
4. **User Testing**: Seamless playback and settings changes

### Rollback Plan
- Maintain feature flag for enabling queue-based vs single-utterance mode
- Keep existing single-utterance code as fallback
- Gradual rollout with A/B testing capability