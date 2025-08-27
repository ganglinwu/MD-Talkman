# Phase 3: Claude Integration - Revised Implementation Plan

## Overview
Focused implementation of core Claude integration with voice input, prioritizing quality over feature breadth.

## Scope Revision

### 🎯 Phase 3 Core (Essential Features Only)
**Goal**: Minimal viable Claude integration - voice question → text response
- Basic speech-to-text input (`STTManager`)
- Claude API integration for simple Q&A
- Text-based Claude responses (no TTS yet)
- Simple conversation history per file

### 📦 Moved to Phase 4 (Advanced Features)
- TTS for Claude responses (complex audio session management)
- Advanced conversation UI with history drawer
- Voice differentiation and audio interruption/resume
- CarPlay integration and hands-free activation
- Context optimization and conversation summarization

## Implementation Strategy

### Pre-Implementation: Test Hardening
**CRITICAL**: Before touching any existing code, ensure bulletproof test coverage

#### 1. TTSManager Test Audit & Enhancement
```bash
# Current test coverage analysis needed
- Review existing TTSManagerTests.swift
- Identify gaps in edge case coverage
- Add missing integration tests
- Performance tests for large documents
- Audio session conflict scenarios
```

**New Test Requirements**:
- Audio session management under various conditions
- TTS state transitions during interruptions
- Memory management with large markdown files
- Concurrent audio operations
- Error recovery scenarios

#### 2. Integration Test Suite Expansion
- End-to-end TTS workflow tests
- GitHub sync → Parse → TTS pipeline
- Cross-component interaction validation
- Performance benchmarking

#### 3. Test-Driven Development for New Components
- Write tests BEFORE implementing STTManager
- API integration tests with mocked responses
- Conversation persistence tests

## Phase 3 Simplified Architecture

### Component 1: STTManager (Speech-to-Text)
**Purpose**: Convert voice input to text only
**Scope**: Basic speech recognition without TTS integration

```swift
class STTManager: ObservableObject {
    @Published var recognitionState: STTState
    @Published var recognizedText: String
    @Published var hasPermission: Bool
    @Published var errorMessage: String?
    
    // Simple methods - no audio session conflicts
    func startListening()
    func stopListening() 
    func cancelListening()
}
```

**Key Simplifications**:
- No audio session management (TTS unaffected)
- User manually pauses TTS before voice input
- Clear separation of concerns

### Component 2: ClaudeAPIManager
**Purpose**: Basic Claude API communication
**Scope**: Simple request/response, no streaming

```swift
class ClaudeAPIManager: ObservableObject {
    @Published var isProcessing: Bool
    @Published var lastResponse: String
    @Published var errorMessage: String?
    
    func sendQuery(question: String, fileContext: String) async -> String
}
```

### Component 3: Simple Conversation Storage
**Purpose**: Basic conversation history per file
**Scope**: Core Data persistence only

```swift
// Minimal entities with time-based sorting (Option 2: Compound Sorting)
entity ConversationMessage {
    id: UUID                    // Standard v4 UUID for uniqueness
    fileId: UUID               // Link to MarkdownFile
    userQuestion: String
    claudeResponse: String
    timestamp: Date            // For time-based sorting and display
    sortOrder: Int64          // Sequential ordering within conversation
}

// Core Data sorting extensions
extension ConversationMessage {
    static func sortDescriptors() -> [NSSortDescriptor] {
        return [
            NSSortDescriptor(keyPath: \ConversationMessage.timestamp, ascending: true),
            NSSortDescriptor(keyPath: \ConversationMessage.sortOrder, ascending: true)
        ]
    }
    
    // Convenience method for creating new messages with auto-incrementing sort order
    static func createMessage(
        in context: NSManagedObjectContext,
        fileId: UUID,
        userQuestion: String,
        claudeResponse: String
    ) -> ConversationMessage {
        let message = ConversationMessage(context: context)
        message.id = UUID() // Standard v4 UUID
        message.fileId = fileId
        message.userQuestion = userQuestion
        message.claudeResponse = claudeResponse
        message.timestamp = Date()
        
        // Auto-increment sort order for this file
        let request: NSFetchRequest<ConversationMessage> = ConversationMessage.fetchRequest()
        request.predicate = NSPredicate(format: "fileId == %@", fileId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ConversationMessage.sortOrder, ascending: false)]
        request.fetchLimit = 1
        
        let lastMessage = try? context.fetch(request).first
        message.sortOrder = (lastMessage?.sortOrder ?? 0) + 1
        
        return message
    }
}
```

### Component 4: Basic Voice Input UI
**Purpose**: Simple voice input interface in ReaderView
**Scope**: Button → voice input → text display → manual TTS resume

## Simplified User Flow

### Phase 3 User Experience
1. **User pauses TTS manually** (existing stop button)
2. **Taps "Ask Claude" button**
3. **Records voice question** (STTManager)
4. **Views transcribed text** (confirm accuracy)
5. **Sends to Claude** with current file context
6. **Reads Claude's text response** on screen
7. **Manually resumes TTS** from where they left off

### Benefits of This Approach
- **Lower risk**: No complex audio session management
- **Easier testing**: Clear component boundaries
- **Faster delivery**: Core functionality without edge cases
- **Better foundation**: Solid base for Phase 4 enhancements

## Implementation Sequence (Revised)

### Step 0: Test Hardening (MANDATORY FIRST)
**Timeline**: 1-2 days
- [ ] Audit existing test coverage
- [ ] Add missing TTSManager tests
- [ ] Create integration test baseline
- [ ] Performance benchmarking setup
- [ ] CI/CD pipeline validation

### Step 1: STTManager Foundation
**Timeline**: 2-3 days
- [ ] Create STTManager.swift (TDD approach)
- [ ] iOS Speech framework integration
- [ ] Permission management
- [ ] Unit tests (written first)
- [ ] Basic UI integration

### Step 2: Claude API Integration  
**Timeline**: 2-3 days
- [ ] ClaudeAPIManager.swift implementation
- [ ] API key management in settings
- [ ] Request/response handling
- [ ] Error scenarios and fallbacks
- [ ] Unit tests with mocked API

### Step 3: Data Model Extension
**Timeline**: 1-2 days  
- [ ] Add ConversationMessage entity
- [ ] Core Data migration
- [ ] Basic CRUD operations
- [ ] Persistence tests

### Step 4: UI Integration
**Timeline**: 2-3 days
- [ ] Voice input button in ReaderView
- [ ] Transcription display
- [ ] Claude response display
- [ ] Basic conversation history list
- [ ] UI tests

### Step 5: Integration & Polish
**Timeline**: 2-3 days
- [ ] End-to-end workflow testing
- [ ] Error handling and edge cases
- [ ] Performance optimization
- [ ] User experience polish

## Testing Strategy (Enhanced)

### Test Categories

#### 1. Pre-Implementation Tests
```swift
// Enhanced TTSManager tests
func testTTSStateTransitions()
func testAudioSessionRecovery() 
func testLargeDocumentPerformance()
func testConcurrentOperations()
func testMemoryManagement()
```

#### 2. STTManager Tests (TDD)
```swift
// Write these BEFORE implementation
func testSpeechRecognitionAccuracy()
func testPermissionHandling()
func testNetworkFailureScenarios()
func testLongSpeechInput()
func testBackgroundModeHandling()
```

#### 3. API Integration Tests
```swift
func testClaudeAPIRequest()
func testAPIErrorHandling()
func testRateLimiting()
func testNetworkTimeout()
func testInvalidAPIKey()
```

#### 4. Integration Tests
```swift
func testVoiceToClaudeWorkflow()
func testConversationPersistence()
func testFileContextInclusion()
func testConcurrentUserInteractions()
```

## Risk Assessment & Mitigation

### Technical Risks (Reduced Scope)
- **STT Accuracy**: Use iOS Speech framework with cloud backup
- **API Reliability**: Proper error handling and user feedback
- **Data Persistence**: Thorough Core Data migration testing

### Complexity Risks (Mitigated)
- **Audio Conflicts**: Eliminated by manual TTS pause/resume
- **State Management**: Simplified with clear component boundaries
- **Testing Complexity**: Reduced by eliminating audio session management

## Success Criteria (Phase 3)

### Must Have
- [ ] Voice question correctly transcribed (>90% accuracy)
- [ ] Claude response received and displayed
- [ ] Conversation history saved per file
- [ ] No regression in existing TTS functionality
- [ ] All tests passing with >80% code coverage

### Nice to Have
- [ ] Conversation export functionality
- [ ] Context-aware Claude responses
- [ ] Voice input visual feedback animations
- [ ] Claude response formatting (markdown rendering)

## Phase 4 Preview (Future)

After Phase 3 solid foundation:
- TTS for Claude responses with audio session management
- Seamless TTS interruption/resume during conversations
- Advanced conversation UI with history drawer
- Voice commands for TTS control
- CarPlay integration
- Multi-voice support

## File Structure

```
MD TalkMan/
├── Controllers/
│   ├── STTManager.swift            # Speech-to-text only
│   ├── ClaudeAPIManager.swift      # API communication
│   └── TTSManager.swift           # Unchanged in Phase 3
├── Views/
│   ├── VoiceInputView.swift        # Simple voice UI
│   └── ReaderView.swift           # Enhanced with voice button
├── Models/
│   └── CoreDataModel.xcdatamodeld  # Add ConversationMessage
└── Tests/
    ├── TTSManagerEnhancedTests.swift
    ├── STTManagerTests.swift
    └── ClaudeAPITests.swift
```

## Timeline Estimate

**Total Phase 3 Duration**: 2-3 weeks
- Test hardening: 2-3 days
- Core implementation: 10-12 days  
- Integration & polish: 3-4 days

This revised scope is much more achievable and creates a solid foundation for the advanced features in Phase 4.