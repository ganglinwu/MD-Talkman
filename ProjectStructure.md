# MD TalkMan Project Structure

## Overview
The project is organized using a clean architecture pattern with separation of concerns for maintainability and testability.

## Folder Structure

```
MD TalkMan/
├── Core/                          # App entry point and core configuration
│   └── MD_TalkManApp.swift       # Main app entry point with Core Data setup
│
├── Views/                         # SwiftUI Views (Presentation Layer)
│   ├── ContentView.swift         # Main repository browser
│   ├── RepositoryDetailView.swift # File listing within repositories
│   └── ReaderView.swift          # TTS reader interface with controls
│
├── Controllers/                   # Business Logic and State Management
│   ├── PersistenceController.swift # Core Data stack management
│   └── TTSManager.swift          # Text-to-speech playback controller
│
├── Models/                        # Data Models and Core Data Schema
│   ├── DataModel.xcdatamodeld/   # Core Data model definition
│   └── CoreDataEnums.swift      # Type-safe enums for Core Data
│
├── Utils/                         # Utilities and Helper Classes
│   ├── MarkdownParser.swift     # Markdown to TTS conversion
│   └── MockData.swift           # Sample data for development/testing
│
└── Assets.xcassets/              # App icons, colors, and other assets

Tests/
├── Unit/                         # Unit Tests
│   ├── MarkdownParserTests.swift # Markdown parsing accuracy tests
│   └── TTSManagerTests.swift    # TTS functionality tests
│
├── Integration/                  # Integration Tests
│   └── IntegrationTests.swift   # End-to-end workflow tests
│
└── Utils/                        # Test Utilities
    └── TestConfiguration.swift  # Test data and helper methods

UITests/
└── ReaderViewUITests.swift      # UI interaction tests

Documentation/
├── CLAUDE.md                     # Complete project documentation
├── PersistentController.md      # Core Data architecture guide
├── TestSummary.md               # Test coverage summary
└── ProjectStructure.md          # This file
```

## Architecture Overview

### Core Layer
- **MD_TalkManApp.swift**: App entry point, dependency injection root
- Configures Core Data environment for the entire app
- Sets up navigation and global state management

### Views Layer (SwiftUI)
- **Presentation logic only** - no business logic
- **ContentView**: Repository browser with Core Data @FetchRequest
- **RepositoryDetailView**: File listing with navigation to reader
- **ReaderView**: Complete TTS interface with real-time controls

### Controllers Layer  
- **Business logic and state management**
- **PersistenceController**: Core Data stack, singleton pattern
- **TTSManager**: Observable object for TTS state (@Published properties)
- Handles user actions and coordinates between views and models

### Models Layer
- **Data definitions and Core Data schema**
- **DataModel.xcdatamodeld**: 6-entity Core Data model
- **CoreDataEnums.swift**: Type-safe Swift enums with Core Data integration

### Utils Layer
- **Pure functions and utilities** 
- **MarkdownParser**: Stateless markdown processing
- **MockData**: Development and testing sample data
- No dependencies on UI or state management

## Design Patterns Used

### 1. **Singleton Pattern**
```swift
// PersistenceController
static let shared = PersistenceController()
static var preview = PersistenceController(inMemory: true)
```

### 2. **Observer Pattern**  
```swift
// TTSManager as ObservableObject
@Published var playbackState: TTSPlaybackState
@Published var currentPosition: Int
```

### 3. **Dependency Injection**
```swift
// Views receive managed object context
.environment(\.managedObjectContext, persistenceController.container.viewContext)
```

### 4. **Strategy Pattern**
```swift
// Different TTS conversion strategies for markdown elements
parseHeader(), parseCodeBlock(), parseList(), parseParagraph()
```

### 5. **Factory Pattern**
```swift
// Test data creation
TestConfiguration.createTestRepository()
TestConfiguration.createTestMarkdownFile()
```

## Data Flow

### Reading Flow
```
User Tap → ContentView → RepositoryDetailView → ReaderView
                                                     ↓
MarkdownFile → MarkdownParser → ParsedContent → TTSManager
                                                     ↓
                               AVSpeechSynthesizer → Audio Output
```

### Data Persistence Flow
```
Markdown Content → MarkdownParser → Core Data Entities
                                         ↓
ReadingProgress ← User Interaction ← TTS Manager
                                         ↓
Core Data → PersistenceController → SQLite Database
```

## Testing Strategy

### Unit Tests
- **MarkdownParserTests**: Pure function testing, no dependencies
- **TTSManagerTests**: Mocked Core Data context, isolated testing
- Focus on individual component correctness

### Integration Tests  
- **End-to-end workflows**: Markdown → Core Data → TTS
- **Relationship integrity**: All Core Data relationships
- **Real data scenarios**: Large documents, edge cases

### UI Tests
- **User interaction workflows**: Navigation, controls, accessibility
- **State validation**: UI reflects underlying data changes
- **Performance testing**: App launch, large content handling

## Key Benefits of This Structure

### ✅ **Maintainability**
- Clear separation of concerns
- Easy to locate and modify specific functionality
- Consistent naming conventions

### ✅ **Testability**  
- Pure functions in Utils are easily testable
- Controllers can be tested with mocked dependencies
- Views focus only on presentation logic

### ✅ **Scalability**
- New features can be added to appropriate layers
- Controllers can be extended without affecting views
- Models can evolve independently

### ✅ **Team Collaboration**
- Different developers can work on different layers
- Clear file organization prevents merge conflicts
- Consistent patterns across the codebase

## File Naming Conventions

### Views
- Descriptive names ending in "View"
- Match the main functionality (ContentView, ReaderView)

### Controllers  
- End with "Controller" or "Manager"
- Indicate their primary responsibility (TTSManager, PersistenceController)

### Models
- Entity names match Core Data entities
- Enums follow Swift naming conventions (SyncStatus, ContentSectionType)

### Utils
- Descriptive class names indicating functionality
- No "Manager" or "Controller" suffix (MarkdownParser, MockData)

### Tests
- Mirror the main file structure  
- Append "Tests" to the class being tested
- Organized by test type (Unit/, Integration/, Utils/)

This structure provides a solid foundation for continued development while maintaining code quality and developer productivity.