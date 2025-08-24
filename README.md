# MD TalkMan 

A SwiftUI app for hands-free markdown reading with Claude.ai integration, designed for driving and accessibility.

## 🎯 Project Vision

MD TalkMan transforms markdown documents into an audio-first experience, perfect for consuming technical content while driving, walking, or when visual attention isn't available. The app integrates with GitHub repositories and Claude.ai for intelligent content interaction.

## ✅ Current Status: Phase 2 Complete - Production Webhook System

### 🎵 **Audio-First Markdown Experience**
- **Smart TTS Conversion**: Markdown syntax is transformed into natural speech
- **Visual Text Display**: Real-time text highlighting synchronized with TTS
- **Section Navigation**: Skip between headers, paragraphs, code blocks
- **Technical Content Skipping**: Automatically identify and skip code blocks
- **Speed Control**: Adjustable playback speed (0.5x - 2.0x)
- **Progress Tracking**: Resume exactly where you left off

### 🗃️ **Enterprise-Grade Data Architecture**
- **6-Entity Core Data Model**: Production-ready with perfect relationships
- **Type-Safe Enums**: SyncStatus, ContentSectionType with UI integration
- **Automatic Progress Saving**: Reading position, bookmarks, completion status
- **Embedded Content System**: 15 comprehensive Swift learning articles
- **GitHub Apps Integration**: JWT authentication with installation tokens

### 🧪 **Comprehensive Testing**
- **72 Total Tests**: Unit, integration, and UI test coverage
- **Performance Tested**: Large documents (1000+ sections)
- **Edge Case Handling**: Malformed markdown, empty content, error recovery
- **Mock Objects**: Isolated testing with realistic sample data
- **Visual Text Display**: Comprehensive text window and highlighting tests

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

### 🔗 **GitHub Integration & Webhook System**
- **GitHub Apps Authentication**: JWT-based secure API access
- **Repository Management**: Browse and access GitHub repositories
- **Installation Flow**: OAuth-based GitHub App installation
- **Production Webhook Server**: Go-based webhook handler deployed on EC2
- **Real APNs Integration**: Token-based push notifications for repository updates
- **AWS CloudFront Resolution**: Comprehensive webhook debugging and architecture

### 🛠️ **Production Infrastructure**
- **Docker Deployment**: Multi-stage builds with health checks
- **nginx Reverse Proxy**: Production-ready routing and rate limiting
- **APNs Push Notifications**: Real-time repository update notifications
- **GitHub Webhook Processing**: Smart markdown file change detection
- **EC2 Production Deployment**: Scalable webhook processing infrastructure

## 📋 **Roadmap**

### Phase 2: GitHub Integration & Webhook System ✅ COMPLETED
- [x] GitHub Apps authentication (JWT-based)
- [x] GitHub API integration with installation tokens
- [x] OAuth flow for GitHub Apps installation
- [x] Repository and file browser UI with GitHub integration
- [x] Production webhook server deployed on EC2
- [x] Real APNs integration with token-based authentication
- [x] Webhook debugging and architecture documentation

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
- **Unit Tests (39)**: MarkdownParser, TTSManager, TextWindowManager, Core Data entities
- **Integration Tests (18)**: End-to-end data flow, relationship integrity
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
- **[webhook-debugging-adventure.md](webhook-debugging-adventure.md)**: Complete webhook debugging story
- **[webhook-server/README.md](webhook-server/README.md)**: Production webhook server documentation
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
- **GitHub Apps API** for secure repository management
- **Apple Push Notification Service (APNs)** for real-time notifications
- **Go** and **Docker** for production webhook server
- **nginx** for reverse proxy and load balancing
- **Speech Framework** for voice recognition (upcoming)
- **Claude.ai** for intelligent content interaction (upcoming)

---

**MD TalkMan** - Transforming text into accessible audio experiences 🎵📚