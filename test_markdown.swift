#!/usr/bin/env swift

import Foundation

// Copy the sample markdown content to test
let markdownContent = """
# SwiftUI Development Guide

Welcome to **SwiftUI development**! This guide will help you get started.

## What is SwiftUI?

SwiftUI is Apple's *modern framework* for building user interfaces across all Apple platforms.

### Key Benefits

- **Declarative syntax** - Describe what your UI should look like
- **Cross-platform** - Works on iOS, macOS, watchOS, and tvOS  
- **Live previews** - See changes in real-time

## Getting Started

1. Create a new Xcode project
2. Choose SwiftUI as your interface
3. Start building your first view

```swift
import SwiftUI

struct ContentView: View {
    @State private var name = "World"
    
    var body: some View {
        VStack {
            Text("Hello, \\(name)!")
                .font(.largeTitle)
                .padding()
        }
    }
}
```

> Remember: SwiftUI views are value types, which makes them lightweight and efficient.

### Common Patterns

```javascript
// This would be skipped as technical content
const example = "code";
```

For more information, check out the [official documentation](https://developer.apple.com/documentation/swiftui).
"""

// Test markdown processing
func testMarkdownProcessing() {
    print("🧪 Testing Markdown to TTS Conversion")
    print("=" * 50)
    
    // Simulate the parsing logic from MarkdownParser
    let lines = markdownContent.components(separatedBy: .newlines)
    var ttsOutput = ""
    var sectionCount = 0
    
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        if trimmed.isEmpty {
            continue
        }
        
        if trimmed.hasPrefix("#") {
            // Header
            let level = trimmed.prefix(while: { $0 == "#" }).count
            let headerText = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
            let cleanText = removeMarkdownFormatting(headerText)
            let spoken = "Heading level \\(level): \\(cleanText). "
            
            print("📍 HEADER (Level \\(level)): \\(cleanText)")
            ttsOutput += spoken
            sectionCount += 1
            
        } else if trimmed.hasPrefix("```") {
            // Code block
            print("💻 CODE BLOCK [SKIPPABLE]: Technical content detected")
            ttsOutput += "Code block begins. [Code content omitted for brevity] Code block ends. "
            sectionCount += 1
            
        } else if trimmed.hasPrefix("-") || trimmed.hasPrefix("*") || trimmed.hasPrefix("+") {
            // List item
            let itemText = String(trimmed.dropFirst(2))
            let cleanText = removeMarkdownFormatting(itemText)
            let spoken = "• \\(cleanText). "
            
            print("📝 LIST ITEM: \\(cleanText)")
            ttsOutput += spoken
            sectionCount += 1
            
        } else if trimmed.hasPrefix(">") {
            // Blockquote
            let quoteText = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            let cleanText = removeMarkdownFormatting(quoteText)
            let spoken = "Quote: \\(cleanText). End quote. "
            
            print("💬 BLOCKQUOTE: \\(cleanText)")
            ttsOutput += spoken
            sectionCount += 1
            
        } else if trimmed.hasPrefix(#"\\d+\\."#) {
            // Numbered list
            let cleanText = removeMarkdownFormatting(trimmed)
            let spoken = "\\(cleanText). "
            
            print("🔢 NUMBERED LIST: \\(cleanText)")
            ttsOutput += spoken
            sectionCount += 1
            
        } else if !trimmed.isEmpty {
            // Regular paragraph
            let cleanText = removeMarkdownFormatting(trimmed)
            let spoken = "\\(cleanText). "
            
            print("📄 PARAGRAPH: \\(cleanText)")
            ttsOutput += spoken
            sectionCount += 1
        }
    }
    
    print("\\n" + "=" * 50)
    print("📊 SUMMARY:")
    print("Total sections processed: \\(sectionCount)")
    print("Total TTS text length: \\(ttsOutput.count) characters")
    print("\\n🎵 FINAL TTS OUTPUT:")
    print("\\\"\\(ttsOutput.trimmingCharacters(in: .whitespacesAndNewlines))\\\"")
}

func removeMarkdownFormatting(_ text: String) -> String {
    var result = text
    
    // Remove bold (**text** or __text__)
    result = result.replacingOccurrences(of: #"\\*\\*([^*]+)\\*\\*"#, with: "$1", options: .regularExpression)
    result = result.replacingOccurrences(of: #"__([^_]+)__"#, with: "$1", options: .regularExpression)
    
    // Remove italic (*text* or _text_)
    result = result.replacingOccurrences(of: #"\\*([^*]+)\\*"#, with: "$1", options: .regularExpression)
    result = result.replacingOccurrences(of: #"_([^_]+)_"#, with: "$1", options: .regularExpression)
    
    // Remove inline code (`text`)
    result = result.replacingOccurrences(of: #"`([^`]+)`"#, with: "$1", options: .regularExpression)
    
    // Remove links [text](url) -> text
    result = result.replacingOccurrences(of: #"\\[([^\\]]+)\\]\\([^)]+\\)"#, with: "$1", options: .regularExpression)
    
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
}

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

// Run the test
testMarkdownProcessing()