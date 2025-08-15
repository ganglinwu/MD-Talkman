//
//  MarkdownParserTests.swift
//  MD TalkManTests
//
//  Created by Claude on 8/14/25.
//

import XCTest
import CoreData
@testable import MD_TalkMan

final class MarkdownParserTests: XCTestCase {
    
    var parser: MarkdownParser!
    
    override func setUpWithError() throws {
        parser = MarkdownParser()
    }
    
    override func tearDownWithError() throws {
        parser = nil
    }
    
    // MARK: - Header Parsing Tests
    
    func testHeaderParsing() throws {
        let markdown = """
        # Main Title
        ## Subtitle
        ### Sub-subtitle
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        XCTAssertEqual(result.sections.count, 3)
        
        // Test first header
        let firstSection = result.sections[0]
        XCTAssertEqual(firstSection.type, .header)
        XCTAssertEqual(firstSection.level, 1)
        XCTAssertEqual(firstSection.spokenText, "Heading level 1: Main Title. ")
        XCTAssertFalse(firstSection.isSkippable)
        
        // Test second header
        let secondSection = result.sections[1]
        XCTAssertEqual(secondSection.type, .header)
        XCTAssertEqual(secondSection.level, 2)
        XCTAssertEqual(secondSection.spokenText, "Heading level 2: Subtitle. ")
        
        // Test third header
        let thirdSection = result.sections[2]
        XCTAssertEqual(thirdSection.type, .header)
        XCTAssertEqual(thirdSection.level, 3)
        XCTAssertEqual(thirdSection.spokenText, "Heading level 3: Sub-subtitle. ")
    }
    
    func testInvalidHeaders() throws {
        let markdown = """
        ####### Too many hashes
        #No space after hash
        # 
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        // Invalid headers should be parsed as paragraphs
        XCTAssertEqual(result.sections.count, 3)
        XCTAssertEqual(result.sections[0].type, .paragraph)
        XCTAssertEqual(result.sections[1].type, .paragraph)
        XCTAssertEqual(result.sections[2].type, .paragraph)
    }
    
    // MARK: - Code Block Parsing Tests
    
    func testCodeBlockParsing() throws {
        let markdown = """
        Here's some code:
        
        ```swift
        func hello() {
            print("Hello, World!")
        }
        ```
        
        End of example.
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        XCTAssertEqual(result.sections.count, 3)
        
        let codeSection = result.sections[1]
        XCTAssertEqual(codeSection.type, .codeBlock)
        XCTAssertTrue(codeSection.isSkippable)
        XCTAssertEqual(codeSection.spokenText, "Code block in swift begins. [Code content omitted for brevity] Code block ends. ")
    }
    
    func testCodeBlockWithoutLanguage() throws {
        let markdown = """
        ```
        some code here
        ```
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        XCTAssertEqual(result.sections.count, 1)
        let codeSection = result.sections[0]
        XCTAssertEqual(codeSection.spokenText, "Code block begins. [Code content omitted for brevity] Code block ends. ")
    }
    
    func testUnclosedCodeBlock() throws {
        let markdown = """
        ```swift
        unclosed code block
        more code
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        XCTAssertEqual(result.sections.count, 1)
        let codeSection = result.sections[0]
        XCTAssertEqual(codeSection.type, .codeBlock)
        XCTAssertTrue(codeSection.isSkippable)
    }
    
    // MARK: - List Parsing Tests
    
    func testUnorderedListParsing() throws {
        let markdown = """
        - First item
        * Second item
        + Third item
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        XCTAssertEqual(result.sections.count, 3)
        
        for section in result.sections {
            XCTAssertEqual(section.type, .list)
            XCTAssertFalse(section.isSkippable)
            XCTAssertTrue(section.spokenText.hasPrefix("• "))
        }
        
        XCTAssertEqual(result.sections[0].spokenText, "• First item. ")
        XCTAssertEqual(result.sections[1].spokenText, "• Second item. ")
        XCTAssertEqual(result.sections[2].spokenText, "• Third item. ")
    }
    
    func testOrderedListParsing() throws {
        let markdown = """
        1. First item
        2. Second item
        3. Third item
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        XCTAssertEqual(result.sections.count, 3)
        
        for section in result.sections {
            XCTAssertEqual(section.type, .list)
            XCTAssertFalse(section.isSkippable)
        }
        
        XCTAssertEqual(result.sections[0].spokenText, "First item. ")
        XCTAssertEqual(result.sections[1].spokenText, "Second item. ")
        XCTAssertEqual(result.sections[2].spokenText, "Third item. ")
    }
    
    // MARK: - Blockquote Parsing Tests
    
    func testBlockquoteParsing() throws {
        let markdown = """
        > This is a quote
        > Another line of the quote
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        XCTAssertEqual(result.sections.count, 2)
        
        for section in result.sections {
            XCTAssertEqual(section.type, .blockquote)
            XCTAssertFalse(section.isSkippable)
            XCTAssertTrue(section.spokenText.hasPrefix("Quote: "))
            XCTAssertTrue(section.spokenText.hasSuffix(" End quote. "))
        }
    }
    
    // MARK: - Formatting Removal Tests
    
    func testFormattingRemoval() throws {
        let markdown = """
        This has **bold** and *italic* text.
        Also `inline code` and [a link](http://example.com).
        Here's an image: ![alt text](image.jpg)
        And ~~strikethrough~~ text.
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        let plainText = result.plainText
        
        // Should not contain markdown syntax
        XCTAssertFalse(plainText.contains("**"))
        XCTAssertFalse(plainText.contains("*"))
        XCTAssertFalse(plainText.contains("`"))
        XCTAssertFalse(plainText.contains("["))
        XCTAssertFalse(plainText.contains("]("))
        XCTAssertFalse(plainText.contains("!["))
        XCTAssertFalse(plainText.contains("~~"))
        
        // Should contain clean text
        XCTAssertTrue(plainText.contains("bold"))
        XCTAssertTrue(plainText.contains("italic"))
        XCTAssertTrue(plainText.contains("inline code"))
        XCTAssertTrue(plainText.contains("a link"))
        XCTAssertTrue(plainText.contains("Image: alt text"))
        XCTAssertTrue(plainText.contains("strikethrough"))
    }
    
    // MARK: - Section Index Tests
    
    func testSectionIndices() throws {
        let markdown = """
        # Title
        Some paragraph text.
        ## Subtitle
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        XCTAssertEqual(result.sections.count, 3)
        
        // Indices should be sequential and non-overlapping
        var currentIndex = 0
        for section in result.sections {
            XCTAssertEqual(section.startIndex, currentIndex)
            XCTAssertGreaterThan(section.endIndex, section.startIndex)
            currentIndex = section.endIndex
        }
        
        // Total length should match plain text length
        XCTAssertEqual(currentIndex, result.plainText.count)
    }
    
    // MARK: - Complex Document Test
    
    func testComplexDocument() throws {
        let markdown = """
        # Getting Started with SwiftUI
        
        SwiftUI is Apple's modern framework for building user interfaces.
        
        ## Key Features
        
        - Declarative syntax
        - Live previews
        - Cross-platform support
        
        Here's a simple example:
        
        ```swift
        struct ContentView: View {
            var body: some View {
                Text("Hello, World!")
            }
        }
        ```
        
        > SwiftUI makes UI development easier and more intuitive.
        
        ### Getting Started
        
        1. Create new project
        2. Select SwiftUI template
        3. Start coding
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        // Should have multiple section types
        let sectionTypes = Set(result.sections.map { $0.type })
        XCTAssertTrue(sectionTypes.contains(.header))
        XCTAssertTrue(sectionTypes.contains(.paragraph))
        XCTAssertTrue(sectionTypes.contains(.list))
        XCTAssertTrue(sectionTypes.contains(.codeBlock))
        XCTAssertTrue(sectionTypes.contains(.blockquote))
        
        // Should have at least one skippable section (code block)
        let skippableSections = result.sections.filter { $0.isSkippable }
        XCTAssertGreaterThan(skippableSections.count, 0)
        
        // Plain text should be reasonable length and clean
        XCTAssertGreaterThan(result.plainText.count, 100)
        XCTAssertFalse(result.plainText.contains("```"))
        XCTAssertFalse(result.plainText.contains("##"))
    }
    
    // MARK: - Empty Content Tests
    
    func testEmptyContent() throws {
        let result = parser.parseMarkdownForTTS("")
        
        XCTAssertEqual(result.plainText, "")
        XCTAssertEqual(result.sections.count, 0)
    }
    
    func testWhitespaceOnly() throws {
        let markdown = """
        
        
           
        
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        XCTAssertEqual(result.plainText.trimmingCharacters(in: .whitespacesAndNewlines), "")
    }
    
    // MARK: - Performance Tests
    
    func testLargeDocumentPerformance() throws {
        // Create a large document
        var largeMarkdown = ""
        for i in 1...1000 {
            largeMarkdown += "## Section \(i)\n\nThis is paragraph \(i) with some content.\n\n"
        }
        
        measure {
            _ = parser.parseMarkdownForTTS(largeMarkdown)
        }
    }
}