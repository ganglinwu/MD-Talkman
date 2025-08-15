#!/usr/bin/env swift

//
//  MarkdownTTSSimulator.swift
//  MD TalkMan Simulation
//
//  A command-line tool to test markdown to TTS conversion
//

import Foundation
import AVFoundation

// MARK: - ContentSectionType Enum (simplified)
enum ContentSectionType: String, CaseIterable {
    case header = "header"
    case paragraph = "paragraph"
    case codeBlock = "codeBlock"
    case list = "list"
    case blockquote = "blockquote"
}

// MARK: - ParsedSection Structure
struct ParsedSection {
    let startIndex: Int
    let endIndex: Int
    let type: ContentSectionType
    let level: Int
    let isSkippable: Bool
    let originalText: String
    let spokenText: String
}

// MARK: - Markdown Parser (Simplified for Simulation)
class MarkdownParser {
    
    func parseMarkdownForTTS(_ markdownContent: String) -> (plainText: String, sections: [ParsedSection]) {
        let lines = markdownContent.components(separatedBy: .newlines)
        var processedText = ""
        var sections: [ParsedSection] = []
        var currentIndex = 0
        
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.isEmpty {
                processedText += " "
                currentIndex += 1
                i += 1
                continue
            }
            
            // Parse different markdown elements
            if let headerResult = parseHeader(line: line, startIndex: currentIndex) {
                sections.append(headerResult.section)
                processedText += headerResult.section.spokenText
                currentIndex += headerResult.section.spokenText.count
                
            } else if let codeBlockResult = parseCodeBlock(lines: lines, startIndex: i, textIndex: currentIndex) {
                sections.append(codeBlockResult.section)
                processedText += codeBlockResult.section.spokenText
                currentIndex += codeBlockResult.section.spokenText.count
                i = codeBlockResult.nextLineIndex - 1
                
            } else if let listResult = parseListItem(line: line, startIndex: currentIndex) {
                sections.append(listResult.section)
                processedText += listResult.section.spokenText
                currentIndex += listResult.section.spokenText.count
                
            } else if let blockquoteResult = parseBlockquote(line: line, startIndex: currentIndex) {
                sections.append(blockquoteResult.section)
                processedText += blockquoteResult.section.spokenText
                currentIndex += blockquoteResult.section.spokenText.count
                
            } else {
                let paragraphResult = parseParagraph(line: line, startIndex: currentIndex)
                sections.append(paragraphResult.section)
                processedText += paragraphResult.section.spokenText
                currentIndex += paragraphResult.section.spokenText.count
            }
            
            i += 1
        }
        
        return (plainText: processedText.trimmingCharacters(in: .whitespacesAndNewlines), 
                sections: sections)
    }
    
    // MARK: - Header Parsing
    private func parseHeader(line: String, startIndex: Int) -> (section: ParsedSection, nextLineIndex: Int)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }
        
        var level = 0
        for char in trimmed {
            if char == "#" {
                level += 1
            } else if char == " " {
                break
            } else {
                return nil
            }
        }
        
        guard level <= 6 else { return nil }
        
        let headerText = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
        let cleanText = removeMarkdownFormatting(headerText)
        
        let levelText = level <= 3 ? "Heading level \(level): " : "Subheading: "
        let spokenText = "\(levelText)\(cleanText). "
        
        let section = ParsedSection(
            startIndex: startIndex,
            endIndex: startIndex + spokenText.count,
            type: .header,
            level: level,
            isSkippable: false,
            originalText: line,
            spokenText: spokenText
        )
        
        return (section: section, nextLineIndex: 1)
    }
    
    // MARK: - Code Block Parsing
    private func parseCodeBlock(lines: [String], startIndex: Int, textIndex: Int) -> (section: ParsedSection, nextLineIndex: Int)? {
        let firstLine = lines[startIndex].trimmingCharacters(in: .whitespaces)
        guard firstLine.hasPrefix("```") else { return nil }
        
        var endIndex = startIndex + 1
        var foundEnd = false
        
        while endIndex < lines.count {
            if lines[endIndex].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                foundEnd = true
                break
            }
            endIndex += 1
        }
        
        if !foundEnd {
            endIndex = lines.count - 1
        }
        
        let language = String(firstLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        let languageText = language.isEmpty ? "" : " in \(language)"
        
        let spokenText = "Code block\(languageText) begins. [Code content omitted for brevity] Code block ends. "
        
        let section = ParsedSection(
            startIndex: textIndex,
            endIndex: textIndex + spokenText.count,
            type: .codeBlock,
            level: 0,
            isSkippable: true,
            originalText: lines[startIndex...endIndex].joined(separator: "\n"),
            spokenText: spokenText
        )
        
        return (section: section, nextLineIndex: endIndex + 1)
    }
    
    // MARK: - List Item Parsing
    private func parseListItem(line: String, startIndex: Int) -> (section: ParsedSection, nextLineIndex: Int)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Unordered list
        if let match = trimmed.range(of: #"^[-*+]\s+"#, options: .regularExpression) {
            let itemText = String(trimmed[match.upperBound...])
            let cleanText = removeMarkdownFormatting(itemText)
            let spokenText = "• \(cleanText). "
            
            let section = ParsedSection(
                startIndex: startIndex,
                endIndex: startIndex + spokenText.count,
                type: .list,
                level: 0,
                isSkippable: false,
                originalText: line,
                spokenText: spokenText
            )
            
            return (section: section, nextLineIndex: 1)
        }
        
        // Ordered list
        if let match = trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
            let itemText = String(trimmed[match.upperBound...])
            let cleanText = removeMarkdownFormatting(itemText)
            let spokenText = "\(cleanText). "
            
            let section = ParsedSection(
                startIndex: startIndex,
                endIndex: startIndex + spokenText.count,
                type: .list,
                level: 0,
                isSkippable: false,
                originalText: line,
                spokenText: spokenText
            )
            
            return (section: section, nextLineIndex: 1)
        }
        
        return nil
    }
    
    // MARK: - Blockquote Parsing
    private func parseBlockquote(line: String, startIndex: Int) -> (section: ParsedSection, nextLineIndex: Int)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(">") else { return nil }
        
        let quoteText = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
        let cleanText = removeMarkdownFormatting(quoteText)
        let spokenText = "Quote: \(cleanText). End quote. "
        
        let section = ParsedSection(
            startIndex: startIndex,
            endIndex: startIndex + spokenText.count,
            type: .blockquote,
            level: 0,
            isSkippable: false,
            originalText: line,
            spokenText: spokenText
        )
        
        return (section: section, nextLineIndex: 1)
    }
    
    // MARK: - Paragraph Parsing
    private func parseParagraph(line: String, startIndex: Int) -> (section: ParsedSection, nextLineIndex: Int) {
        let cleanText = removeMarkdownFormatting(line)
        let spokenText = "\(cleanText.trimmingCharacters(in: .whitespacesAndNewlines)). "
        
        let section = ParsedSection(
            startIndex: startIndex,
            endIndex: startIndex + spokenText.count,
            type: .paragraph,
            level: 0,
            isSkippable: false,
            originalText: line,
            spokenText: spokenText
        )
        
        return (section: section, nextLineIndex: 1)
    }
    
    // MARK: - Remove Markdown Formatting
    private func removeMarkdownFormatting(_ text: String) -> String {
        var result = text
        
        // Remove bold (**text** or __text__)
        result = result.replacingOccurrences(of: #"\*\*([^*]+)\*\*"#, with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: #"__([^_]+)__"#, with: "$1", options: .regularExpression)
        
        // Remove italic (*text* or _text_)
        result = result.replacingOccurrences(of: #"\*([^*]+)\*"#, with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: #"_([^_]+)_"#, with: "$1", options: .regularExpression)
        
        // Remove inline code (`text`)
        result = result.replacingOccurrences(of: #"`([^`]+)`"#, with: "$1", options: .regularExpression)
        
        // Remove links [text](url) -> text
        result = result.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
        
        // Remove images ![alt](url) -> alt text
        result = result.replacingOccurrences(of: #"!\[([^\]]*)\]\([^)]+\)"#, with: "Image: $1", options: .regularExpression)
        
        // Remove strikethrough (~~text~~)
        result = result.replacingOccurrences(of: #"~~([^~]+)~~"#, with: "$1", options: .regularExpression)
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - TTS Simulator
class TTSSimulator {
    private let synthesizer = AVSpeechSynthesizer()
    
    func speakText(_ text: String, rate: Float = 0.5) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        print("🔊 Speaking: \"\(text)\"")
        synthesizer.speak(utterance)
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

// MARK: - Main Simulation Function
func runMarkdownSimulation() {
    print("🎵 MD TalkMan - Markdown to TTS Simulator")
    print("=" * 50)
    
    let parser = MarkdownParser()
    let tts = TTSSimulator()
    
    // Sample markdown content
    let sampleMarkdown = """
# Getting Started with SwiftUI

SwiftUI is Apple's **modern framework** for building user interfaces.

## Key Features

- Declarative syntax
- Cross-platform compatibility
- Real-time previews

### Code Example

```swift
struct ContentView: View {
    var body: some View {
        Text("Hello, World!")
    }
}
```

> SwiftUI makes it easy to build great apps with less code.

For more information, visit [Apple's documentation](https://developer.apple.com).
"""
    
    print("📄 Original Markdown:")
    print(sampleMarkdown)
    print("\n" + "=" * 50)
    
    // Parse markdown
    let result = parser.parseMarkdownForTTS(sampleMarkdown)
    
    print("🎵 TTS Conversion:")
    print("Plain Text: \(result.plainText)")
    print("\n📋 Sections (\(result.sections.count) total):")
    
    for (index, section) in result.sections.enumerated() {
        let skipStatus = section.isSkippable ? " [SKIPPABLE]" : ""
        print("  \(index + 1). \(section.type.rawValue.uppercased())\(skipStatus):")
        print("     Original: \"\(section.originalText)\"")
        print("     Spoken:   \"\(section.spokenText.trimmingCharacters(in: .whitespaces))\"")
        print("")
    }
    
    print("=" * 50)
    print("🔊 Choose an option:")
    print("1. Speak entire document")
    print("2. Speak section by section")
    print("3. Speak only skippable content")
    print("4. Analyze a custom file")
    print("5. Exit")
    
    if let choice = readLine(), let option = Int(choice) {
        switch option {
        case 1:
            print("🎵 Speaking entire document...")
            tts.speakText(result.plainText)
            
        case 2:
            print("🎵 Speaking section by section...")
            for (index, section) in result.sections.enumerated() {
                print("Section \(index + 1): \(section.type.rawValue)")
                tts.speakText(section.spokenText)
                print("Press Enter for next section...")
                _ = readLine()
            }
            
        case 3:
            let skippableSections = result.sections.filter { $0.isSkippable }
            print("🎵 Speaking \(skippableSections.count) skippable sections...")
            for section in skippableSections {
                tts.speakText(section.spokenText)
            }
            
        case 4:
            print("📁 Enter path to markdown file:")
            if let filePath = readLine() {
                processCustomFile(filePath: filePath, parser: parser, tts: tts)
            }
            
        case 5:
            print("👋 Goodbye!")
            tts.stop()
            
        default:
            print("❌ Invalid option")
        }
    }
}

func processCustomFile(filePath: String, parser: MarkdownParser, tts: TTSSimulator) {
    do {
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        print("📄 Processing: \(filePath)")
        
        let result = parser.parseMarkdownForTTS(content)
        
        print("✅ Parsed \(result.sections.count) sections")
        print("📝 Total spoken text length: \(result.plainText.count) characters")
        
        print("\n🔊 Would you like to hear it? (y/n)")
        if let response = readLine(), response.lowercased() == "y" {
            tts.speakText(result.plainText)
        }
        
    } catch {
        print("❌ Error reading file: \(error)")
    }
}

// MARK: - String Extension for Separator
extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

// Run the simulation
runMarkdownSimulation()