//
//  VisualTextDisplayView.swift
//  MD TalkMan
//
//  Created by Claude on 8/16/25.
//

import SwiftUI

/// SwiftUI view component for visual text display with highlighting and auto-scroll
struct VisualTextDisplayView: View {
    
    // MARK: - Properties
    @ObservedObject var windowManager: TextWindowManager
    let isVisible: Bool
    
    // MARK: - State
    @State private var searchText = ""
    @State private var searchResults: [NSRange] = []
    @State private var scrollPosition: Int = 0
    
    // MARK: - Environment
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            if isVisible {
                // Search bar
                searchBar
                
                // Text display with auto-scroll
                textDisplayView
                    .frame(height: displayHeight)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .onChange(of: windowManager.currentSectionIndex) { _ in
            withAnimation(.easeInOut(duration: 0.8)) {
                scrollToCurrentPosition()
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search in text...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .onChange(of: searchText) { newValue in
                    searchResults = windowManager.searchInWindow(newValue)
                }
            
            if !searchText.isEmpty {
                Button("Clear") {
                    searchText = ""
                    searchResults = []
                }
                .foregroundColor(.blue)
                .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    // MARK: - Text Display
    private var textDisplayView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    attributedTextView
                        .id("textContent")
                }
                .padding()
            }
            .onChange(of: windowManager.displayWindow) { _ in
                // Auto-scroll when content updates
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo("textContent", anchor: .top)
                }
            }
        }
    }
    
    // MARK: - Attributed Text with Highlighting
    private var attributedTextView: some View {
        Text(createAttributedString())
            .font(fontSize)
            .lineSpacing(4)
            .multilineTextAlignment(.leading)
            .accessibilityLabel("Currently reading: \(windowManager.displayWindow)")
            .accessibilityAddTraits(.updatesFrequently)
    }
    
    // MARK: - Helper Methods
    
    /// Create attributed string with highlighting
    private func createAttributedString() -> AttributedString {
        var attributedString = AttributedString(windowManager.displayWindow)
        
        // Apply current position highlighting
        if let highlightRange = windowManager.currentHighlight,
           highlightRange.location >= 0,
           highlightRange.location + highlightRange.length <= attributedString.characters.count {
            
            let startIndex = attributedString.index(attributedString.startIndex, offsetByCharacters: highlightRange.location)
            let endIndex = attributedString.index(startIndex, offsetByCharacters: highlightRange.length)
            
            if startIndex < attributedString.endIndex && endIndex <= attributedString.endIndex {
                attributedString[startIndex..<endIndex].backgroundColor = .blue.opacity(0.15)
                attributedString[startIndex..<endIndex].foregroundColor = .primary
            }
        }
        
        // Apply search result highlighting
        for searchRange in searchResults {
            if searchRange.location >= 0,
               searchRange.location + searchRange.length <= attributedString.characters.count {
                
                let startIndex = attributedString.index(attributedString.startIndex, offsetByCharacters: searchRange.location)
                let endIndex = attributedString.index(startIndex, offsetByCharacters: searchRange.length)
                
                if startIndex < attributedString.endIndex && endIndex <= attributedString.endIndex {
                    attributedString[startIndex..<endIndex].backgroundColor = .yellow.opacity(0.3)
                    attributedString[startIndex..<endIndex].foregroundColor = .primary
                }
            }
        }
        
        return attributedString
    }
    
    /// Scroll to current reading position
    private func scrollToCurrentPosition() {
        // This method can be enhanced to scroll to specific highlight position
        // For now, the auto-scroll in textDisplayView handles most cases
    }
    
    // MARK: - Responsive Design
    
    /// Display height based on device size
    private var displayHeight: CGFloat {
        switch horizontalSizeClass {
        case .compact: return 150  // iPhone portrait
        case .regular: return 250  // iPad or iPhone landscape
        default: return 200
        }
    }
    
    /// Font size based on device size
    private var fontSize: Font {
        switch horizontalSizeClass {
        case .compact: return .callout  // Smaller for iPhone
        case .regular: return .body     // Regular for iPad
        default: return .body
        }
    }
}

// MARK: - Preview
#Preview {
    let windowManager = TextWindowManager()
    
    // Load sample content for preview
    let sampleSections = createSampleSections()
    let sampleText = "This is a sample text for previewing the visual text display. It contains multiple paragraphs to demonstrate the windowing functionality. The text should highlight the current reading position and allow for smooth scrolling as the TTS progresses through the content."
    
    windowManager.loadContent(sections: sampleSections, plainText: sampleText)
    windowManager.updateWindow(for: 50)
    
    return VisualTextDisplayView(
        windowManager: windowManager,
        isVisible: true
    )
    .padding()
}

// MARK: - Preview Helper
private func createSampleSections() -> [ContentSection] {
    // This would normally come from Core Data, but for preview we create mock sections
    let mockContext = PersistenceController.preview.container.viewContext
    
    let section1 = ContentSection(context: mockContext)
    section1.startIndex = 0
    section1.endIndex = 100
    section1.typeEnum = .paragraph
    section1.level = 0
    section1.isSkippable = false
    
    let section2 = ContentSection(context: mockContext)
    section2.startIndex = 100
    section2.endIndex = 200
    section2.typeEnum = .paragraph
    section2.level = 0
    section2.isSkippable = false
    
    return [section1, section2]
}