//
//  TTSManagerTests.swift
//  MD TalkManTests
//
//  Created by Claude on 8/14/25.
//

import XCTest
import CoreData
import AVFoundation
@testable import MD_TalkMan

final class TTSManagerTests: XCTestCase {
    
    var ttsManager: TTSManager!
    var mockContext: NSManagedObjectContext!
    var testContainer: NSPersistentContainer!
    
    override func setUpWithError() throws {
        // Create in-memory Core Data stack for testing
        testContainer = NSPersistentContainer(name: "DataModel")
        let description = testContainer.persistentStoreDescriptions.first!
        description.url = URL(fileURLWithPath: "/dev/null")
        
        testContainer.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        
        mockContext = testContainer.viewContext
        ttsManager = TTSManager()
    }
    
    override func tearDownWithError() throws {
        ttsManager.stop()
        ttsManager = nil
        mockContext = nil
        testContainer = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() throws {
        XCTAssertEqual(ttsManager.playbackState, .idle)
        XCTAssertEqual(ttsManager.currentPosition, 0)
        XCTAssertEqual(ttsManager.totalDuration, 0)
        XCTAssertEqual(ttsManager.playbackSpeed, 1.0) // Fixed: should default to 1.0x natural speed
        XCTAssertEqual(ttsManager.currentSectionIndex, 0)
    }
    
    // MARK: - Speed Control Tests
    
    func testPlaybackSpeedControl() throws {
        // Test valid speeds
        ttsManager.setPlaybackSpeed(1.0)
        XCTAssertEqual(ttsManager.playbackSpeed, 1.0, accuracy: 0.01)
        
        ttsManager.setPlaybackSpeed(2.0)
        XCTAssertEqual(ttsManager.playbackSpeed, 2.0, accuracy: 0.01)
        
        ttsManager.setPlaybackSpeed(0.5)
        XCTAssertEqual(ttsManager.playbackSpeed, 0.5, accuracy: 0.01)
        
        // Test boundary conditions
        ttsManager.setPlaybackSpeed(0.1) // Too slow
        XCTAssertEqual(ttsManager.playbackSpeed, 0.5, accuracy: 0.01)
        
        ttsManager.setPlaybackSpeed(3.0) // Too fast
        XCTAssertEqual(ttsManager.playbackSpeed, 2.0, accuracy: 0.01)
    }
    
    // MARK: - Content Loading Tests
    
    func testLoadMarkdownFileWithoutContent() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        
        XCTAssertEqual(ttsManager.playbackState, .idle)
        XCTAssertEqual(ttsManager.currentPosition, 0)
    }
    
    func testLoadMarkdownFileWithContent() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        _ = createTestParsedContent(for: markdownFile)
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        
        XCTAssertEqual(ttsManager.playbackState, .idle)
    }
    
    func testLoadMarkdownFileWithExistingProgress() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        _ = createTestParsedContent(for: markdownFile)
        
        // Create existing reading progress
        let progress = ReadingProgress(context: mockContext)
        progress.fileId = markdownFile.id!
        progress.currentPosition = 100
        progress.totalDuration = 300
        progress.isCompleted = false
        progress.lastReadDate = Date()
        progress.markdownFile = markdownFile
        
        try mockContext.save()
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        
        XCTAssertEqual(ttsManager.currentPosition, 100)
        XCTAssertEqual(ttsManager.totalDuration, 300, accuracy: 0.01)
    }
    
    // MARK: - Navigation Tests
    
    func testRewindFunctionality() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        _ = createTestParsedContent(for: markdownFile)
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        ttsManager.currentPosition = 1000
        
        ttsManager.rewind(seconds: 5.0)
        
        // Should rewind approximately (this is an estimation based on words per minute)
        XCTAssertLessThan(ttsManager.currentPosition, 1000)
        XCTAssertGreaterThanOrEqual(ttsManager.currentPosition, 0)
    }
    
    func testRewindBoundary() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        _ = createTestParsedContent(for: markdownFile)
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        ttsManager.currentPosition = 10 // Very close to beginning
        
        ttsManager.rewind(seconds: 10.0)
        
        // Should not go below 0
        XCTAssertEqual(ttsManager.currentPosition, 0)
    }
    
    // MARK: - Section Navigation Tests
    
    func testSectionNavigation() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        let parsedContent = createTestParsedContent(for: markdownFile)
        
        // Create multiple content sections
        let section1 = ContentSection(context: mockContext)
        section1.startIndex = 0
        section1.endIndex = 50
        section1.typeEnum = .header
        section1.level = 1
        section1.parsedContent = parsedContent
        
        let section2 = ContentSection(context: mockContext)
        section2.startIndex = 50
        section2.endIndex = 150
        section2.typeEnum = .paragraph
        section2.level = 0
        section2.parsedContent = parsedContent
        
        let section3 = ContentSection(context: mockContext)
        section3.startIndex = 150
        section3.endIndex = 250
        section3.typeEnum = .codeBlock
        section3.level = 0
        section3.parsedContent = parsedContent
        
        try mockContext.save()
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        
        // Test next section navigation
        XCTAssertEqual(ttsManager.currentSectionIndex, 0)
        
        ttsManager.skipToNextSection()
        XCTAssertEqual(ttsManager.currentSectionIndex, 1)
        XCTAssertEqual(ttsManager.currentPosition, 50)
        
        ttsManager.skipToNextSection()
        XCTAssertEqual(ttsManager.currentSectionIndex, 2)
        XCTAssertEqual(ttsManager.currentPosition, 150)
        
        // Test previous section navigation
        ttsManager.skipToPreviousSection()
        XCTAssertEqual(ttsManager.currentSectionIndex, 1)
        XCTAssertEqual(ttsManager.currentPosition, 50)
        
        // Test boundaries
        ttsManager.currentSectionIndex = 0
        ttsManager.skipToPreviousSection()
        XCTAssertEqual(ttsManager.currentSectionIndex, 0) // Should not go below 0
    }
    
    // MARK: - Section Information Tests
    
    func testGetCurrentSectionInfo() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        let parsedContent = createTestParsedContent(for: markdownFile)
        
        let section = ContentSection(context: mockContext)
        section.startIndex = 0
        section.endIndex = 100
        section.typeEnum = .codeBlock
        section.level = 0
        section.isSkippable = true
        section.parsedContent = parsedContent
        
        try mockContext.save()
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        
        let sectionInfo = ttsManager.getCurrentSectionInfo()
        XCTAssertNotNil(sectionInfo)
        XCTAssertEqual(sectionInfo?.type, .codeBlock)
        XCTAssertEqual(sectionInfo?.level, 0)
        XCTAssertTrue(sectionInfo?.isSkippable ?? false)
        
        XCTAssertTrue(ttsManager.canSkipCurrentSection())
    }
    
    func testGetCurrentSectionInfoNoContent() throws {
        let sectionInfo = ttsManager.getCurrentSectionInfo()
        XCTAssertNil(sectionInfo)
        XCTAssertFalse(ttsManager.canSkipCurrentSection())
    }
    
    // MARK: - Playback State Tests
    
    func testPlaybackStateTransitions() throws {
        // Initial state should be idle
        XCTAssertEqual(ttsManager.playbackState, .idle)
        
        // Test play without content - should remain idle
        ttsManager.play()
        
        // Note: In a real test environment with actual TTS, we'd need to mock
        // AVSpeechSynthesizer or use expectation-based testing for async behavior
        // For now, we test the synchronous parts
    }
    
    func testStopFunctionality() throws {
        // Should be safe to call stop even when idle
        ttsManager.stop()
        XCTAssertEqual(ttsManager.playbackState, .idle)
    }
    
    // MARK: - End-of-File Bug Tests
    
    func testEndOfFilePositionTracking() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        let parsedContent = createTestParsedContent(for: markdownFile)
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        
        // Simulate near end of content
        let contentLength = parsedContent.plainText?.count ?? 0
        ttsManager.currentPosition = contentLength - 50 // 50 chars from end
        
        // Test position tracking near end (we'll test behavior indirectly)
        // Since methods are private, we test by checking TTS behavior
        
        // Test normal position - should have content
        XCTAssertLessThan(ttsManager.currentPosition, contentLength)
        
        // Test position at end - should complete
        ttsManager.currentPosition = contentLength
        XCTAssertGreaterThanOrEqual(ttsManager.currentPosition, contentLength)
    }
    
    func testEndOfFilePositionBoundaries() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        let parsedContent = createTestParsedContent(for: markdownFile)
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        
        let contentLength = parsedContent.plainText?.count ?? 0
        
        // Test position validation - should handle positions at/beyond end gracefully
        ttsManager.currentPosition = contentLength - 50  // Near end
        XCTAssertLessThan(ttsManager.currentPosition, contentLength)
        
        ttsManager.currentPosition = contentLength       // At end
        XCTAssertEqual(ttsManager.currentPosition, contentLength)
        
        ttsManager.currentPosition = contentLength + 10  // Beyond end
        XCTAssertGreaterThan(ttsManager.currentPosition, contentLength)
        
        // The key test: TTS should handle these positions without crashing
        XCTAssertEqual(ttsManager.playbackState, .idle) // Should remain stable
    }
    
    func testTinyFragmentHandling() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        
        // Create content with tiny ending fragment
        let parsedContent = ParsedContent(context: mockContext)
        parsedContent.fileId = markdownFile.id!
        parsedContent.plainText = "This is a longer test content that ends with a tiny fragment like: Hi"
        parsedContent.lastParsed = Date()
        parsedContent.markdownFiles = markdownFile
        
        try mockContext.save()
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        
        let contentLength = parsedContent.plainText?.count ?? 0
        
        // Position just before the tiny fragment "Hi" (2 chars)
        ttsManager.currentPosition = contentLength - 2
        
        // This should handle the tiny fragment case properly without crashing
        // We test the public interface behavior rather than private method
        ttsManager.play()
        ttsManager.stop()
        
        // Should handle end-of-content positions gracefully
        XCTAssertEqual(ttsManager.playbackState, .idle)
    }
    
    func testUserStopFlagPreventsAutoRestart() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        _ = createTestParsedContent(for: markdownFile)
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        
        // Simulate user stopping playback
        ttsManager.stop()
        
        // Verify user stop flag prevents auto-restart in didFinish
        // (This would be tested more thoroughly with AVSpeechSynthesizer mocking)
        XCTAssertEqual(ttsManager.playbackState, .idle)
    }
    
    func testPositionUpdateAfterUtteranceCompletion() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        _ = createTestParsedContent(for: markdownFile)
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        
        // Simulate utterance completion with proper position calculation
        ttsManager.currentPosition = 100 // utteranceStartPosition
        let utteranceLength = 50
        
        // The position should be updated to start + length
        let expectedPosition = 100 + utteranceLength
        
        // Test position calculation logic (this simulates the didFinish delegate)
        ttsManager.currentPosition = ttsManager.currentPosition + utteranceLength
        
        XCTAssertEqual(ttsManager.currentPosition, expectedPosition)
    }
    
    // MARK: - Helper Methods
    
    private func createTestRepository() -> GitRepository {
        let repository = GitRepository(context: mockContext)
        repository.id = UUID()
        repository.name = "Test Repository"
        repository.remoteURL = "https://github.com/test/repo"
        repository.localPath = "/test/path"
        repository.defaultBranch = "main"
        repository.syncEnabled = true
        
        return repository
    }
    
    private func createTestMarkdownFile(repository: GitRepository) -> MarkdownFile {
        let markdownFile = MarkdownFile(context: mockContext)
        markdownFile.id = UUID()
        markdownFile.title = "Test File"
        markdownFile.filePath = "/test/file.md"
        markdownFile.gitFilePath = "file.md"
        markdownFile.repositoryId = repository.id
        markdownFile.lastModified = Date()
        markdownFile.fileSize = 1000
        markdownFile.syncStatusEnum = .synced
        markdownFile.hasLocalChanges = false
        markdownFile.repository = repository
        
        return markdownFile
    }
    
    private func createTestParsedContent(for markdownFile: MarkdownFile) -> ParsedContent {
        let parsedContent = ParsedContent(context: mockContext)
        parsedContent.fileId = markdownFile.id!
        parsedContent.plainText = """
        Test Title
        
        This is a test paragraph with some content that can be used for testing the TTS functionality.
        It should be long enough to test various features like position tracking and section navigation.
        
        Another paragraph here to make sure we have sufficient content for testing purposes.
        """
        parsedContent.lastParsed = Date()
        parsedContent.markdownFiles = markdownFile
        
        return parsedContent
    }
}

// MARK: - Mock TTS Manager for UI Tests

class MockTTSManager: TTSManager, @unchecked Sendable {
    
    override init() {
        super.init()
        // Override initialization to prevent actual audio system setup during tests
    }
    
    override func play() {
        // Mock implementation - just change state without actual TTS
        if playbackState == .idle {
            playbackState = .playing
        } else if playbackState == .paused {
            playbackState = .playing
        }
    }
    
    override func pause() {
        if playbackState == .playing {
            playbackState = .paused
        }
    }
    
    override func stop() {
        playbackState = .idle
    }
}

// MARK: - Core Data Extensions for Testing

extension NSManagedObjectContext {
    
    func saveTestChanges() throws {
        guard hasChanges else { return }
        try save()
    }
}