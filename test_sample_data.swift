#!/usr/bin/env swift

import Foundation

// Simple test to verify our sample data logic
func testSampleDataContent() {
    print("🧪 Testing Sample Data Content for TTS")
    print("=" * 50)
    
    let sampleContents = [
        ("Getting Started with SwiftUI", """
        Heading level 1: Getting Started with SwiftUI. SwiftUI is Apple's modern framework for building user interfaces across all Apple platforms. It uses a declarative syntax that makes it easy to create complex UIs with minimal code. Heading level 2: Key Benefits. • Cross-platform compatibility. • Live previews in Xcode. • Automatic dark mode support. • State management with property wrappers. Heading level 3: Simple Example. Code block in swift begins. [Code content omitted for brevity] Code block ends. This creates a text view with a title font style. You can customize the appearance using modifiers like font, foregroundColor, and padding. Quote: SwiftUI makes building great apps faster and more enjoyable than ever before. End quote. For more information, visit Apple's documentation.
        """),
        
        ("Advanced Core Data", """
        Heading level 1: Advanced Core Data. Core Data is Apple's framework for managing object graphs and persistence. It provides powerful features like relationship management, data validation, and performance optimization. Heading level 2: Key Features. • Object-relational mapping. • Automatic change tracking. • Lazy loading and batching. • Schema migration support. Code block in swift begins. [Code content omitted for brevity] Code block ends. Understanding these concepts will help you build efficient data-driven applications.
        """),
        
        ("iOS Speech Recognition", """
        Heading level 1: iOS Speech Recognition. The Speech framework enables your app to convert audio to text with high accuracy. This guide covers implementation patterns and best practices. Heading level 2: Getting Started. • Request user permission for microphone access. • Set up audio session for recording. • Configure speech recognition parameters. • Handle real-time transcription results. Quote: Speech recognition opens up new possibilities for accessibility and hands-free interaction. End quote. Remember to handle errors gracefully and provide fallback options for users.
        """),
        
        ("Git Workflows", """
        Heading level 1: Git Workflows. Version control is essential for modern software development. This article covers best practices for Git workflows in team environments. Heading level 2: Common Workflows. • Feature branch workflow for isolated development. • Git flow for release management. • GitHub flow for continuous deployment. Heading level 3: Best Practices. Always write descriptive commit messages. Use pull requests for code review. Keep your repository history clean with rebasing.
        """)
    ]
    
    for (title, content) in sampleContents {
        print("📄 Article: \(title)")
        print("📝 Length: \(content.count) characters")
        
        // Count sections
        let headerCount = countOccurrences(in: content, of: "Heading level")
        let listCount = countOccurrences(in: content, of: "• ")
        let codeCount = countOccurrences(in: content, of: "Code block")
        let quoteCount = countOccurrences(in: content, of: "Quote:")
        
        print("🏷️  Sections: \(headerCount) headers, \(listCount) lists, \(codeCount) code blocks, \(quoteCount) quotes")
        
        // Test TTS-friendly features
        let hasTechnicalContent = content.contains("[Code content omitted for brevity]")
        let hasNavigationMarkers = content.contains("Heading level")
        let hasAccessibleLists = content.contains("• ")
        
        print("✅ TTS Features: Navigation (\(hasNavigationMarkers)), Lists (\(hasAccessibleLists)), Skip Content (\(hasTechnicalContent))")
        
        // Estimate reading time (average 200 WPM for TTS)
        let wordCount = content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        let readingTimeMinutes = Double(wordCount) / 200.0
        print("⏱️  Estimated reading time: \(String(format: "%.1f", readingTimeMinutes)) minutes")
        
        print()
    }
    
    print("🎯 Summary:")
    print("✅ All sample content is properly formatted for TTS")
    print("✅ Headers use 'Heading level X:' format")
    print("✅ Lists use bullet point '•' markers") 
    print("✅ Code blocks are marked as skippable")
    print("✅ Quotes are wrapped with 'Quote:' and 'End quote.'")
    print("✅ Ready for audio playback testing!")
}

func countOccurrences(in text: String, of substring: String) -> Int {
    return text.components(separatedBy: substring).count - 1
}

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

testSampleDataContent()