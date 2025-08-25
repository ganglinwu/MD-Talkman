//
//  PerformanceBenchmarkTests.swift
//  MD TalkManTests
//
//  Created by Claude on 8/25/25.
//  Performance benchmarking tests for Phase 3 preparation
//

import XCTest
import CoreData
@testable import MD_TalkMan

final class PerformanceBenchmarkTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var parser: MarkdownParser!
    var ttsManager: TTSManager!
    var textWindowManager: TextWindowManager!
    
    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        parser = MarkdownParser()
        ttsManager = TTSManager()
        textWindowManager = TextWindowManager()
    }
    
    override func tearDownWithError() throws {
        ttsManager = nil
        textWindowManager = nil
        parser = nil
        persistenceController = nil
        context = nil
    }
    
    // MARK: - Large Document Processing Performance
    
    func testMarkdownParsingPerformanceLargeDocument() throws {
        let largeMarkdown = createLargeMarkdownDocument(sections: 500, paragraphsPerSection: 10)
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        
        measure {
            parser.processAndSaveMarkdownFile(markdownFile, content: largeMarkdown, in: context)
        }
        
        // Verify the processing completed successfully
        XCTAssertNotNil(markdownFile.parsedContent)
        if let parsedContent = markdownFile.parsedContent {
            XCTAssertFalse(parsedContent.plainText?.isEmpty ?? true)
        }
    }
    
    func testMarkdownParsingPerformanceVeryLargeDocument() throws {
        let veryLargeMarkdown = createLargeMarkdownDocument(sections: 1000, paragraphsPerSection: 20)
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        
        // Test with very large document (should complete within reasonable time)
        measure {
            parser.processAndSaveMarkdownFile(markdownFile, content: veryLargeMarkdown, in: context)
        }
        
        XCTAssertNotNil(markdownFile.parsedContent)
    }
    
    func testMarkdownParsingMemoryUsage() throws {
        // Test memory usage with multiple large documents
        let documents = 10
        let markdownContent = createLargeMarkdownDocument(sections: 100, paragraphsPerSection: 5)
        
        var markdownFiles: [MarkdownFile] = []
        let repository = createTestRepository()
        
        measure {
            for i in 0..<documents {
                let markdownFile = createTestMarkdownFile(repository: repository, title: "Document \(i)")
                parser.processAndSaveMarkdownFile(markdownFile, content: markdownContent, in: context)
                markdownFiles.append(markdownFile)
            }
        }
        
        // Verify all documents were processed
        XCTAssertEqual(markdownFiles.count, documents)
        
        for markdownFile in markdownFiles {
            XCTAssertNotNil(markdownFile.parsedContent)
        }
    }
    
    // MARK: - TTS Performance Tests
    
    func testTTSLoadingPerformanceLargeContent() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        
        // Create large parsed content
        let largeContent = String(repeating: "This is a test sentence for TTS performance testing. ", count: 10000)
        let parsedContent = ParsedContent(context: context)
        parsedContent.fileId = markdownFile.id!
        parsedContent.plainText = largeContent
        parsedContent.lastParsed = Date()
        parsedContent.markdownFiles = markdownFile
        
        // Create many sections
        for i in 0..<1000 {
            let section = ContentSection(context: context)
            section.startIndex = Int32(i * 100)
            section.endIndex = Int32((i + 1) * 100)
            section.typeEnum = i % 2 == 0 ? .paragraph : .header
            section.level = Int16(i % 3)
            section.parsedContent = parsedContent
        }
        
        try context.save()
        
        measure {
            ttsManager.loadMarkdownFile(markdownFile, context: context)
        }
        
        XCTAssertNotNil(ttsManager.getCurrentSectionInfo())
    }
    
    func testTTSSectionNavigationPerformance() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        let parsedContent = createLargeParsedContent(for: markdownFile, sections: 2000)
        
        ttsManager.loadMarkdownFile(markdownFile, context: context)
        
        measure {
            // Test rapid section navigation
            for _ in 0..<100 {
                ttsManager.skipToNextSection()
                if ttsManager.currentSectionIndex >= 1900 {
                    // Reset to avoid going beyond bounds
                    ttsManager.currentSectionIndex = 0
                    ttsManager.currentPosition = 0
                }
            }
        }
        
        XCTAssertGreaterThanOrEqual(ttsManager.currentSectionIndex, 0)
    }
    
    func testTTSPositionTrackingPerformance() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        _ = createLargeParsedContent(for: markdownFile, sections: 1000)
        
        ttsManager.loadMarkdownFile(markdownFile, context: context)
        
        measure {
            // Test rapid position changes
            for i in 0..<1000 {
                ttsManager.currentPosition = i * 100
                _ = ttsManager.getCurrentSectionInfo()
            }
        }
        
        XCTAssertGreaterThan(ttsManager.currentPosition, 0)
    }
    
    // MARK: - Text Window Manager Performance Tests
    
    func testTextWindowPerformanceLargeContent() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        let largeText = String(repeating: "This is a test sentence for text window performance testing. ", count: 1000)
        
        // Create parsed content with sections
        let parsedContent = ParsedContent(context: context)
        parsedContent.fileId = markdownFile.id!
        parsedContent.plainText = largeText
        parsedContent.lastParsed = Date()
        parsedContent.markdownFiles = markdownFile
        
        // Create sections
        for i in 0..<100 {
            let section = ContentSection(context: context)
            section.startIndex = Int32(i * 100)
            section.endIndex = Int32((i + 1) * 100)
            section.typeEnum = .paragraph
            section.parsedContent = parsedContent
        }
        
        try context.save()
        
        let sections = parsedContent.contentSection?.allObjects as? [ContentSection] ?? []
        
        measure {
            textWindowManager.loadContent(sections: sections, plainText: largeText)
        }
        
        XCTAssertFalse(textWindowManager.displayWindow.isEmpty)
    }
    
    func testTextWindowPositionUpdatePerformance() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        let testText = String(repeating: "Performance test sentence. ", count: 1000)
        
        let parsedContent = createLargeParsedContent(for: markdownFile, sections: 100)
        parsedContent.plainText = testText
        try context.save()
        
        let sections = parsedContent.contentSection?.allObjects as? [ContentSection] ?? []
        textWindowManager.loadContent(sections: sections, plainText: testText)
        
        measure {
            // Test rapid position updates
            for i in 0..<100 {
                textWindowManager.updateWindow(for: i * 10)
            }
        }
        
        XCTAssertFalse(textWindowManager.displayWindow.isEmpty)
    }
    
    func testTextWindowSearchPerformance() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        let largeText = createLargeSearchableText()
        
        let parsedContent = ParsedContent(context: context)
        parsedContent.fileId = markdownFile.id!
        parsedContent.plainText = largeText
        parsedContent.lastParsed = Date()
        parsedContent.markdownFiles = markdownFile
        
        let section = ContentSection(context: context)
        section.startIndex = 0
        section.endIndex = Int32(largeText.count)
        section.typeEnum = .paragraph
        section.parsedContent = parsedContent
        
        try context.save()
        
        textWindowManager.loadContent(sections: [section], plainText: largeText)
        
        measure {
            let results = textWindowManager.searchInWindow("performance")
            XCTAssertTrue(results.count >= 0)
        }
    }
    
    // MARK: - Core Data Performance Tests
    
    func testCoreDataSavePerformanceWithManyEntities() throws {
        let repository = createTestRepository()
        
        measure {
            // Create many markdown files and parsed content
            for i in 0..<100 {
                let markdownFile = createTestMarkdownFile(repository: repository, title: "File \(i)")
                
                let parsedContent = ParsedContent(context: context)
                parsedContent.fileId = markdownFile.id!
                parsedContent.plainText = "Content for file \(i)"
                parsedContent.lastParsed = Date()
                parsedContent.markdownFiles = markdownFile
                
                // Add sections
                for j in 0..<10 {
                    let section = ContentSection(context: context)
                    section.startIndex = Int32(j * 50)
                    section.endIndex = Int32((j + 1) * 50)
                    section.typeEnum = .paragraph
                    section.level = 0
                    section.parsedContent = parsedContent
                }
            }
            
            do {
                try context.save()
            } catch {
                XCTFail("Failed to save context: \(error)")
            }
        }
    }
    
    func testCoreDataFetchPerformanceWithManyEntities() throws {
        // First create many entities
        let repository = createTestRepository()
        
        for i in 0..<1000 {
            let markdownFile = createTestMarkdownFile(repository: repository, title: "File \(i)")
            let parsedContent = ParsedContent(context: context)
            parsedContent.fileId = markdownFile.id!
            parsedContent.plainText = "Content for file \(i)"
            parsedContent.lastParsed = Date()
            parsedContent.markdownFiles = markdownFile
        }
        
        try context.save()
        
        // Test fetch performance
        measure {
            let fetchRequest: NSFetchRequest<MarkdownFile> = MarkdownFile.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "repository == %@", repository)
            
            do {
                let files = try context.fetch(fetchRequest)
                XCTAssertEqual(files.count, 1000)
            } catch {
                XCTFail("Failed to fetch files: \(error)")
            }
        }
    }
    
    // MARK: - Memory Pressure Tests
    
    func testMemoryPressureHandling() throws {
        // Test behavior under memory pressure by creating many large objects
        var repositories: [GitRepository] = []
        
        measure {
            for i in 0..<50 {
                let repository = createTestRepository()
                repository.name = "Repository \(i)"
                
                for j in 0..<20 {
                    let markdownFile = createTestMarkdownFile(repository: repository, title: "File \(j)")
                    let parsedContent = createLargeParsedContent(for: markdownFile, sections: 100)
                }
                
                repositories.append(repository)
            }
        }
        
        XCTAssertEqual(repositories.count, 50)
        
        // Test cleanup
        repositories.removeAll()
    }
    
    func testConcurrentOperationsPerformance() throws {
        let repository = createTestRepository()
        let expectation = XCTestExpectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = 10
        
        measure {
            for i in 0..<10 {
                DispatchQueue.global().async {
                    let markdownFile = self.createTestMarkdownFile(repository: repository, title: "Concurrent File \(i)")
                    let content = "Concurrent content for file \(i)"
                    
                    self.context.perform {
                        self.parser.processAndSaveMarkdownFile(markdownFile, content: content, in: self.context)
                        expectation.fulfill()
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Integration Performance Tests
    
    func testEndToEndProcessingPerformance() throws {
        let largeMarkdown = createLargeMarkdownDocument(sections: 200, paragraphsPerSection: 5)
        
        measure {
            let repository = createTestRepository()
            let markdownFile = createTestMarkdownFile(repository: repository)
            
            // Parse markdown
            parser.processAndSaveMarkdownFile(markdownFile, content: largeMarkdown, in: context)
            
            // Load into TTS
            ttsManager.loadMarkdownFile(markdownFile, context: context)
            
            // Load into text window
            if let parsedContent = markdownFile.parsedContent,
               let plainText = parsedContent.plainText {
                let sections = parsedContent.contentSection?.allObjects as? [ContentSection] ?? []
                textWindowManager.loadContent(sections: sections, plainText: plainText)
            }
        }
        
        XCTAssertNotNil(ttsManager.getCurrentSectionInfo())
        XCTAssertFalse(textWindowManager.displayWindow.isEmpty)
    }
    
    func testRepeatedLoadUnloadCycles() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        let content = createLargeMarkdownDocument(sections: 100, paragraphsPerSection: 3)
        
        parser.processAndSaveMarkdownFile(markdownFile, content: content, in: context)
        
        measure {
            // Simulate repeated loading and unloading
            for _ in 0..<10 {
                ttsManager.loadMarkdownFile(markdownFile, context: context)
                ttsManager.stop() // Cleanup
                
                if let parsedContent = markdownFile.parsedContent,
                   let plainText = parsedContent.plainText {
                    let sections = parsedContent.contentSection?.allObjects as? [ContentSection] ?? []
                    textWindowManager.loadContent(sections: sections, plainText: plainText)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createLargeMarkdownDocument(sections: Int, paragraphsPerSection: Int) -> String {
        var content = "# Large Document Test\n\n"
        
        for i in 1...sections {
            content += "## Section \(i)\n\n"
            
            for j in 1...paragraphsPerSection {
                content += "This is paragraph \(j) of section \(i). It contains substantial content designed to test the performance of the markdown parsing system. The paragraph includes various types of content that would typically be found in real-world documents, including technical terminology, proper nouns, and complex sentence structures.\n\n"
            }
            
            if i % 10 == 0 {
                content += """
                ```swift
                // Code example for section \(i)
                func performanceTest\(i)() {
                    let data = generateTestData()
                    let result = processData(data)
                    return result
                }
                ```
                
                """
            }
            
            if i % 15 == 0 {
                content += """
                > This is a blockquote in section \(i). It provides additional context and information that complements the main content of the section.
                
                """
            }
            
            if i % 20 == 0 {
                content += """
                - List item 1 for section \(i)
                - List item 2 for section \(i)
                - List item 3 for section \(i)
                
                """
            }
        }
        
        return content
    }
    
    private func createLargeSearchableText() -> String {
        var text = ""
        let searchTerms = ["performance", "testing", "benchmark", "optimization", "speed", "memory", "efficiency"]
        
        for i in 0..<1000 {
            let randomTerm = searchTerms[i % searchTerms.count]
            text += "This is sentence \(i) containing the word \(randomTerm) for search testing purposes. "
        }
        
        return text
    }
    
    private func createTestRepository() -> GitRepository {
        let repository = GitRepository(context: context)
        repository.id = UUID()
        repository.name = "Performance Test Repository"
        repository.remoteURL = "https://github.com/test/performance"
        repository.localPath = "/test/performance"
        repository.defaultBranch = "main"
        repository.syncEnabled = true
        repository.lastSyncDate = Date()
        
        return repository
    }
    
    private func createTestMarkdownFile(repository: GitRepository, title: String = "Performance Test File") -> MarkdownFile {
        let markdownFile = MarkdownFile(context: context)
        markdownFile.id = UUID()
        markdownFile.title = title
        markdownFile.filePath = "/test/performance/\(title.lowercased().replacingOccurrences(of: " ", with: "_")).md"
        markdownFile.gitFilePath = "\(title.lowercased().replacingOccurrences(of: " ", with: "_")).md"
        markdownFile.repositoryId = repository.id
        markdownFile.lastModified = Date()
        markdownFile.fileSize = 10000
        markdownFile.syncStatusEnum = .synced
        markdownFile.hasLocalChanges = false
        markdownFile.repository = repository
        
        return markdownFile
    }
    
    private func createLargeParsedContent(for markdownFile: MarkdownFile, sections: Int) -> ParsedContent {
        let parsedContent = ParsedContent(context: context)
        parsedContent.fileId = markdownFile.id!
        
        var contentText = ""
        for i in 0..<sections {
            contentText += "Section \(i) content with substantial text for performance testing. "
        }
        
        parsedContent.plainText = contentText
        parsedContent.lastParsed = Date()
        parsedContent.markdownFiles = markdownFile
        
        // Create sections
        let sectionLength = contentText.count / sections
        for i in 0..<sections {
            let section = ContentSection(context: context)
            section.startIndex = Int32(i * sectionLength)
            section.endIndex = Int32((i + 1) * sectionLength)
            section.typeEnum = i % 3 == 0 ? .header : .paragraph
            section.level = Int16(i % 4)
            section.isSkippable = (i % 10 == 0)
            section.parsedContent = parsedContent
        }
        
        return parsedContent
    }
}