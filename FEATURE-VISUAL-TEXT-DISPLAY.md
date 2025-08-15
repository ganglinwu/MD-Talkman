# Visual Text Display Feature

**Feature Branch**: `feature/visual-text-display`  
**Target Release**: Phase 1.5 (between Core Audio and GitHub Integration)  
**Estimated Development Time**: 3-4 hours

## 🎯 Feature Overview

Add a visual text display component that shows 2-3 paragraphs of the currently playing content with automatic scrolling synchronized to TTS progress. This enhances accessibility and enables text search functionality while maintaining the audio-first design philosophy.

### Key Benefits
- **Enhanced Accessibility**: Visual context for hearing-impaired users
- **Text Search**: Find specific content within articles
- **Better Navigation**: Visual reference for current reading position
- **Driving Safety**: Optional display that doesn't distract from primary audio experience

## 🏗️ Technical Architecture

### 1. Git Branching Strategy
```bash
git checkout -b feature/visual-text-display
```

### 2. Component Design

#### VisualTextDisplayView
```swift
struct VisualTextDisplayView: View {
    let sections: [ContentSection]
    let currentPosition: Int
    let isVisible: Bool
    
    @State private var displayText: String = ""
    @State private var highlightRange: NSRange?
    @State private var scrollPosition: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Text display with auto-scroll
            ScrollViewReader { proxy in
                ScrollView {
                    Text(displayText)
                        .font(.body)
                        .lineSpacing(4)
                        .padding()
                        // Highlight current sentence/paragraph
                }
            }
            .frame(height: 200) // Fixed height for 2-3 paragraphs
        }
    }
}
```

#### TextWindowManager
```swift
class TextWindowManager: ObservableObject {
    @Published var displayWindow: String = ""
    @Published var currentHighlight: NSRange?
    
    private let windowSize = 3 // Show 3 paragraphs
    private var sections: [ContentSection] = []
    
    func updateWindow(for position: Int, in sections: [ContentSection]) {
        // Find current section and surrounding context
        let currentSection = findSection(for: position, in: sections)
        let windowSections = getWindowSections(around: currentSection)
        
        // Build display text with paragraph breaks
        displayWindow = buildDisplayText(from: windowSections)
        
        // Calculate highlight range for current sentence
        currentHighlight = calculateHighlightRange(for: position)
    }
    
    private func findSection(for position: Int, in sections: [ContentSection]) -> ContentSection? {
        return sections.first { section in
            position >= section.startIndex && position <= section.endIndex
        }
    }
    
    private func getWindowSections(around currentSection: ContentSection?) -> [ContentSection] {
        guard let current = currentSection,
              let index = sections.firstIndex(of: current) else { return [] }
        
        let start = max(0, index - 1) // Previous paragraph
        let end = min(sections.count - 1, index + 1) // Next paragraph
        
        return Array(sections[start...end])
    }
}
```

### 3. ReaderView Integration
```swift
struct ReaderView: View {
    @StateObject private var textWindowManager = TextWindowManager()
    @State private var showVisualDisplay = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Toggle for visual display
            HStack {
                Button(showVisualDisplay ? "Hide Text" : "Show Text") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showVisualDisplay.toggle()
                    }
                }
                Spacer()
            }
            .padding()
            
            // Visual text display (collapsible)
            if showVisualDisplay {
                VisualTextDisplayView(
                    windowManager: textWindowManager,
                    isVisible: showVisualDisplay
                )
                .transition(.slide)
            }
            
            // Existing TTS controls
            TTSControlsView(...)
        }
        .onChange(of: ttsManager.currentPosition) { position in
            // Sync visual display with TTS progress
            textWindowManager.updateWindow(for: position, in: parsedContent.sections)
        }
    }
}
```

## 🔄 Auto-Scroll Synchronization

### TTS Progress Integration
```swift
// In TTSManager.swift - enhance position tracking
extension TTSManager {
    func getCurrentSentenceRange() -> NSRange? {
        // Calculate current sentence boundaries
        // This helps with precise highlighting
    }
    
    func getSectionProgress() -> Float {
        // Calculate progress within current section
        // Useful for smooth scrolling animations
    }
}
```

### Smooth Scrolling Animation
```swift
struct VisualTextDisplayView: View {
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(textSections.indices, id: \.self) { index in
                        Text(textSections[index])
                            .id(index)
                            .background(
                                // Highlight current section
                                index == currentSectionIndex ? 
                                Color.blue.opacity(0.1) : Color.clear
                            )
                            .animation(.easeInOut(duration: 0.5), value: currentSectionIndex)
                    }
                }
                .padding()
            }
            .onChange(of: currentSectionIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.8)) {
                    proxy.scrollTo(newIndex, anchor: .top)
                }
            }
        }
    }
}
```

## 🎯 User Experience Features

### Search Integration
```swift
struct VisualTextDisplayView: View {
    @State private var searchText = ""
    @State private var searchResults: [NSRange] = []
    
    var body: some View {
        VStack {
            // Search bar
            HStack {
                TextField("Search in text...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                        searchResults = []
                    }
                }
            }
            .padding(.horizontal)
            
            // Text display with search highlights
            ScrollView {
                // Text with search highlighting
            }
        }
    }
}
```

### Accessibility Features
```swift
// Voice over support
Text(displayText)
    .accessibilityLabel("Currently reading: \(displayText)")
    .accessibilityAddTraits(.updatesFrequently)

// Dynamic Type support
Text(displayText)
    .font(.body)
    .dynamicTypeSize(...regularXL) // Limit for driving safety
```

## 📱 Device Adaptation

### Responsive Design
```swift
struct VisualTextDisplayView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var displayHeight: CGFloat {
        switch horizontalSizeClass {
        case .compact: return 150  // iPhone portrait
        case .regular: return 250  // iPad or iPhone landscape
        default: return 200
        }
    }
    
    var fontSize: Font {
        switch horizontalSizeClass {
        case .compact: return .callout  // Smaller for iPhone
        case .regular: return .body     // Regular for iPad
        default: return .body
        }
    }
}
```

### CarPlay Considerations
```swift
// Simplified view for CarPlay
#if canImport(CarPlay)
struct CarPlayVisualTextView: View {
    var body: some View {
        // Minimal text display optimized for automotive
        Text(currentSentence)
            .font(.title2)
            .fontWeight(.medium)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.8)
    }
}
#endif
```

## 🎛️ Settings Integration

```swift
// Add to SettingsView
struct VisualDisplaySettings: View {
    @AppStorage("showVisualDisplay") private var defaultShowVisual = false
    @AppStorage("visualDisplayHeight") private var displayHeight = 200.0
    @AppStorage("autoScrollSpeed") private var scrollSpeed = 0.8
    
    var body: some View {
        Section("Visual Text Display") {
            Toggle("Show by default", isOn: $defaultShowVisual)
            
            VStack {
                Text("Display Height: \(Int(displayHeight))pt")
                Slider(value: $displayHeight, in: 100...300, step: 25)
            }
            
            VStack {
                Text("Scroll Speed: \(scrollSpeed, specifier: "%.1f")x")
                Slider(value: $scrollSpeed, in: 0.3...1.5, step: 0.1)
            }
        }
    }
}
```

## 🧪 Testing Strategy

### Unit Tests
- **TextWindowManager**: Test text windowing logic
- **Position Calculation**: Verify accurate section finding
- **Search Functionality**: Test search highlighting accuracy

### UI Tests  
- **Toggle Functionality**: Show/hide visual display
- **Auto-scroll Behavior**: Verify smooth scrolling with TTS
- **Search Interface**: Test search bar and result navigation

### Integration Tests
- **TTS Synchronization**: Ensure visual display matches audio position
- **Performance**: Test with large embedded content files
- **Memory Usage**: Verify efficient text windowing

### Accessibility Tests
- **VoiceOver**: Ensure proper accessibility labels
- **Dynamic Type**: Test text scaling across size categories
- **Contrast**: Verify highlight visibility in different themes

## 📋 Implementation Phases

### Phase A: Core Infrastructure (1-2 hours)
1. ✅ Create feature branch
2. ⏳ Create `TextWindowManager` class
3. ⏳ Implement basic `VisualTextDisplayView`
4. ⏳ Add text windowing logic (2-3 paragraph display)

### Phase B: TTS Integration (1 hour)
5. ⏳ Integrate with existing `TTSManager`
6. ⏳ Add position synchronization
7. ⏳ Implement auto-scroll functionality

### Phase C: UI Polish (1 hour)
8. ⏳ Add toggle functionality to `ReaderView`
9. ⏳ Implement smooth scrolling animations
10. ⏳ Add visual highlighting for current section

### Phase D: Enhanced Features (30 mins)
11. ⏳ Add search functionality
12. ⏳ Test with all embedded content
13. ⏳ Add settings integration

## 🎨 Design Specifications

### Visual Hierarchy
- **Primary**: TTS controls (unchanged)
- **Secondary**: Visual text display (collapsible)
- **Tertiary**: Search functionality (contextual)

### Color Scheme
- **Current Text Highlight**: Blue.opacity(0.15)
- **Search Results**: Yellow.opacity(0.3) 
- **Background**: System background (adaptive)
- **Text**: Primary and secondary label colors

### Animation Timing
- **Show/Hide Display**: 0.3s ease-in-out
- **Auto-scroll**: 0.8s ease-in-out
- **Section Highlight**: 0.5s ease-in-out

### Typography
- **Display Text**: .body (16pt), line spacing 4pt
- **Search Field**: .callout (16pt)
- **iPhone Compact**: .callout (15pt) for space efficiency

## 🔧 File Structure Changes

### New Files
```
MD TalkMan/
├── Controllers/
│   └── TextWindowManager.swift      # NEW: Text windowing logic
├── Views/
│   ├── VisualTextDisplayView.swift  # NEW: Main visual component
│   └── TextSearchView.swift         # NEW: Search functionality
└── Utils/
    └── TextHighlighter.swift        # NEW: Search result highlighting
```

### Modified Files
- `ReaderView.swift`: Add visual display integration
- `SettingsView.swift`: Add visual display settings
- `TTSManager.swift`: Enhanced position tracking
- `ProjectStructure.md`: Update with new components

## 🚀 Success Criteria

### Functional Requirements
- [ ] Visual display shows 2-3 paragraphs of current content
- [ ] Auto-scroll synchronized with TTS progress
- [ ] Toggle show/hide functionality
- [ ] Search within displayed text
- [ ] Smooth animations and transitions

### Performance Requirements
- [ ] <100ms response time for position updates
- [ ] Smooth 60fps scrolling animations
- [ ] Memory usage <10MB for text windowing
- [ ] No impact on TTS playback performance

### Accessibility Requirements
- [ ] VoiceOver support for all text elements
- [ ] Dynamic Type support (up to .accessibilityLarge)
- [ ] High contrast mode compatibility
- [ ] Keyboard navigation support

### User Experience Requirements
- [ ] Intuitive toggle placement and behavior
- [ ] Clear visual hierarchy with TTS controls as primary
- [ ] Responsive design across iPhone/iPad orientations
- [ ] Distraction-free design suitable for driving mode

## 📝 Development Notes

### Technical Considerations
- Use `LazyVStack` for performance with long articles
- Implement text windowing to avoid memory issues
- Leverage SwiftUI's `ScrollViewReader` for precise scroll control
- Consider using `NSAttributedString` for rich text highlighting

### Design Decisions
- Fixed height display to maintain consistent UI layout
- Collapsible design to preserve audio-first philosophy  
- Minimal search interface to reduce cognitive load
- Automatic scrolling to reduce manual interaction while driving

### Future Enhancements
- Markdown rendering for headers, code blocks, lists
- Font size adjustment independent of system settings
- Night mode with high contrast options
- Export/share selected text functionality

---

**Note**: This feature maintains MD TalkMan's audio-first design philosophy while adding valuable visual functionality. The implementation prioritizes driving safety and accessibility throughout.