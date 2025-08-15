# MD TalkMan 

A SwiftUI app for hands-free markdown reading with Claude.ai integration, designed for driving and accessibility.

## 🎯 Project Vision

MD TalkMan transforms markdown documents into an audio-first experience, perfect for consuming technical content while driving, walking, or when visual attention isn't available. The app integrates with GitHub repositories and Claude.ai for intelligent content interaction.

## ✅ Current Status: Phase 1 Complete

### 🎵 **Audio-First Markdown Experience**
- **Smart TTS Conversion**: Markdown syntax is transformed into natural speech
- **Section Navigation**: Skip between headers, paragraphs, code blocks
- **Technical Content Skipping**: Automatically identify and skip code blocks
- **Speed Control**: Adjustable playback speed (0.5x - 2.0x)
- **Progress Tracking**: Resume exactly where you left off

### 🗃️ **Enterprise-Grade Data Architecture**
- **6-Entity Core Data Model**: Production-ready with perfect relationships
- **Type-Safe Enums**: SyncStatus, ContentSectionType with UI integration
- **Automatic Progress Saving**: Reading position, bookmarks, completion status
- **GitHub Sync Ready**: Data model prepared for repository synchronization

### 🧪 **Comprehensive Testing**
- **44 Total Tests**: Unit, integration, and UI test coverage
- **Performance Tested**: Large documents (1000+ sections)
- **Edge Case Handling**: Malformed markdown, empty content, error recovery
- **Mock Objects**: Isolated testing with realistic sample data

## 🏗️ **Architecture Highlights**

### Clean Architecture
```
Views/ (SwiftUI Presentation)
├── ContentView.swift         # Repository browser
├── RepositoryDetailView.swift # File listing  
└── ReaderView.swift          # TTS interface

Controllers/ (Business Logic)
├── PersistenceController.swift # Core Data management
└── TTSManager.swift           # Audio playback control

Models/ (Data Layer)
├── DataModel.xcdatamodeld     # Core Data schema
└── CoreDataEnums.swift        # Type-safe enums

Utils/ (Pure Functions)
├── MarkdownParser.swift       # Markdown → TTS conversion
└── MockData.swift             # Development data
```

### Key Design Patterns
- **Observable Objects**: Real-time UI updates with @Published properties
- **Dependency Injection**: Clean testing with environment objects
- **Singleton Pattern**: Shared persistence and TTS managers
- **Strategy Pattern**: Different parsing strategies for markdown elements

## 🎵 **TTS Conversion Examples**

```
Input:  # Getting Started with SwiftUI
Output: "Heading level 1: Getting Started with SwiftUI."

Input:  **Bold text** and *italic text*
Output: "Bold text and italic text"

Input:  ```swift
        let example = "code"
        ```
Output: "Code block in swift begins. [Code content omitted for brevity] Code block ends."

Input:  > This is a quote
Output: "Quote: This is a quote. End quote."

Input:  - First item
        - Second item
Output: "• First item. • Second item."
```

## 🚀 **Getting Started**

### Prerequisites
- Xcode 15.0+
- iOS 17.0+ (for latest SwiftUI features)
- macOS 14.0+ (for development)

### Quick Start
1. **Clone the repository**
   ```bash
   git clone https://github.com/user/md-talkman
   cd md-talkman
   ```

2. **Open in Xcode**
   ```bash
   open "MD TalkMan.xcodeproj"
   ```

3. **Run the app**
   - Select iOS Simulator or device
   - Press ⌘R to build and run
   - Sample data will populate automatically

4. **Test the TTS functionality**
   - Navigate to a repository → file
   - Tap the play button to start audio playback
   - Use section navigation and speed controls

### Running Tests
```bash
# Run all tests
xcodebuild test -project "MD TalkMan.xcodeproj" -scheme "MD TalkMan"

# Run specific test suite
xcodebuild test -project "MD TalkMan.xcodeproj" -scheme "MD TalkMan" -only-testing:MD_TalkManTests/MarkdownParserTests
```

## 📋 **Roadmap**

### Phase 2: GitHub Integration (Next)
- [ ] OAuth authentication with GitHub
- [ ] Repository cloning and local sync
- [ ] Git operations (commit, push, pull)
- [ ] Real-time sync status indicators

### Phase 3: Claude.ai Integration
- [ ] Speech-to-text for voice questions
- [ ] Claude API integration with file context
- [ ] Conversation history per document
- [ ] Claude response TTS playback

### Phase 4: CarPlay & Accessibility
- [ ] CarPlay integration for steering wheel controls
- [ ] iOS Shortcuts and Siri integration
- [ ] Voice commands for hands-free operation
- [ ] Advanced bookmarking and navigation

## 🧪 **Testing Strategy**

### Test Coverage
- **Unit Tests (21)**: MarkdownParser, TTSManager, Core Data entities
- **Integration Tests (8)**: End-to-end data flow, relationship integrity
- **UI Tests (10)**: User interaction, navigation, accessibility
- **Utils Tests (5)**: Test configuration, mock data validation

### Quality Assurance
- **Performance Testing**: Large documents, memory usage
- **Edge Case Coverage**: Malformed markdown, empty content
- **Error Recovery**: Graceful handling of parsing failures
- **Accessibility**: VoiceOver compatibility, large text support

## 📚 **Documentation**

- **[CLAUDE.md](CLAUDE.md)**: Complete project architecture and implementation details
- **[ProjectStructure.md](ProjectStructure.md)**: Folder organization and design patterns
- **[PersistentController.md](PersistentController.md)**: Core Data architecture guide
- **[TestSummary.md](TestSummary.md)**: Comprehensive testing coverage report

## 🤝 **Contributing**

The project follows clean architecture principles with clear separation of concerns:

1. **Views**: SwiftUI presentation logic only
2. **Controllers**: Business logic and state management  
3. **Models**: Data definitions and Core Data schema
4. **Utils**: Pure functions and utilities
5. **Tests**: Comprehensive coverage with realistic scenarios

### Code Style
- Swift 5.9+ with latest language features
- SwiftUI declarative patterns
- Comprehensive documentation
- Type-safe Core Data integration
- Observable object patterns for state management

## 📄 **License**

MIT License - see LICENSE file for details.

## 🙏 **Acknowledgments**

- Built with **SwiftUI** and **Core Data**
- **AVFoundation** for text-to-speech functionality  
- **Speech Framework** for voice recognition (upcoming)
- **Claude.ai** for intelligent content interaction (upcoming)
- **GitHub API** for repository management (upcoming)

---

**MD TalkMan** - Transforming text into accessible audio experiences 🎵📚