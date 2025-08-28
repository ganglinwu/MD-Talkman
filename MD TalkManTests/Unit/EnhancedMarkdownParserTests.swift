//
//  EnhancedMarkdownParserTests.swift
//  MD TalkManTests
//
//  Created by Claude on 8/28/25.
//

import XCTest
import CoreData
@testable import MD_TalkMan

final class EnhancedMarkdownParserTests: XCTestCase {
    
    var parser: MarkdownParser!
    var mockContext: NSManagedObjectContext!
    var testContainer: NSPersistentContainer!
    
    override func setUpWithError() throws {
        parser = MarkdownParser()
        
        // Create test persistence controller with in-memory store
        let testPersistenceController = PersistenceController(inMemory: true)
        testContainer = testPersistenceController.container
        mockContext = testContainer.viewContext
    }
    
    override func tearDownWithError() throws {
        parser = nil
        
        // Clean up Core Data
        let stores = testContainer.persistentStoreCoordinator.persistentStores
        for store in stores {
            try? testContainer.persistentStoreCoordinator.remove(store)
        }
        mockContext = nil
        testContainer = nil
    }
    
    // MARK: - Enhanced Code Block Format Tests
    
    func testCodeBlockWithLanguageNewFormat() {
        let markdown = """
        # Introduction
        
        Here's a Swift code example:
        
        ```swift
        func greet() {
            print("Hello, World!")
        }
        ```
        
        And here's some Python:
        
        ```python
        def greet():
            print("Hello, World!")
        ```
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        XCTAssertEqual(result.sections.count, 5)
        
        // Find code block sections
        let swiftCodeSection = result.sections.first { $0.type == .codeBlock && $0.spokenText.contains("[swift code]") }
        let pythonCodeSection = result.sections.first { $0.type == .codeBlock && $0.spokenText.contains("[python code]") }
        
        XCTAssertNotNil(swiftCodeSection, "Should find Swift code block")
        XCTAssertNotNil(pythonCodeSection, "Should find Python code block")
        
        XCTAssertEqual(swiftCodeSection?.spokenText, "[swift code] ")
        XCTAssertEqual(pythonCodeSection?.spokenText, "[python code] ")
        
        XCTAssertTrue(swiftCodeSection?.isSkippable ?? false, "Code blocks should be skippable")
        XCTAssertTrue(pythonCodeSection?.isSkippable ?? false, "Code blocks should be skippable")
    }
    
    func testCodeBlockWithoutLanguageNewFormat() {
        let markdown = """
        # Code Example
        
        ```
        function anonymous() {
            return "Hello";
        }
        ```
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        XCTAssertEqual(result.sections.count, 2)
        
        let codeSection = result.sections.first { $0.type == .codeBlock }
        XCTAssertNotNil(codeSection, "Should find code block")
        XCTAssertEqual(codeSection?.spokenText, "[code] ")
        XCTAssertTrue(codeSection?.isSkippable ?? false, "Code blocks should be skippable")
    }
    
    func testCodeBlockOldFormatCompatibility() {
        // Test that the parser still handles the old format if it exists
        let markdown = """
        # Legacy Code
        
        This is a test with the old format.
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        XCTAssertEqual(result.sections.count, 2)
        XCTAssertEqual(result.sections[0].type, .header)
        XCTAssertEqual(result.sections[1].type, .paragraph)
    }
    
    // MARK: - Language Detection Tests
    
    func testLanguageDetectionForCommonLanguages() {
        let testLanguages = [
            "swift", "python", "javascript", "typescript", "java", "kotlin", "rust", "go", "c", "cpp", "csharp",
            "ruby", "php", "html", "css", "sql", "bash", "shell", "powershell", "dockerfile", "yaml", "json", "xml",
            "markdown", "lua", "perl", "r", "matlab", "scala", "haskell", "clojure", "elixir", "erlang", "fsharp", "ocaml",
            "dart", "flutter", "objective-c", "swiftui", "react", "vue", "angular", "svelte", "next", "nuxt", "gatsby"
        ]
        
        for language in testLanguages {
            let markdown = """
            # Test
            
            ```\(language)
            // Code in \(language)
            ```
            """
            
            let result = parser.parseMarkdownForTTS(markdown)
            
            let codeSection = result.sections.first { $0.type == .codeBlock }
            XCTAssertNotNil(codeSection, "Should find code block for \(language)")
            XCTAssertEqual(codeSection?.spokenText, "[\(language) code] ", "Should detect \(language) correctly")
        }
    }
    
    func testLanguageDetectionCaseSensitivity() {
        let markdown = """
        # Case Sensitivity Test
        
        ```SWIFT
        let x = 1
        ```
        
        ```Python
        print("Hello")
        ```
        
        ```JavaScript
        console.log("Hello");
        ```
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        let codeSections = result.sections.filter { $0.type == .codeBlock }
        XCTAssertEqual(codeSections.count, 3)
        
        // Should handle case variations (convert to lowercase)
        let swiftSection = codeSections.first { $0.spokenText.contains("swift") }
        let pythonSection = codeSections.first { $0.spokenText.contains("python") }
        let jsSection = codeSections.first { $0.spokenText.contains("javascript") }
        
        XCTAssertNotNil(swiftSection, "Should handle uppercase SWIFT")
        XCTAssertNotNil(pythonSection, "Should handle title case Python")
        XCTAssertNotNil(jsSection, "Should handle title case JavaScript")
    }
    
    func testLanguageDetectionWithSpecialCharacters() {
        let markdown = """
        # Special Characters
        
        ```c++
        #include <iostream>
        ```
        
        ```c#
        using System;
        ```
        
        ```f#
        let x = 1
        ```
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        let codeSections = result.sections.filter { $0.type == .codeBlock }
        XCTAssertEqual(codeSections.count, 3)
        
        // Should handle language names with special characters
        let cppSection = codeSections.first { $0.spokenText.contains("c++") }
        let csharpSection = codeSections.first { $0.spokenText.contains("c#") }
        let fsharpSection = codeSections.first { $0.spokenText.contains("f#") }
        
        XCTAssertNotNil(cppSection, "Should handle c++")
        XCTAssertNotNil(csharpSection, "Should handle c#")
        XCTAssertNotNil(fsharpSection, "Should handle f#")
    }
    
    // MARK: - TTS Optimization Tests
    
    func testTTSSpokenTextOptimization() {
        let markdown = """
        # Optimization Test
        
        Regular paragraph with some text.
        
        ```swift
        func example() {
            // This is a comment
            let x = 42
            return x
        }
        ```
        
        Another regular paragraph.
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        XCTAssertEqual(result.sections.count, 4)
        
        let codeSection = result.sections.first { $0.type == .codeBlock }
        XCTAssertNotNil(codeSection, "Should find code block")
        
        // The spoken text should be optimized for TTS
        XCTAssertEqual(codeSection?.spokenText, "[swift code] ")
        XCTAssertFalse(codeSection?.spokenText.contains("Code block in swift begins") ?? true, "Should not use old verbose format")
        XCTAssertFalse(codeSection?.spokenText.contains("[Code content omitted]") ?? true, "Should not include content omission text")
    }
    
    func testTTSSpokenTextBrevity() {
        let markdown = """
        # Brevity Test
        
        ```python
        def long_function_name():
            \"\"\"This is a docstring\"\"\"
            result = complex_calculation()
            return result
        ```
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        let codeSection = result.sections.first { $0.type == .codeBlock }
        XCTAssertNotNil(codeSection, "Should find code block")
        
        // Should be very brief regardless of code complexity
        XCTAssertEqual(codeSection?.spokenText, "[python code] ")
        XCTAssertLessThanOrEqual(codeSection?.spokenText.count ?? 0, 15, "Spoken text should be very brief")
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyCodeBlock() {
        let markdown = """
        # Empty Code
        
        ```swift
        
        ```
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        XCTAssertEqual(result.sections.count, 2)
        
        let codeSection = result.sections.first { $0.type == .codeBlock }
        XCTAssertNotNil(codeSection, "Should handle empty code block")
        XCTAssertEqual(codeSection?.spokenText, "[swift code] ", "Should still format empty code block correctly")
    }
    
    func testCodeBlockWithOnlyWhitespace() {
        let markdown = """
        # Whitespace Only
        
        ```python
        
        
        ```
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        let codeSection = result.sections.first { $0.type == .codeBlock }
        XCTAssertNotNil(codeSection, "Should handle whitespace-only code block")
        XCTAssertEqual(codeSection?.spokenText, "[python code] ", "Should format whitespace-only code block")
    }
    
    func testCodeBlockWithSpecialLanguageNames() {
        let markdown = """
        # Special Language Names
        
        ```text
        This is plain text
        ```
        
        ```plain
        This is also plain text
        ```
        
        ```txt
        This is text too
        ```
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        let codeSections = result.sections.filter { $0.type == .codeBlock }
        XCTAssertEqual(codeSections.count, 3)
        
        // Should handle special text-based language names
        XCTAssertEqual(codeSections[0].spokenText, "[text code] ")
        XCTAssertEqual(codeSections[1].spokenText, "[plain code] ")
        XCTAssertEqual(codeSections[2].spokenText, "[txt code] ")
    }
    
    func testCodeBlockWithNumbersInLanguage() {
        let markdown = """
        # Numbered Languages
        
        ```html5
        <!DOCTYPE html>
        ```
        
        ```css3
        body { margin: 0; }
        ```
        
        ```ecmascript6
        const x = 1;
        ```
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        let codeSections = result.sections.filter { $0.type == .codeBlock }
        XCTAssertEqual(codeSections.count, 3)
        
        // Should handle language names with numbers
        XCTAssertEqual(codeSections[0].spokenText, "[html5 code] ")
        XCTAssertEqual(codeSections[1].spokenText, "[css3 code] ")
        XCTAssertEqual(codeSections[2].spokenText, "[ecmascript6 code] ")
    }
    
    func testUnclosedCodeBlock() {
        let markdown = """
        # Unclosed Code
        
        ```swift
        func example() {
            print("Hello")
        }
        
        Some text after unclosed code block.
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        // Should handle unclosed code blocks gracefully
        XCTAssertGreaterThan(result.sections.count, 1)
        
        let codeSection = result.sections.first { $0.type == .codeBlock }
        XCTAssertNotNil(codeSection, "Should detect unclosed code block")
    }
    
    func testMalformedCodeBlock() {
        let markdown = """
        # Malformed Code
        
        ````swift
        // Too many backticks
        func example() {}
        `````
        
        `single backtick`
        
        ```incomplete
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        // Should handle malformed code blocks gracefully
        XCTAssertGreaterThanOrEqual(result.sections.count, 1)
    }
    
    // MARK: - Mixed Content Tests
    
    func testMixedCodeBlocksAndRegularContent() {
        let markdown = """
        # Mixed Content
        
        This is a paragraph with some text.
        
        ```swift
        func swiftCode() {
            print("Swift")
        }
        ```
        
        This is another paragraph between code blocks.
        
        ```python
        def pythonCode():
            print("Python")
        ```
        
        Final paragraph after all code blocks.
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        XCTAssertEqual(result.sections.count, 6)
        
        // Check that we have the right mix
        let headers = result.sections.filter { $0.type == .header }
        let paragraphs = result.sections.filter { $0.type == .paragraph }
        let codeBlocks = result.sections.filter { $0.type == .codeBlock }
        
        XCTAssertEqual(headers.count, 1)
        XCTAssertEqual(paragraphs.count, 3)
        XCTAssertEqual(codeBlocks.count, 2)
        
        // Check specific spoken texts
        XCTAssertEqual(codeBlocks[0].spokenText, "[swift code] ")
        XCTAssertEqual(codeBlocks[1].spokenText, "[python code] ")
    }
    
    func testConsecutiveCodeBlocks() {
        let markdown = """
        # Consecutive Code Blocks
        
        ```swift
        let x = 1
        ```
        
        ```python
        x = 1
        ```
        
        ```javascript
        let x = 1;
        ```
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        XCTAssertEqual(result.sections.count, 4)
        
        let codeSections = result.sections.filter { $0.type == .codeBlock }
        XCTAssertEqual(codeSections.count, 3)
        
        XCTAssertEqual(codeSections[0].spokenText, "[swift code] ")
        XCTAssertEqual(codeSections[1].spokenText, "[python code] ")
        XCTAssertEqual(codeSections[2].spokenText, "[javascript code] ")
    }
    
    // MARK: - Performance Tests
    
    func testCodeBlockParsingPerformance() {
        var largeMarkdown = """
        # Large Document
        
        This is a test document with many code blocks.
        """
        
        // Add many code blocks
        for i in 0..<100 {
            largeMarkdown += """
            
            Paragraph \(i) with some text.
            
            ```language\(i)
            // Code in language \(i)
            let x = \(i);
            ```
            
            """
        }
        
        measure {
            let result = parser.parseMarkdownForTTS(largeMarkdown)
            let codeSections = result.sections.filter { $0.type == .codeBlock }
            XCTAssertEqual(codeSections.count, 100)
        }
    }
    
    func testLanguageDetectionPerformance() {
        let languages = ["swift", "python", "javascript", "java", "c", "cpp", "rust", "go", "ruby", "php"]
        
        measure {
            for language in languages {
                let markdown = """
                # Test
                
                ```\(language)
                // Code in \(language)
                ```
                """
                
                let result = parser.parseMarkdownForTTS(markdown)
                let codeSection = result.sections.first { $0.type == .codeBlock }
                XCTAssertEqual(codeSection?.spokenText, "[\(language) code] ")
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testIntegrationWithTextWindowManager() {
        let markdown = """
        # Integration Test
        
        This is a test paragraph.
        
        ```swift
        func integrate() {
            return "Success"
        }
        ```
        
        Another paragraph after code.
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        // Test that the result works well with TextWindowManager
        let windowManager = TextWindowManager()
        
        // Convert ParsedSection to ContentSection for TextWindowManager
        let contentSections: [ContentSection] = result.sections.map { parsedSection in
            let contentSection = ContentSection(context: mockContext)
            contentSection.startIndex = Int32(parsedSection.startIndex)
            contentSection.endIndex = Int32(parsedSection.endIndex)
            contentSection.type = parsedSection.type.rawValue
            contentSection.level = Int16(parsedSection.level)
            contentSection.isSkippable = parsedSection.isSkippable
            return contentSection
        }
        
        windowManager.loadContent(sections: contentSections, plainText: result.plainText)
        
        XCTAssertEqual(windowManager.getTotalSections(), result.sections.count)
        
        // Test window updates
        windowManager.updateWindow(for: 50)
        XCTAssertFalse(windowManager.displayWindow.isEmpty)
        
        windowManager.updateWindow(for: 150) // Should be in code block
        XCTAssertFalse(windowManager.displayWindow.isEmpty)
    }
    
    func testIntegrationWithTTSManager() {
        let markdown = """
        # TTS Integration
        
        Regular text content.
        
        ```python
        def tts_test():
            return "Test successful"
        ```
        
        More text content.
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        // The parsed result should be ready for TTS consumption
        XCTAssertEqual(result.sections.count, 4)
        
        let codeSection = result.sections.first { $0.type == .codeBlock }
        XCTAssertNotNil(codeSection)
        XCTAssertEqual(codeSection?.spokenText, "[python code] ")
        
        // The spoken text should be optimized for TTS playback
        XCTAssertFalse(codeSection?.spokenText.contains("Code block begins") ?? true)
        XCTAssertFalse(codeSection?.spokenText.contains("Code content omitted") ?? true)
    }
    
    // MARK: - Backward Compatibility Tests
    
    func testBackwardCompatibilityWithExistingTests() {
        // This test ensures that existing functionality still works
        let markdown = """
        # Main Title
        ## Subtitle
        ### Sub-subtitle
        
        This is a paragraph.
        
        - List item 1
        - List item 2
        
        > This is a quote.
        
        **Bold text** and *italic text*.
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        // Should still parse headers correctly
        XCTAssertEqual(result.sections[0].spokenText, "Heading level 1: Main Title. ")
        XCTAssertEqual(result.sections[1].spokenText, "Heading level 2: Subtitle. ")
        
        // Should still parse other elements correctly
        XCTAssertTrue(result.sections.contains { $0.type == .paragraph })
        XCTAssertTrue(result.sections.contains { $0.type == .list })
        XCTAssertTrue(result.sections.contains { $0.type == .blockquote })
    }
    
    func testBackwardCompatibilityWithOldCodeFormat() {
        // Test that documents using old code block format still work
        let markdown = """
        # Legacy Format
        
        Here's some code:
        
        ```swift
        func legacy() {
            print("Legacy format")
        }
        ```
        
        End of document.
        """
        
        let result = parser.parseMarkdownForTTS(markdown)
        
        XCTAssertEqual(result.sections.count, 3)
        
        let codeSection = result.sections.first { $0.type == .codeBlock }
        XCTAssertNotNil(codeSection)
        XCTAssertEqual(codeSection?.spokenText, "[swift code] ", "Should convert legacy format to new format")
    }
}