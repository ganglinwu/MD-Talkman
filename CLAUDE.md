# MD TalkMan - SwiftUI Markdown Audio Reader

A SwiftUI app for hands-free markdown reading with Claude.ai integration, designed for driving and accessibility.

## Core Features

1. **Markdown Reader**: Display and navigate markdown files with text-to-speech playback
2. **Voice-to-Claude**: Speech-to-text → Claude.ai queries → spoken responses  
3. **File Management**: Browse/sync markdown files from GitHub repositories + local storage
4. **Hands-Free Operation**: Optimized for driving with CarPlay integration

## Audio-First Design

### Text-to-Speech Implementation
- Parse markdown → extract plain text (strip symbols, format code blocks as "code section")
- Sentence/paragraph-based chunking for better scrubbing control
- Bookmark system: save position by paragraph/section + timestamp

### Reading Controls
- Play/pause functionality
- Scrub backwards 5 seconds  
- Skip sections (especially technical content with code blocks)
- Section navigation using markdown headers
- Speed Control: 0.5x to 2.0x playback speed
- Progress tracking with resume capability

### Hands-Free Controls
- Large touch targets for basic controls
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

### TTS Manager (AVSpeechSynthesizer)
```swift
class TTSManager: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    
    func speakText(_ text: String, rate: Float = 0.5) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }
    
    func pause() { synthesizer.pauseSpeaking(at: .immediate) }
    func resume() { synthesizer.continueSpeaking() }
    func stop() { synthesizer.stopSpeaking(at: .immediate) }
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

### Phase 1: Core Audio & File System ✅ COMPLETED
- [x] Set up SwiftUI project with Core Data
- [x] Implement markdown parsing with TTS conversion
- [x] Build basic reader UI with TTS controls
- [x] Create comprehensive test suite (21 unit tests + integration + UI tests)
- [x] Build file management system with local storage
- [x] Create project structure and documentation

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
- Comprehensive MockData with realistic samples

**Markdown Processing Pipeline**
- MarkdownParser: Converts markdown to TTS-friendly text
- Handles all markdown elements: headers, code blocks, lists, quotes, formatting
- Removes syntax and creates structured ContentSection objects
- Smart skippable content detection (code blocks, technical content)

**Text-to-Speech System**
- TTSManager: Full playback control with AVSpeechSynthesizer
- Variable speed (0.5x-2.0x), rewind, section navigation
- Automatic progress tracking and bookmark support
- Audio session management for background playback

**SwiftUI Interface**
- ContentView: Repository browser with Core Data integration
- RepositoryDetailView: File listing with sync status indicators
- ReaderView: Complete TTS interface with playback controls
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
- Observable TTS manager with @Published state
- Type-safe enum extensions for database string fields
- Comprehensive error handling and edge case management

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