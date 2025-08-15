//
//  IntegrationTests.swift
//  MD TalkManTests
//
//  Created by Claude on 8/14/25.
//

import XCTest
import CoreData
@testable import MD_TalkMan

final class IntegrationTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var parser: MarkdownParser!
    
    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        parser = MarkdownParser()
    }
    
    override func tearDownWithError() throws {
        persistenceController = nil
        context = nil
        parser = nil
    }
    
    // MARK: - End-to-End Markdown Processing Tests
    
    func testCompleteMarkdownProcessingFlow() throws {
        // Create test data
        let repository = GitRepository(context: context)
        repository.id = UUID()
        repository.name = "Integration Test Repo"
        repository.remoteURL = "https://github.com/test/integration"
        repository.localPath = "/test/integration"
        repository.defaultBranch = "main"
        repository.syncEnabled = true
        
        let markdownFile = MarkdownFile(context: context)
        markdownFile.id = UUID()
        markdownFile.title = "Integration Test Document"
        markdownFile.filePath = "/test/integration/document.md"
        markdownFile.gitFilePath = "document.md"
        markdownFile.repositoryId = repository.id
        markdownFile.lastModified = Date()
        markdownFile.fileSize = 2000
        markdownFile.syncStatusEnum = .synced
        markdownFile.hasLocalChanges = false
        markdownFile.repository = repository
        
        // Sample markdown content
        let markdownContent = """
        # Integration Test Document
        
        This is a comprehensive test document to verify the complete markdown processing pipeline.
        
        ## Features Tested
        
        The following features are being tested:
        
        - Markdown parsing accuracy
        - Core Data integration
        - Section creation and management
        - TTS text preparation
        
        ### Code Example
        
        Here's a code block to test skippable content:
        
        ```swift
        class TestClass {
            func testMethod() {
                print("This should be skippable")
            }
        }
        ```
        
        > This is a blockquote to test quote parsing functionality.
        
        ## Conclusion
        
        1. All sections should be properly parsed
        2. Content should be TTS-ready
        3. Relationships should be correctly established
        
        **Bold text** and *italic text* should be cleaned up for speech.
        """
        
        // Process the markdown
        parser.processAndSaveMarkdownFile(markdownFile, content: markdownContent, in: context)
        
        // Verify the processing results
        try context.save()
        
        // Reload the markdown file to get updated relationships
        context.refresh(markdownFile, mergeChanges: true)
        
        // Verify ParsedContent was created
        XCTAssertNotNil(markdownFile.parsedContent)
        
        let parsedContent = markdownFile.parsedContent!
        XCTAssertFalse(parsedContent.plainText!.isEmpty)
        XCTAssertNotNil(parsedContent.lastParsed)
        
        // Verify plain text doesn't contain markdown syntax
        let plainText = parsedContent.plainText!
        XCTAssertFalse(plainText.contains("**"))
        XCTAssertFalse(plainText.contains("*"))
        XCTAssertFalse(plainText.contains("```"))
        XCTAssertFalse(plainText.contains("#"))
        XCTAssertFalse(plainText.contains(">"))
        
        // Verify content sections were created
        guard let sections = parsedContent.contentSection as? Set<ContentSection> else {
            XCTFail("Content sections not created")
            return
        }
        
        XCTAssertGreaterThan(sections.count, 5) // Should have multiple sections
        
        // Verify different section types exist
        let sectionTypes = Set(sections.map { $0.typeEnum })
        XCTAssertTrue(sectionTypes.contains(.header))
        XCTAssertTrue(sectionTypes.contains(.paragraph))
        XCTAssertTrue(sectionTypes.contains(.list))
        XCTAssertTrue(sectionTypes.contains(.codeBlock))
        XCTAssertTrue(sectionTypes.contains(.blockquote))
        
        // Verify skippable sections exist
        let skippableSections = sections.filter { $0.isSkippable }
        XCTAssertGreaterThan(skippableSections.count, 0)
        
        // Verify section indices are sequential
        let sortedSections = sections.sorted { $0.startIndex < $1.startIndex }
        var expectedIndex: Int32 = 0
        
        for section in sortedSections {
            XCTAssertEqual(section.startIndex, expectedIndex)
            XCTAssertGreaterThan(section.endIndex, section.startIndex)
            expectedIndex = section.endIndex
        }
        
        // Verify total length matches plain text
        XCTAssertEqual(expectedIndex, Int32(plainText.count))
    }
    
    // MARK: - TTS Integration Tests
    
    func testTTSIntegrationWithParsedContent() throws {
        // Create and process a markdown file
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        
        let simpleMarkdown = """
        # Simple Test
        
        This is a simple test paragraph.
        
        ```javascript
        console.log("test");
        ```
        
        Final paragraph.
        """
        
        parser.processAndSaveMarkdownFile(markdownFile, content: simpleMarkdown, in: context)
        try context.save()
        
        // Create TTS manager and load content
        let ttsManager = TTSManager()
        ttsManager.loadMarkdownFile(markdownFile, context: context)
        
        // Verify TTS manager loaded the content correctly
        XCTAssertNotNil(ttsManager.getCurrentSectionInfo())
        
        // Test section navigation
        let initialSection = ttsManager.getCurrentSectionInfo()
        XCTAssertEqual(initialSection?.type, .header)
        
        // Navigate through sections
        ttsManager.skipToNextSection()
        let secondSection = ttsManager.getCurrentSectionInfo()
        XCTAssertEqual(secondSection?.type, .paragraph)
        
        ttsManager.skipToNextSection()
        let thirdSection = ttsManager.getCurrentSectionInfo()
        XCTAssertEqual(thirdSection?.type, .codeBlock)
        XCTAssertTrue(thirdSection?.isSkippable ?? false)
    }
    
    // MARK: - Reading Progress Integration Tests
    
    func testReadingProgressIntegration() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        
        // Create initial reading progress
        let progress = ReadingProgress(context: context)
        progress.fileId = markdownFile.id!
        progress.currentPosition = 0
        progress.lastReadDate = Date()
        progress.totalDuration = 0
        progress.isCompleted = false
        progress.markdownFile = markdownFile
        
        try context.save()
        
        // Process some content
        let markdown = "# Test\n\nSome content here."
        parser.processAndSaveMarkdownFile(markdownFile, content: markdown, in: context)
        
        // Update progress
        progress.currentPosition = 10
        progress.totalDuration = 30
        
        try context.save()
        
        // Verify relationships
        XCTAssertEqual(markdownFile.readingProgress, progress)
        XCTAssertEqual(progress.markdownFile, markdownFile)
        XCTAssertEqual(progress.currentPosition, 10)
        XCTAssertEqual(progress.totalDuration, 30, accuracy: 0.01)
    }
    
    // MARK: - Bookmark Integration Tests
    
    func testBookmarkIntegration() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        
        // Create reading progress
        let progress = ReadingProgress(context: context)
        progress.fileId = markdownFile.id!
        progress.currentPosition = 0
        progress.lastReadDate = Date()
        progress.totalDuration = 0
        progress.isCompleted = false
        progress.markdownFile = markdownFile
        
        // Create bookmarks
        let bookmark1 = Bookmark(context: context)
        bookmark1.id = UUID()
        bookmark1.position = 50
        bookmark1.title = "Important point"
        bookmark1.timestamp = Date()
        bookmark1.readingProgress = progress
        
        let bookmark2 = Bookmark(context: context)
        bookmark2.id = UUID()
        bookmark2.position = 150
        bookmark2.title = "Another bookmark"
        bookmark2.timestamp = Date()
        bookmark2.readingProgress = progress
        
        try context.save()
        
        // Verify relationships
        guard let bookmarks = progress.bookmarks as? Set<Bookmark> else {
            XCTFail("Bookmarks not properly related")
            return
        }
        
        XCTAssertEqual(bookmarks.count, 2)
        
        // Verify bookmark properties
        let sortedBookmarks = bookmarks.sorted { $0.position < $1.position }
        XCTAssertEqual(sortedBookmarks[0].position, 50)
        XCTAssertEqual(sortedBookmarks[0].title, "Important point")
        XCTAssertEqual(sortedBookmarks[1].position, 150)
        XCTAssertEqual(sortedBookmarks[1].title, "Another bookmark")
    }
    
    // MARK: - Error Handling Tests
    
    func testMalformedMarkdownHandling() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        
        // Test with various malformed markdown
        let malformedMarkdown = """
        # Unclosed header #
        
        **Unclosed bold
        
        ```
        Unclosed code block
        
        > Unclosed quote
        
        [Broken link](
        
        ![Broken image](
        """
        
        // Should not crash or throw
        parser.processAndSaveMarkdownFile(markdownFile, content: malformedMarkdown, in: context)
        
        try context.save()
        
        // Verify content was still processed
        XCTAssertNotNil(markdownFile.parsedContent)
        XCTAssertFalse(markdownFile.parsedContent!.plainText!.isEmpty)
    }
    
    // MARK: - Performance Integration Tests
    
    func testLargeDocumentIntegration() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        
        // Create a large document
        var largeMarkdown = "# Large Document Test\n\n"
        
        for i in 1...100 {
            largeMarkdown += """
            ## Section \(i)
            
            This is section \(i) with some content to test performance.
            
            - Item 1 for section \(i)
            - Item 2 for section \(i)
            - Item 3 for section \(i)
            
            ```swift
            // Code for section \(i)
            func section\(i)Function() {
                print("Section \(i)")
            }
            ```
            
            """
        }
        
        // Test performance of processing
        measure {
            parser.processAndSaveMarkdownFile(markdownFile, content: largeMarkdown, in: context)
        }
        
        // Verify results
        XCTAssertNotNil(markdownFile.parsedContent)
        
        if let sections = markdownFile.parsedContent?.contentSection as? Set<ContentSection> {
            XCTAssertGreaterThan(sections.count, 300) // Should have many sections
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestRepository() -> GitRepository {
        let repository = GitRepository(context: context)
        repository.id = UUID()
        repository.name = "Test Repository"
        repository.remoteURL = "https://github.com/test/repo"
        repository.localPath = "/test/repo"
        repository.defaultBranch = "main"
        repository.syncEnabled = true
        
        return repository
    }
    
    private func createTestMarkdownFile(repository: GitRepository) -> MarkdownFile {
        let markdownFile = MarkdownFile(context: context)
        markdownFile.id = UUID()
        markdownFile.title = "Test File"
        markdownFile.filePath = "/test/repo/test.md"
        markdownFile.gitFilePath = "test.md"
        markdownFile.repositoryId = repository.id
        markdownFile.lastModified = Date()
        markdownFile.fileSize = 1000
        markdownFile.syncStatusEnum = .synced
        markdownFile.hasLocalChanges = false
        markdownFile.repository = repository
        
        return markdownFile
    }
}