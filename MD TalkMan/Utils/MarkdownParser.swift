//
//  MarkdownParser.swift
//  MD TalkMan
//
//  Created by Claude on 8/14/25.
//

import Foundation
import CoreData

// MARK: - Parsed Section Structure
struct ParsedSection {
    let startIndex: Int
    let endIndex: Int
    let type: ContentSectionType
    let level: Int
    let isSkippable: Bool
    let originalText: String
    let spokenText: String
}

// MARK: - Markdown Parser
class MarkdownParser {
    
    // MARK: - Main Parsing Function
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
                // Skip empty lines but preserve spacing
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
                i = codeBlockResult.nextLineIndex - 1 // Will be incremented at end of loop
                
            } else if let listResult = parseListItem(line: line, startIndex: currentIndex) {
                sections.append(listResult.section)
                processedText += listResult.section.spokenText
                currentIndex += listResult.section.spokenText.count
                
            } else if let blockquoteResult = parseBlockquote(line: line, startIndex: currentIndex) {
                sections.append(blockquoteResult.section)
                processedText += blockquoteResult.section.spokenText
                currentIndex += blockquoteResult.section.spokenText.count
                
            } else {
                // Regular paragraph
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
        
        // Count header level
        var level = 0
        for char in trimmed {
            if char == "#" {
                level += 1
            } else if char == " " {
                break
            } else {
                return nil // Invalid header format
            }
        }
        
        guard level <= 6 else { return nil } // Max 6 levels
        
        // Extract header text
        let headerText = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
        let cleanText = removeMarkdownFormatting(headerText)
        
        // Convert to speech-friendly format
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
        
        // Find closing ```
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
            endIndex = lines.count - 1 // Handle unclosed code blocks
        }
        
        // Extract language (if specified)
        let language = String(firstLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        let languageText = language.isEmpty ? "" : " in \(language)"
        
        // Create TTS-friendly text
        let spokenText = "Code block\(languageText) begins. [Code content omitted for brevity] Code block ends. "
        
        let section = ParsedSection(
            startIndex: textIndex,
            endIndex: textIndex + spokenText.count,
            type: .codeBlock,
            level: 0,
            isSkippable: true, // Users can skip technical content
            originalText: lines[startIndex...endIndex].joined(separator: "\n"),
            spokenText: spokenText
        )
        
        return (section: section, nextLineIndex: endIndex + 1)
    }
    
    // MARK: - List Item Parsing
    private func parseListItem(line: String, startIndex: Int) -> (section: ParsedSection, nextLineIndex: Int)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Check for unordered list (-, *, +)
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
        
        // Check for ordered list (1., 2., etc.)
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

// MARK: - Core Data Integration
extension MarkdownParser {
    
    func processAndSaveMarkdownFile(_ markdownFile: MarkdownFile, 
                                   content: String, 
                                   in context: NSManagedObjectContext) {
        let parseResult = parseMarkdownForTTS(content)
        
        // Create or update ParsedContent
        let parsedContent: ParsedContent
        if let existing = markdownFile.parsedContent {
            parsedContent = existing
        } else {
            parsedContent = ParsedContent(context: context)
            parsedContent.fileId = markdownFile.id!
            markdownFile.parsedContent = parsedContent
        }
        
        parsedContent.plainText = parseResult.plainText
        parsedContent.lastParsed = Date()
        
        // Remove existing content sections
        if let existingSections = parsedContent.contentSection as? Set<ContentSection> {
            for section in existingSections {
                context.delete(section)
            }
        }
        
        // Create new content sections
        for parsedSection in parseResult.sections {
            let contentSection = ContentSection(context: context)
            contentSection.startIndex = Int32(parsedSection.startIndex)
            contentSection.endIndex = Int32(parsedSection.endIndex)
            contentSection.typeEnum = parsedSection.type
            contentSection.level = Int16(parsedSection.level)
            contentSection.isSkippable = parsedSection.isSkippable
            contentSection.parsedContent = parsedContent
        }
        
        // Save context
        do {
            try context.save()
        } catch {
            print("Failed to save parsed content: \(error)")
        }
    }
}