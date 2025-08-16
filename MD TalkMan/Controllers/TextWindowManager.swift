//
//  TextWindowManager.swift
//  MD TalkMan
//
//  Created by Claude on 8/16/25.
//

import Foundation
import SwiftUI

/// Manages the text windowing system for the visual text display
/// Provides 2-3 paragraph context window that moves with TTS progress
class TextWindowManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var displayWindow: String = ""
    @Published var currentHighlight: NSRange?
    @Published var currentSectionIndex: Int = 0
    @Published var isLoading: Bool = false
    
    // MARK: - Configuration
    private let windowSize = 3 // Show 3 paragraphs (previous, current, next)
    private let maxDisplayLength = 2000 // Maximum characters to display at once
    
    // MARK: - Current Content
    private var sections: [ContentSection] = []
    private var plainText: String = ""
    private var currentPosition: Int = 0
    
    // MARK: - Content Loading
    
    /// Load content sections and plain text for windowing
    func loadContent(sections: [ContentSection], plainText: String) {
        self.sections = sections.sorted { $0.startIndex < $1.startIndex }
        self.plainText = plainText
        
        print("📖 TextWindowManager: Loaded \(sections.count) sections, \(plainText.count) characters")
        
        // Initialize with first window
        updateWindow(for: 0)
    }
    
    // MARK: - Window Updates
    
    /// Update the display window for the given position
    func updateWindow(for position: Int) {
        guard !sections.isEmpty, !plainText.isEmpty else {
            displayWindow = ""
            currentHighlight = nil
            return
        }
        
        currentPosition = position
        
        // Find current section and surrounding context
        let currentSection = findSection(for: position)
        let windowSections = getWindowSections(around: currentSection)
        
        // Build display text with paragraph breaks
        displayWindow = buildDisplayText(from: windowSections)
        
        // Calculate highlight range for current position
        currentHighlight = calculateHighlightRange(for: position, in: windowSections)
        
        // Update section index for UI feedback
        if let currentSection = currentSection,
           let index = sections.firstIndex(where: { $0.startIndex == currentSection.startIndex }) {
            currentSectionIndex = index
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Find the section containing the given position
    private func findSection(for position: Int) -> ContentSection? {
        return sections.first { section in
            position >= section.startIndex && position < section.endIndex
        }
    }
    
    /// Get sections for the display window (previous, current, next)
    private func getWindowSections(around currentSection: ContentSection?) -> [ContentSection] {
        guard let current = currentSection,
              let index = sections.firstIndex(where: { $0.startIndex == current.startIndex }) else {
            // If no current section, show first few sections
            return Array(sections.prefix(windowSize))
        }
        
        let start = max(0, index - 1) // Previous paragraph
        let end = min(sections.count - 1, index + windowSize - 2) // Current + next paragraphs
        
        return Array(sections[start...end])
    }
    
    /// Build display text from sections with proper formatting
    private func buildDisplayText(from windowSections: [ContentSection]) -> String {
        guard !windowSections.isEmpty else { return "" }
        
        var displayText = ""
        
        for (index, section) in windowSections.enumerated() {
            let startPos = Int(section.startIndex)
            let endPos = Int(section.endIndex)
            
            // Validate positions
            guard startPos < plainText.count,
                  endPos <= plainText.count,
                  startPos < endPos else { continue }
            
            let startIndex = plainText.index(plainText.startIndex, offsetBy: startPos)
            let endIndex = plainText.index(plainText.startIndex, offsetBy: endPos)
            
            let sectionText = String(plainText[startIndex..<endIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !sectionText.isEmpty {
                if index > 0 {
                    displayText += "\n\n" // Double line break between sections
                }
                displayText += sectionText
            }
        }
        
        // Trim to maximum display length if needed
        if displayText.count > maxDisplayLength {
            let maxIndex = displayText.index(displayText.startIndex, offsetBy: maxDisplayLength)
            displayText = String(displayText[..<maxIndex]) + "..."
        }
        
        return displayText
    }
    
    /// Calculate highlight range for current reading position
    private func calculateHighlightRange(for position: Int, in windowSections: [ContentSection]) -> NSRange? {
        guard !windowSections.isEmpty,
              let currentSection = findSection(for: position) else { return nil }
        
        // Find the start of the current section in the display text
        var displayOffset = 0
        var foundSection = false
        
        for section in windowSections {
            if section.startIndex == currentSection.startIndex {
                foundSection = true
                break
            }
            
            // Add length of previous sections + line breaks
            let sectionLength = max(0, Int(section.endIndex - section.startIndex))
            displayOffset += sectionLength + 2 // +2 for "\n\n"
        }
        
        guard foundSection else { return nil }
        
        // Calculate position within current section
        let positionInSection = position - Int(currentSection.startIndex)
        let highlightStart = displayOffset + positionInSection
        
        // Highlight current sentence (approximately 50-100 characters)
        let sentenceLength = min(80, displayWindow.count - highlightStart)
        
        guard highlightStart >= 0,
              highlightStart + sentenceLength <= displayWindow.count else { return nil }
        
        return NSRange(location: highlightStart, length: max(1, sentenceLength))
    }
    
    // MARK: - Search Functionality
    
    /// Search for text within the current display window
    func searchInWindow(_ searchText: String) -> [NSRange] {
        guard !searchText.isEmpty,
              !displayWindow.isEmpty else { return [] }
        
        var ranges: [NSRange] = []
        let lowercaseWindow = displayWindow.lowercased()
        let lowercaseSearch = searchText.lowercased()
        
        var searchRange = lowercaseWindow.startIndex..<lowercaseWindow.endIndex
        
        while let range = lowercaseWindow.range(of: lowercaseSearch, range: searchRange) {
            let nsRange = NSRange(range, in: lowercaseWindow)
            ranges.append(nsRange)
            
            // Move search range past this match
            searchRange = range.upperBound..<lowercaseWindow.endIndex
        }
        
        return ranges
    }
    
    // MARK: - Section Navigation
    
    /// Get section info for current display
    func getCurrentSectionInfo() -> (type: ContentSectionType?, level: Int, isSkippable: Bool) {
        guard currentSectionIndex < sections.count else {
            return (nil, 0, false)
        }
        
        let section = sections[currentSectionIndex]
        return (section.typeEnum, Int(section.level), section.isSkippable)
    }
    
    /// Get total number of sections
    func getTotalSections() -> Int {
        return sections.count
    }
    
    /// Navigate to specific section
    func navigateToSection(_ index: Int) -> Int? {
        guard index >= 0, index < sections.count else { return nil }
        
        let section = sections[index]
        let position = Int(section.startIndex)
        
        updateWindow(for: position)
        return position
    }
    
    // MARK: - Debug Information
    
    /// Get debug information about current state
    func getDebugInfo() -> String {
        return """
        📖 TextWindowManager Debug:
        - Sections: \(sections.count)
        - Current Section: \(currentSectionIndex)
        - Current Position: \(currentPosition)
        - Display Length: \(displayWindow.count) chars
        - Highlight: \(currentHighlight?.debugDescription ?? "nil")
        """
    }
}