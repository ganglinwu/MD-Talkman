# MD TalkMan - SwiftUI Markdown Audio Reader

A SwiftUI app for hands-free markdown reading with Claude.ai integration, designed for driving and accessibility.

## Core Features

1. **Markdown Reader**: Display and navigate markdown files with text-to-speech playback
2. **Voice-to-Claude**: Speech-to-text → Claude.ai queries → spoken responses  
3. **File Management**: Browse/sync markdown files from GitHub repositories + local storage
4. **Hands-Free Operation**: Optimized for driving with CarPlay integration

## Audio-First Design

### Text-to-Speech Implementation
- Enhanced voice selection with premium iOS voices (Ava, Samantha, Alex)
- Parse markdown → extract plain text (strip symbols, format code blocks as "code section")
- Sentence/paragraph-based chunking for better scrubbing control
- Bookmark system: save position by paragraph/section + timestamp
- Premium audio parameters: pitch, volume, pre/post utterance delays
- Driving-optimized audio session management for CarPlay

### Reading Controls
- Play/pause functionality with single-tap stop button
- Scrub backwards 5 seconds  
- Skip sections (especially technical content with code blocks)
- Section navigation using markdown headers
- Speed Control: 0.5x to 2.0x playback speed (defaults to 1.0x natural speech)
- Progress tracking with resume capability
- Haptic feedback for accessibility and hands-free operation

### Hands-Free Controls
- Large touch targets for basic controls
- Haptic and audio feedback for TTS state changes
- Voice commands via iOS Shortcuts integration
- CarPlay integration for steering wheel controls
- Background audio session for continuous playback

## Data Architecture

### Core Data Models

**MarkdownFile**
```swift
- id: UUID
- title: String
- filePath: String (local path)
- gitFilePath: String (relative path in repo)
- repositoryId: UUID (foreign key to GitRepository)
- lastCommitHash: String
- lastModified: Date
- fileSize: Int
- syncStatus: enum (local, synced, needsSync, conflicted)
- hasLocalChanges: Bool
```

**ReadingProgress**
```swift
- fileId: UUID (foreign key)
- currentPosition: Int (character/paragraph index)
- lastReadDate: Date
- totalDuration: TimeInterval?
- bookmarks: [Bookmark]
- isCompleted: Bool
```

**ParsedContent**
```swift
- fileId: UUID
- plainText: String (markdown → clean text)
- sections: [ContentSection] (headers, paragraphs)
- lastParsed: Date
```

**GitRepository**
```swift
- id: UUID
- name: String
- remoteURL: String (GitHub repo URL)
- localPath: String
- defaultBranch: String
- lastSyncDate: Date
- accessToken: String (encrypted)
- syncEnabled: Bool
```

**ContentSection**
```swift
- startIndex: Int
- endIndex: Int  
- type: enum (header, paragraph, codeBlock, list)
- level: Int? (for headers)
- isSkippable: Bool (technical content detection)
```

### Storage Strategy

**Local Storage (Core Data)**
- Primary storage for all metadata and reading progress
- Cached parsed content for fast TTS startup
- Works offline, persists across app launches

**File System**
- Local Git repositories in Documents/Repositories/
- Raw markdown files within each repo structure
- Parsed content cache in Library/Caches/ParsedContent/
- Git metadata in .git directories

**GitHub Integration**
- GitHub API for repository access and webhooks
- OAuth authentication for user repositories
- Git operations using SwiftGit2 or similar
- Support for private repositories

### Git-Based Sync Architecture

**Repository Management**
- Clone user's GitHub repositories locally
- Support multiple repositories
- Automatic branch creation for Claude edits
- Repository structure: `repo-name/articles/`, `repo-name/notes/`, etc.

**Sync Strategy**
```swift
// Standard Git workflow
func syncRepository() {
    git.fetch()  // Get latest changes
    if hasLocalChanges {
        git.commit("Claude insights: \(timestamp)")
        git.push()  // Upload local changes
    }
    git.pull()  // Merge remote changes
}
```

**Conflict Resolution**
- Git's built-in merge strategies
- Claude edits on separate branches
- User reviews merge requests
- Automatic merging for non-conflicting changes

**Version Control Benefits**
- Full edit history with commit messages
- Rollback capability for any change
- Branch-based Claude experiments
- Collaboration through GitHub features

## Content Architecture

### Embedded Content System
The app now uses an embedded content architecture that eliminates iOS sandbox limitations and provides reliable content delivery.

**Key Features:**
- **15 Comprehensive Articles**: High-quality Swift learning content embedded directly in the app
- **iOS Sandbox Compatible**: No external file dependencies or permissions required
- **Reliable Content Delivery**: Always available, no network or filesystem issues
- **TTS-Optimized**: Content specifically formatted for clear audio narration

**Content Topics Covered:**
- SwiftUI Fundamentals & Navigation Patterns
- Memory Management & ARC
- iOS App Architecture (MVC, MVVM, Clean Architecture)
- Networking & API Integration with async/await
- Core Data & Performance Optimization  
- Advanced Swift Features (Generics, Protocols, Property Wrappers)
- UIKit Integration with SwiftUI
- Testing Best Practices & Debugging Techniques
- Concurrency & Error Handling
- Design Patterns for iOS Development

**Technical Implementation:**
```swift
// Content mapping system
private static func getEmbeddedContent(for filePath: String) -> String {
    if filePath.contains("swiftui-fundamentals") {
        return swiftUIFundamentalsContent
    } else if filePath.contains("memory-management") {
        return memoryManagementContent
    }
    // ... additional mappings for all 15 topics
}
```

**Benefits:**
- **Consistent Experience**: Content always available regardless of network/storage state
- **Educational Quality**: Each article 500-2000+ words with realistic code examples
- **Audio-First Design**: Content structured for optimal TTS narration flow
- **No Dependencies**: Eliminates external file requirements and permissions

## Claude.ai Integration

### Voice Interaction Flow
1. User listening to markdown file via TTS
2. Holds button or says "Hey Claude" 
3. Speech-to-text captures question
4. Question sent to Claude.ai API with file context
5. Claude response read aloud via TTS
6. Optional: Claude edits file based on conversation

### Speech Recognition (iOS Speech Framework)
```swift
import Speech

class VoiceManager: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    
    func startListening() {
        // Request microphone permission
        // Start audio recording
        // Stream audio to speech recognition
    }
    
    func stopListening() -> String {
        // Stop recording, return transcribed text
    }
}
```

### Context-Aware Conversations
- Send current markdown file content as context
- Maintain conversation history per file
- Claude can reference specific sections
- Smart context trimming for API limits

### Voice Commands
```swift
// Recognized voice patterns
"Claude, what does this section mean?"
"Summarize this article"
"Add your thoughts about X"
"What questions should I ask about this?"
```

## Text-to-Speech Implementation

### Enhanced TTS Manager (AVSpeechSynthesizer)
```swift
class TTSManager: ObservableObject {
    @Published var playbackState: TTSPlaybackState = .idle
    @Published var selectedVoice: AVSpeechSynthesisVoice?
    @Published var pitchMultiplier: Float = 1.0
    @Published var volumeMultiplier: Float = 1.0
    
    private let synthesizer = AVSpeechSynthesizer()
    private var enhancedVoices: [AVSpeechSynthesisVoice] = []
    
    private func getBestAvailableVoice() -> AVSpeechSynthesisVoice? {
        let preferredVoices = [
            "com.apple.voice.enhanced.en-US.Ava",      // Neural voice
            "com.apple.voice.enhanced.en-US.Samantha", // Enhanced voice
            "com.apple.voice.enhanced.en-US.Alex"      // Classic enhanced
        ]
        // Premium voice selection logic...
    }
    
    private func setupUtteranceParameters(_ utterance: AVSpeechUtterance) {
        utterance.voice = selectedVoice ?? getBestAvailableVoice()
        utterance.rate = playbackSpeed
        utterance.pitchMultiplier = pitchMultiplier
        utterance.volume = volumeMultiplier
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1
    }
}
```

### Markdown Processing for TTS
- Strip markdown syntax (**, __, [], etc.)
- Convert code blocks to "code section begins... code section ends"
- Handle lists: "bullet point 1, bullet point 2"
- Section detection for smart skipping

## SwiftUI View Hierarchy

### Main App Structure
```
ContentView
├── RepositoryListView (GitHub repos)
├── FileListView (markdown files in repo)
├── ReaderView (main reading interface)
│   ├── TTSControlsView (play/pause/scrub)
│   ├── VoiceInputView (Claude interaction)
│   └── MarkdownDisplayView (optional visual)
└── SettingsView (repos, voice, TTS settings)
```

### CarPlay Integration
- Simple list-based navigation
- Large buttons for TTS controls
- Voice-first interaction
- Minimal visual elements

## Implementation Plan

### Phase 1: Core Audio & Content System ✅ COMPLETED
- [x] Set up SwiftUI project with Core Data
- [x] Implement markdown parsing with TTS conversion
- [x] Build enhanced reader UI with TTS controls and haptic feedback
- [x] Create comprehensive test suite (21 unit tests + integration + UI tests)
- [x] Build embedded content system with 15 Swift learning articles
- [x] Resolve iOS sandbox limitations with embedded architecture
- [x] Create project structure and comprehensive documentation

### Phase 2: GitHub Integration  
- [ ] Add GitHub OAuth authentication
- [ ] Implement repository cloning and sync
- [ ] Build Git operations (commit, push, pull)
- [ ] Create repository and file browser UI

### Phase 3: Claude Integration
- [ ] Integrate Speech framework for voice input
- [ ] Connect Claude API with file context
- [ ] Implement conversation history per file
- [ ] Add TTS for Claude responses

### Phase 4: Hands-Free Optimization
- [ ] Build CarPlay integration
- [ ] Add voice commands and shortcuts
- [ ] Implement driving mode UI
- [ ] Add advanced audio controls (bookmarks, section skipping)

### Phase 5: Polish & Advanced Features
- [ ] Conflict resolution UI for Git merges
- [ ] Smart content skipping (technical sections)
- [ ] Background sync and notifications
- [ ] Performance optimization

## Current Implementation Status

### ✅ Completed Components

**Core Data Foundation**
- Complete 6-entity data model with perfect relationships
- Type-safe enums with UI-friendly extensions (SyncStatus, ContentSectionType)  
- Production-ready PersistenceController with preview support
- Embedded Content Integration with 15 comprehensive Swift learning articles
- Developer mode for data management and testing

**Markdown Processing Pipeline**
- MarkdownParser: Converts markdown to TTS-friendly text
- Handles all markdown elements: headers, code blocks, lists, quotes, formatting
- Removes syntax and creates structured ContentSection objects
- Smart skippable content detection (code blocks, technical content)

**Enhanced Text-to-Speech System**
- TTSManager: Full playback control with premium voice selection
- Variable speed (0.5x-2.0x, defaults to 1.0x natural speech), rewind, section navigation
- Single-tap stop button with proper user stop tracking
- Premium voice quality: Enhanced/Neural voices (Ava, Samantha, Alex)
- Advanced audio parameters: pitch, volume, utterance delays
- Audio session optimized for driving (.spokenAudio, CarPlay support)
- Automatic progress tracking and bookmark support
- Real-time position tracking with Core Data persistence
- Haptic feedback for accessibility and hands-free operation

**SwiftUI Interface**
- ContentView: Repository browser with Core Data integration
- RepositoryDetailView: File listing with sync status indicators
- ReaderView: Complete TTS interface with enhanced playback controls
- VoiceSettingsView: Premium voice selection and audio customization
- SettingsView: Developer mode toggle and data management
- Clean navigation hierarchy with proper state management

**Comprehensive Testing**
- 21 unit tests for markdown parsing accuracy
- 15 TTS manager tests with mock objects
- 8 integration tests for complete data flow
- 10 UI tests for user interaction validation
- Performance testing with large documents
- Edge case and error handling coverage

### 🎵 TTS Conversion Examples
```
Markdown: ## Getting Started → TTS: "Heading level 2: Getting Started."
Markdown: **bold text** → TTS: "bold text"  
Markdown: ```swift\ncode\n``` → TTS: "Code block in swift begins. [Code content omitted] Code block ends."
Markdown: > Quote → TTS: "Quote: Quote. End quote."
Markdown: - List item → TTS: "• List item."
```

### 🏗️ Architecture Highlights
- Enterprise-grade Core Data relationships with proper delete rules
- Singleton pattern with dependency injection for testing
- Observable TTS manager with @Published state for real-time UI updates
- Type-safe enum extensions for database string fields
- Premium voice architecture with automatic fallback selection
- Developer mode with granular data management controls
- Comprehensive error handling and edge case management
- Audio session management optimized for automotive use

## Required Dependencies
- **SwiftGit2**: Git operations
- **GitHub API SDK**: Repository management  
- **swift-markdown**: Markdown parsing
- **Speech Framework**: Speech-to-text
- **AVFoundation**: TTS and audio session
- **CarPlay Framework**: Vehicle integration
- **Claude API**: AI conversation integration

### Safety Features
- Minimal visual interface when driving mode detected
- Large buttons, high contrast design
- Integration with iOS Focus modes
- Background audio session management