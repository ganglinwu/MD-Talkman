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
- GitHub Apps API for repository access and webhooks
- JWT-based authentication for secure GitHub integration
- Production webhook server (Go) deployed on EC2 with nginx
- APNs push notifications for repository changes
- Support for private repositories with installation-based access

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

### Enhanced Concurrent GitHub Sync (Phase 3+)

**Current Sequential Processing:**
```swift
// Phase 2 Implementation - Sequential processing
func syncRepository() {
    for file in markdownFiles {
        downloadFile(file)        // Download one file
        parseMarkdown(file)       // Parse it
        saveToDatabase(file)      // Save it
    }
}
```

**Enhanced Concurrent Architecture:**
```swift
// Phase 3 Enhancement - Parallel processing
func syncRepositoryEnhanced() async {
    let files = await discoverMarkdownFiles()
    
    await withTaskGroup(of: Void.self) { group in
        for file in files.chunked(into: 5) { // Batch processing
            group.addTask {
                let backgroundContext = persistentContainer.newBackgroundContext()
                await processFilesBatch(file, context: backgroundContext)
            }
        }
    }
}

private func processFilesBatch(_ files: [String], context: NSManagedObjectContext) async {
    for file in files {
        let content = await downloadFile(file)
        let parsed = parseMarkdown(content)
        await context.perform {
            saveToDatabase(parsed, context: context)
        }
    }
}
```

**Performance Benefits:**
- **10x faster sync** for repositories with 50+ markdown files
- **Intelligent batching** prevents overwhelming Core Data
- **Progress tracking** with real-time UI updates
- **Core Data safety** with isolated background contexts

**Use Cases:**
- Large documentation repositories
- Multi-file Claude analysis sessions
- Background sync during TTS playback
- Concurrent Claude API processing for insights

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

## GitHub Sync & Processing Architecture

### Complete GitHub-to-TTS Pipeline
The app now features a full pipeline from GitHub repositories to TTS-ready content:

```swift
// GitHub Sync Flow
1. GitHub Authentication (JWT + Installation Tokens)
   ↓ 
2. Repository Discovery (GitHub Apps API)
   ↓
3. Markdown File Detection (.md, .markdown files)
   ↓
4. Content Download (raw file content via download_url)
   ↓
5. Markdown Parsing (MarkdownParser.parseMarkdownForTTS)
   ↓
6. Core Data Storage (ParsedContent + ContentSection entities)
   ↓
7. TTS Playback (Real GitHub content, not sample data)
```

### GitHubAppManager Features
- **JWT Authentication**: Secure GitHub Apps integration with private key signing
- **Token Persistence**: UserDefaults storage with automatic restoration on launch
- **Installation Management**: Complete OAuth flow with callback handling
- **Repository Syncing**: Full markdown file discovery and content processing
- **Error Handling**: Comprehensive fallback strategies and user feedback

### Markdown Processing System
- **Real-time Processing**: Downloads and parses files during sync operation
- **TTS Optimization**: Converts markdown syntax to spoken-friendly plain text
- **Section Analysis**: Identifies headers, code blocks, and skippable content
- **Core Data Integration**: Creates ParsedContent and ContentSection entities
- **Content Verification**: Ensures GitHub content takes precedence over sample data

### Smart Content Loading
The ReaderView now intelligently chooses content sources:
- **GitHub ParsedContent exists**: ✅ Uses real repository content
- **No ParsedContent found**: 🔄 Falls back to embedded sample content
- **Prevents Overwrites**: Never replaces GitHub content with sample data

### UI Status Integration
- **Real-time Feedback**: Shows parsing progress during sync operations
- **Visual Indicators**: Files display parsing status and readiness
- **Smart Disabling**: Unparsed files are disabled until processing completes
- **Progress Tracking**: Users see file-by-file parsing progress

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

### Interjection Event System
A sophisticated audio management system that handles contextual announcements during TTS playback without interrupting the natural speech flow.

**Architecture Pattern: Deferred Execution**
```swift
// Interjection events wait for natural TTS pauses (utterance completion)
enum InterjectionEvent {
    case codeBlockStart(language: String?, section: ContentSection)
    case codeBlockEnd(section: ContentSection)
    
    // Phase 4 Extensions (for Claude AI integration):
    case claudeInsight(text: String, context: String)
    case userQuestion(query: String)
    case contextualHelp(topic: String)
}
```

**InterjectionManager Features:**
- **Natural Flow Coordination**: Events are deferred until natural TTS pauses (between utterances)
- **Voice Contrast**: Uses female voice (Samantha/Ava) for code block announcements vs. main content voice
- **Configurable Notifications**: Supports smart detection, tones only, voice only, or both
- **Event-Driven Architecture**: Extensible system ready for Phase 4 Claude AI integration
- **Audio Session Safety**: Minimal audio conflicts through careful timing coordination

**Technical Benefits:**
- **Seamless Experience**: No jarring TTS interruptions or audio artifacts  
- **Intelligent Timing**: Uses `AVSpeechSynthesizerDelegate.didFinish` for perfect coordination
- **Memory Safe**: Temporary synthesizer instances with proper delegate lifecycle management
- **Extensible Design**: Ready for Claude insights, contextual help, and user interactions

**Code Block Enhancement Flow:**
```swift
// 1. Code block detected during TTS section transition
// 2. InterjectionEvent.codeBlockStart created with language info
// 3. Event deferred to pendingInterjection property  
// 4. Natural TTS pause occurs (utterance completes)
// 5. InterjectionManager executes event:
//    - Language announcement: "swift code" (female voice)
//    - End-of-interjection tone (subtle completion signal)
// 6. TTS resumes naturally with next content chunk
```

**Phase 4 Readiness:**
The system is architected to handle future Claude AI interjections:
- **Claude Insights**: AI-generated explanations injected at relevant sections
- **User Questions**: Voice queries processed and answered mid-reading
- **Contextual Help**: Smart assistance based on current content type

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
- [x] Create comprehensive test suite (39 unit tests + integration + UI tests)
- [x] Build embedded content system with 15 Swift learning articles
- [x] Resolve iOS sandbox limitations with embedded architecture
- [x] **Visual Text Display System**: Real-time text highlighting synchronized with TTS
- [x] Create project structure and comprehensive documentation

### Phase 2: GitHub Integration & Webhook System ✅ COMPLETED
- [x] Add GitHub Apps authentication (JWT-based)
- [x] Implement GitHub API integration with installation tokens
- [x] Build OAuth flow for GitHub Apps installation
- [x] Create repository and file browser UI with GitHub integration
- [x] **Production Webhook Server**: Go-based webhook handler deployed on EC2
- [x] **Real APNs Integration**: Token-based push notifications for repository updates
- [x] **Webhook Debugging & Architecture**: Complete troubleshooting documentation
- [x] **iOS APNs Client Integration**: Complete push notification handling in iOS app
- [x] **GitHub Management UI**: Comprehensive repository management interface
- [x] **Real-time Markdown Processing**: Direct GitHub file fetching and parsing
- [x] **Connection Persistence**: Auto-restore GitHub authentication on app launch
- [x] **Smart Content Loading**: Prevents overwriting GitHub content with sample data

### Phase 3: Test Infrastructure & Quality Assurance ✅ COMPLETED
- [x] **Comprehensive Test Suite Hardening**: 72 unit, integration, and UI tests with 100% pass rate
- [x] **Core Data Relationship Validation**: Fixed all entity relationship and validation errors
- [x] **Swift 6 Compatibility**: Resolved Sendable conformance and concurrency issues
- [x] **UI Test Automation**: Enhanced navigation, element detection, and state handling
- [x] **Error Handling Robustness**: Comprehensive edge case coverage and graceful degradation
- [x] **TTS State Management**: Complete playback state validation and error recovery
- [x] **Performance Optimization**: Memory management and resource cleanup validation
- [x] **Cross-Platform Testing**: iPhone/iPad UI test compatibility and accessibility

### Phase 4: Claude AI Integration (Next Phase)
- [ ] Integrate Speech framework for voice input
- [ ] Connect Claude API with file context
- [ ] Implement conversation history per file
- [ ] Add TTS for Claude responses
- [ ] **Enhanced Concurrent GitHub Sync**: Parallel file processing for improved performance

### Phase 5: Hands-Free Optimization
- [ ] Build CarPlay integration
- [ ] Add voice commands and shortcuts
- [ ] Implement driving mode UI
- [ ] Add advanced audio controls (bookmarks, section skipping)

### Phase 6: Apple Watch Remote Control
- [ ] Add watchOS target and WatchConnectivity framework
- [ ] Implement gesture-based controls (wrist rotation for section navigation)
- [ ] Add lift-to-speak voice command activation
- [ ] Create watch complication for quick playback controls
- [ ] Develop crown rotation for TTS speed adjustment
- [ ] Implement safety stop gesture (cover watch face)
- [ ] Add haptic feedback for all control actions
- [ ] Optimize for driving scenarios with minimal visual interface

### Phase 7: Polish & Advanced Features
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
- **Interjection Event System**: Natural pause-based audio announcements without TTS interruption

**Visual Text Display System**
- TextWindowManager: Intelligent text windowing with 2-3 paragraph context
- VisualTextDisplayView: SwiftUI component with real-time highlighting
- Auto-scroll functionality synchronized with TTS progress
- Search within displayed text with multi-highlight support
- Responsive design adapting to iPhone/iPad screen sizes
- Dual-layer highlighting: current position + search results
- Toggle show/hide with smooth animations and section progress indicators

**SwiftUI Interface**
- ContentView: Repository browser with Core Data integration and GitHub connection status
- RepositoryDetailView: File listing with sync status indicators
- ReaderView: Complete TTS interface with enhanced playback controls
- VoiceSettingsView: Premium voice selection and audio customization
- SettingsView: Developer mode toggle, data management, and push notification controls
- GitHubManagementView: Comprehensive GitHub repository management interface
- Clean navigation hierarchy with proper state management and sheet presentations

**GitHub Apps Integration**
- JWT signing for secure GitHub API authentication
- Installation token management with automatic refresh
- GitHub App installation flow with OAuth callback handling
- Repository access verification and permission management
- GitHubAppManager: Complete API client with installation-based authentication
- Repository management UI with refresh, sync, and disconnect capabilities
- User-friendly connection status display and repository listing

**APNs Push Notification System**
- APNsManager: Complete push notification handling with UserNotifications framework
- AppDelegate: UIKit delegate integration for push notification callbacks
- Device token registration with production webhook server (EC2)
- Push notification permission flow with user-friendly UI in SettingsView
- Repository update notifications with automatic sync triggers
- Background notification processing and foreground display
- Core Data integration for repository sync status updates

**Complete GitHub-to-TTS Pipeline**
- GitHubAppManager: Full repository sync with JWT authentication and token persistence
- Real-time markdown file discovery and content downloading from GitHub API
- Automated parsing pipeline converting GitHub markdown to TTS-ready plain text
- Smart content loading preventing overwrite of GitHub content with sample data
- UI status integration with parsing progress indicators and file readiness states
- Production-ready error handling and fallback strategies for robust operation

**Interjection Event System (Phase 4 Foundation)**
- InterjectionManager: Event-driven audio announcement system with natural TTS flow coordination
- Deferred execution pattern: Events wait for natural utterance completion (no forced interruptions)
- Voice contrast system: Female voice announcements distinct from main content narration
- Multi-modal notifications: Configurable tones, voice announcements, or combined approaches
- Memory-safe temporary synthesizer instances with proper delegate lifecycle management
- Extensible architecture ready for Claude AI insights, user questions, and contextual help
- Code block language detection and announcement: "swift code", "javascript code", etc.
- End-of-interjection tone system for clear audio boundaries and professional UX

**Comprehensive Testing**
- 21 unit tests for markdown parsing accuracy
- 15 TTS manager tests with mock objects
- 18 text window manager tests with comprehensive coverage
- 8 integration tests for complete data flow
- 10 UI tests for user interaction validation
- Performance testing with large documents and visual display
- Edge case and error handling coverage across all components

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
- **Visual text display architecture** with efficient text windowing algorithms
- **Character-based position tracking** for precise TTS-to-text synchronization
- **AttributedString highlighting** with dual-layer support (position + search)
- **Responsive SwiftUI design** adapting to device sizes and orientations
- **Event-driven interjection system** with natural TTS pause coordination
- **Deferred execution pattern** for seamless audio flow without interruptions
- **Multi-voice architecture** with female contrast voices for announcements
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