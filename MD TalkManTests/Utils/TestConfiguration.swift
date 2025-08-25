//
//  TestConfiguration.swift
//  MD TalkManTests
//
//  Created by Claude on 8/14/25.
//

import Foundation
import CoreData
import XCTest
@testable import MD_TalkMan

// MARK: - Test Configuration and Utilities

struct TestConfiguration {
    
    // MARK: - Sample Content
    
    static let sampleMarkdownContent = """
    # Test Document
    
    This is a sample document for testing the markdown parsing and TTS functionality.
    
    ## Features
    
    - **Bold text** formatting
    - *Italic text* formatting  
    - `Inline code` formatting
    - [Link text](https://example.com)
    
    ### Code Example
    
    ```swift
    struct ContentView: View {
        var body: some View {
            Text("Hello, World!")
        }
    }
    ```
    
    > This is a blockquote to test quote parsing.
    
    ## Lists
    
    1. First ordered item
    2. Second ordered item
    3. Third ordered item
    
    And unordered:
    
    - First bullet point
    - Second bullet point
    - Third bullet point
    
    ### Images and Links
    
    Here's an image: ![Test Image](test.jpg)
    
    And a [test link](https://apple.com).
    
    ## Conclusion
    
    This document tests various markdown features including:
    
    - Headers (multiple levels)
    - **Text formatting**
    - Code blocks (skippable)
    - Lists (ordered and unordered)
    - Blockquotes
    - Links and images
    """
    
    static let complexMarkdownContent = """
    # Complex Document Structure
    
    This document contains more complex markdown structures for comprehensive testing.
    
    ## Nested Elements
    
    Here's a list with nested elements:
    
    1. First item with **bold text**
       - Nested bullet with *italic*
       - Another nested item with `code`
    2. Second item with [a link](https://example.com)
    3. Third item with multiple formats: **bold** and *italic* and `code`
    
    ### Mixed Content
    
    A paragraph with **bold**, *italic*, `code`, [links](https://test.com), and ![images](test.png).
    
    ```python
    def complex_function():
        # This is a longer code block
        # to test multi-line handling
        for i in range(10):
            if i % 2 == 0:
                print(f"Even: {i}")
            else:
                print(f"Odd: {i}")
    ```
    
    > A blockquote that contains **bold text**, *italic text*, and `inline code`.
    > 
    > Multiple paragraph blockquote with a [link](https://example.com).
    
    #### Deeply Nested Header
    
    ##### Very Deep Header
    
    ###### Maximum Depth Header
    
    ## Edge Cases
    
    Empty lines:
    
    
    
    Multiple spaces and    tabs.
    
    **Unclosed bold text
    
    *Unclosed italic
    
    `Unclosed code
    
    [Broken link](
    
    ![Broken image](
    
    ## Final Section
    
    This is the final section to test document completion.
    """
    
    // MARK: - Expected TTS Results
    
    static let expectedTTSTransformations = [
        ("# Header", "Heading level 1: Header. "),
        ("## Subheader", "Heading level 2: Subheader. "),
        ("**bold**", "bold"),
        ("*italic*", "italic"),
        ("`code`", "code"),
        ("[link](url)", "link"),
        ("![alt](img.jpg)", "Image: alt"),
        ("- item", "• item. "),
        ("1. item", "item. "),
        ("> quote", "Quote: quote. End quote. "),
        ("~~strike~~", "strike")
    ]
    
    // MARK: - Test Data Factory
    
    static func createTestRepository(in context: NSManagedObjectContext, 
                                   name: String = "Test Repository") -> GitRepository {
        let repository = GitRepository(context: context)
        repository.id = UUID()
        repository.name = name
        repository.remoteURL = "https://github.com/test/\(name.lowercased().replacingOccurrences(of: " ", with: "-"))"
        repository.localPath = "/test/\(name.lowercased().replacingOccurrences(of: " ", with: "-"))"
        repository.defaultBranch = "main"
        repository.syncEnabled = true
        repository.lastSyncDate = Date()
        
        return repository
    }
    
    static func createTestMarkdownFile(in context: NSManagedObjectContext,
                                     repository: GitRepository,
                                     title: String = "Test File",
                                     content: String? = nil) -> MarkdownFile {
        let file = MarkdownFile(context: context)
        file.id = UUID()
        file.title = title
        file.filePath = "/test/\(repository.name ?? "repo")/\(title.lowercased().replacingOccurrences(of: " ", with: "-")).md"
        file.gitFilePath = "\(title.lowercased().replacingOccurrences(of: " ", with: "-")).md"
        file.repositoryId = repository.id
        file.lastModified = Date()
        file.fileSize = Int64(content?.count ?? 1000)
        file.syncStatusEnum = .synced
        file.hasLocalChanges = false
        file.repository = repository
        
        // If content provided, parse it immediately
        if let markdownContent = content {
            let parser = MarkdownParser()
            parser.processAndSaveMarkdownFile(file, content: markdownContent, in: context)
        }
        
        return file
    }
    
    static func createTestReadingProgress(in context: NSManagedObjectContext,
                                        for file: MarkdownFile,
                                        position: Int32 = 0,
                                        duration: TimeInterval = 0,
                                        completed: Bool = false) -> ReadingProgress {
        let progress = ReadingProgress(context: context)
        progress.fileId = file.id!
        progress.currentPosition = position
        progress.lastReadDate = Date()
        progress.totalDuration = duration
        progress.isCompleted = completed
        progress.markdownFile = file
        
        return progress
    }
    
    static func createTestBookmark(in context: NSManagedObjectContext,
                                 for progress: ReadingProgress,
                                 position: Int32,
                                 title: String? = nil) -> Bookmark {
        let bookmark = Bookmark(context: context)
        bookmark.id = UUID()
        bookmark.position = position
        bookmark.title = title
        bookmark.timestamp = Date()
        bookmark.readingProgress = progress
        
        return bookmark
    }
}

// MARK: - Test Assertions

extension XCTestCase {
    
    func assertMarkdownTransformation(_ input: String, 
                                    expectedOutput: String,
                                    parser: MarkdownParser,
                                    file: StaticString = #file,
                                    line: UInt = #line) {
        let result = parser.parseMarkdownForTTS(input)
        XCTAssertTrue(result.plainText.contains(expectedOutput), 
                     "Expected '\(expectedOutput)' in '\(result.plainText)'",
                     file: file, line: line)
    }
    
    func assertSectionCount(_ input: String,
                          expectedCount: Int,
                          parser: MarkdownParser,
                          file: StaticString = #file,
                          line: UInt = #line) {
        let result = parser.parseMarkdownForTTS(input)
        XCTAssertEqual(result.sections.count, expectedCount,
                      "Expected \(expectedCount) sections, got \(result.sections.count)",
                      file: file, line: line)
    }
    
    func assertSectionType(_ input: String,
                          sectionIndex: Int,
                          expectedType: ContentSectionType,
                          parser: MarkdownParser,
                          file: StaticString = #file,
                          line: UInt = #line) {
        let result = parser.parseMarkdownForTTS(input)
        guard sectionIndex < result.sections.count else {
            XCTFail("Section index \(sectionIndex) out of bounds", file: file, line: line)
            return
        }
        
        let section = result.sections[sectionIndex]
        XCTAssertEqual(section.type, expectedType,
                      "Expected section type \(expectedType), got \(section.type)",
                      file: file, line: line)
    }
    
    func assertNoMarkdownSyntax(_ text: String,
                               file: StaticString = #file,
                               line: UInt = #line) {
        let markdownPatterns = ["**", "*", "`", "[", "](", "![", "#", ">", "~~"]
        
        for pattern in markdownPatterns {
            XCTAssertFalse(text.contains(pattern),
                          "Text should not contain markdown syntax '\(pattern)'",
                          file: file, line: line)
        }
    }
}