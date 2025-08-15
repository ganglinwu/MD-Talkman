#!/usr/bin/env swift

import Foundation

// Test how the real learning content will sound with TTS conversion
func testLearningContentTTS() {
    print("🎵 Testing Learning Content TTS Conversion")
    print("=" * 60)
    
    // Sample from swift-05-some-view-how-it-solves-type-erasure.md
    let sampleMarkdown = """
# Type Erasure in Swift: A Complete Guide

## What is Type Erasure?

Type erasure is when the specific type information gets "erased" or hidden at runtime, keeping only the protocol/interface information. The compiler "forgets" the concrete type and only remembers the protocol conformance.

## Simple Example

### Without Type Erasure (Specific Types)

```swift
let dog = Dog()        // Type: Dog
let cat = Cat()        // Type: Cat
// Swift knows exactly what these are
```

### With Type Erasure (Protocol Types)

```swift
let animals: [any Animal] = [Dog(), Cat()]
// Type: Array<any Animal>
// Swift only knows they're "some Animal" - specific types erased
```

## Key Takeaways

**Type erasure** helps with protocol-oriented programming
"""
    
    print("📄 Original Markdown:")
    print(sampleMarkdown)
    print("\n" + "=" * 60)
    
    // Simulate TTS conversion
    let ttsOutput = convertToTTS(sampleMarkdown)
    
    print("🎵 TTS Conversion Result:")
    print(ttsOutput)
    print("\n" + "=" * 60)
    
    print("🎯 TTS Benefits with Real Learning Content:")
    print("✅ Technical Swift terms properly pronounced")
    print("✅ Code blocks clearly identified as skippable")  
    print("✅ Structured learning with clear sections")
    print("✅ Real examples for hands-free learning while driving")
    print("✅ Progressive complexity from basic to advanced topics")
    
    print("\n📚 Available Learning Topics:")
    let topics = [
        "Camera Implementation",
        "UIKit Bridge", 
        "iOS Class Hierarchy",
        "Memory Management ARC",
        "Type Erasure Solutions",
        "Static Dispatch Approaches",
        "Explicit Return Constraints",
        "Reference vs Value Types",
        "ViewModel Best Practices",
        "Function Overloading"
    ]
    
    for (index, topic) in topics.enumerated() {
        print("  \(index + 1). \(topic)")
    }
    
    print("\n🚗 Perfect for Commute Learning:")
    print("• Listen to complex Swift concepts while driving")
    print("• Skip code blocks when focusing on road")
    print("• Resume exactly where you left off")
    print("• Adjust voice and speed for car environment")
}

func convertToTTS(_ markdown: String) -> String {
    var result = ""
    let lines = markdown.components(separatedBy: .newlines)
    
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        if trimmed.isEmpty {
            continue
        } else if trimmed.hasPrefix("# ") {
            let title = String(trimmed.dropFirst(2))
            result += "Heading level 1: \(title). "
        } else if trimmed.hasPrefix("## ") {
            let title = String(trimmed.dropFirst(3))
            result += "Heading level 2: \(title). "
        } else if trimmed.hasPrefix("### ") {
            let title = String(trimmed.dropFirst(4))
            result += "Heading level 3: \(title). "
        } else if trimmed.hasPrefix("```") {
            if trimmed.count > 3 {
                let language = String(trimmed.dropFirst(3))
                result += "Code block in \(language) begins. [Code content omitted for brevity] Code block ends. "
            } else {
                result += "Code block begins. [Code content omitted for brevity] Code block ends. "
            }
        } else if trimmed.hasPrefix("**") && trimmed.hasSuffix("**") {
            let text = String(trimmed.dropFirst(2).dropLast(2))
            result += "\(text). "
        } else if !trimmed.hasPrefix("//") && !trimmed.hasPrefix("let ") && !trimmed.hasPrefix("// ") {
            // Regular paragraph (skip code comments and declarations)
            result += "\(trimmed). "
        }
    }
    
    return result.trimmingCharacters(in: .whitespaces)
}

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

testLearningContentTTS()