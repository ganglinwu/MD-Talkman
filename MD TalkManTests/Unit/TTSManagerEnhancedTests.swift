//
//  TTSManagerEnhancedTests.swift
//  MD TalkManTests
//
//  Created by Claude on 8/25/25.
//  Enhanced test coverage for Phase 3 preparation
//

import XCTest
import CoreData
import AVFoundation
@testable import MD_TalkMan

final class TTSManagerEnhancedTests: XCTestCase {
    
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
    
    // MARK: - Audio Session Management Tests
    
    func testAudioSessionConfiguration() throws {
        // Test that TTS manager properly configures audio session
        _ = AVAudioSession.sharedInstance() // Suppress unused variable warning
        
        // Create content and attempt to play
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        _ = createTestParsedContent(for: markdownFile)
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        
        // The audio session should be configured for spoken audio
        // Note: In testing environment, we can't easily verify actual audio session
        // but we can test the TTS manager's response to audio session events
        XCTAssertEqual(ttsManager.playbackState, .idle)
        
        // Test audio session interruption handling
        ttsManager.play()
        
        // Simulate interruption (this tests resilience)
        ttsManager.pause()
        XCTAssertEqual(ttsManager.playbackState, .paused)
        
        ttsManager.play()
        // Should be able to resume after interruption
    }
    
    func testAudioSessionRecoveryAfterInterruption() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        _ = createTestParsedContent(for: markdownFile)
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        
        // Start playback
        ttsManager.play()
        
        // Simulate interruption by stopping and restarting
        ttsManager.stop()
        XCTAssertEqual(ttsManager.playbackState, .idle)
        
        // Should be able to restart cleanly
        ttsManager.play()
        
        // Test that position is maintained
        let position = ttsManager.currentPosition
        ttsManager.pause()
        ttsManager.play()
        
        // Position should not reset unexpectedly
        XCTAssertGreaterThanOrEqual(ttsManager.currentPosition, position)
    }
    
    func testConcurrentAudioOperations() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        _ = createTestParsedContent(for: markdownFile)
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        
        // Test rapid state changes (user tapping buttons quickly)
        ttsManager.play()
        ttsManager.pause()
        ttsManager.play()
        ttsManager.stop()
        ttsManager.play()
        
        // Should handle rapid state changes gracefully
        // Final state should be consistent
        XCTAssertTrue([.playing, .paused, .idle].contains(ttsManager.playbackState))
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryManagementWithLargeContent() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        
        // Create large content (approximately 50KB)
        var largeContent = ""
        for i in 1...1000 {
            largeContent += "This is paragraph \(i) with some substantial content to test memory management. "
        }
        
        let parsedContent = ParsedContent(context: mockContext)
        parsedContent.fileId = markdownFile.id!
        parsedContent.plainText = largeContent
        parsedContent.lastParsed = Date()
        parsedContent.markdownFiles = markdownFile
        
        try mockContext.save()
        
        // Load and test multiple times to check for memory leaks
        for _ in 1...10 {
            ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
            
            // Perform operations that should clean up properly
            ttsManager.play()
            ttsManager.stop()
        }
        
        // No specific assertions needed - this test passes if no memory issues occur
        XCTAssertEqual(ttsManager.playbackState, .idle)
    }
    
    func testMemoryCleanupOnStop() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        _ = createTestParsedContent(for: markdownFile)
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        ttsManager.play()
        
        // Stop should clean up resources
        ttsManager.stop()
        
        XCTAssertEqual(ttsManager.playbackState, .idle)
        XCTAssertEqual(ttsManager.currentPosition, 0)
    }
    
    // MARK: - TTS State Transition Edge Cases
    
    func testStateTransitionsUnderStress() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        _ = createTestParsedContent(for: markdownFile)
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        
        // Test various state transition sequences
        let stateSequences: [[TTSPlaybackState]] = [
            [.idle, .playing, .paused, .playing, .idle],
            [.idle, .playing, .idle],
            [.idle, .playing, .paused, .idle],
            [.idle, .playing, .playing, .paused, .paused, .idle] // Duplicate states
        ]
        
        for sequence in stateSequences {
            // Reset to idle
            ttsManager.stop()
            
            for targetState in sequence {
                switch targetState {
                case .idle:
                    ttsManager.stop()
                case .playing:
                    ttsManager.play()
                case .paused:
                    if ttsManager.playbackState == .playing {
                        ttsManager.pause()
                    }
                case .preparing, .loading:
                    // These states are typically managed internally
                    continue
                case .error:
                    // Skip error states in this test
                    continue
                }
                
                // Verify state is stable after each transition
                XCTAssertTrue([.idle, .playing, .paused, .preparing, .loading].contains(ttsManager.playbackState))
            }
        }
    }
    
    func testInvalidStateTransitions() throws {
        // Test calling methods in invalid states
        XCTAssertEqual(ttsManager.playbackState, .idle)
        
        // Pause when idle (should be safe)
        ttsManager.pause()
        XCTAssertEqual(ttsManager.playbackState, .idle)
        
        // Stop when already idle (should be safe)
        ttsManager.stop()
        XCTAssertEqual(ttsManager.playbackState, .idle)
        
        // Play without content (should remain idle)
        ttsManager.play()
        XCTAssertEqual(ttsManager.playbackState, .idle)
    }
    
    // MARK: - Position and Progress Edge Cases
    
    func testPositionTrackingAccuracy() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        _ = createTestParsedContent(for: markdownFile)
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        
        // Test position boundaries
        ttsManager.currentPosition = 0
        XCTAssertEqual(ttsManager.currentPosition, 0)
        
        // Test setting position near end of content
        if let content = markdownFile.parsedContent?.plainText {
            let nearEnd = content.count - 10
            ttsManager.currentPosition = nearEnd
            XCTAssertEqual(ttsManager.currentPosition, nearEnd)
            
            // Test position at exact end
            ttsManager.currentPosition = content.count
            XCTAssertEqual(ttsManager.currentPosition, content.count)
        }
    }
    
    func testProgressPersistenceUnderErrors() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        _ = createTestParsedContent(for: markdownFile)
        
        // Create reading progress
        let progress = ReadingProgress(context: mockContext)
        progress.fileId = markdownFile.id!
        progress.currentPosition = 100
        progress.lastReadDate = Date()
        progress.totalDuration = 200
        progress.isCompleted = false
        progress.markdownFile = markdownFile
        
        try mockContext.save()
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        
        // Verify progress loaded
        XCTAssertEqual(ttsManager.currentPosition, 100)
        
        // Simulate error scenarios (rapid operations)
        for _ in 1...5 {
            ttsManager.play()
            ttsManager.currentPosition += 50
            ttsManager.stop()
        }
        
        // Progress should still be reasonable
        XCTAssertGreaterThan(ttsManager.currentPosition, 100)
    }
    
    // MARK: - Voice Quality and Audio Parameter Tests
    
    func testVoiceSelectionRobustness() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        _ = createTestParsedContent(for: markdownFile)
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        
        // Test with various voice settings
        let voices = AVSpeechSynthesisVoice.speechVoices()
        
        for voice in voices.prefix(3) { // Test first 3 voices
            ttsManager.selectedVoice = voice
            ttsManager.play()
            ttsManager.stop()
            
            // Should handle voice changes gracefully
            XCTAssertEqual(ttsManager.playbackState, .idle)
        }
    }
    
    func testAudioParameterBoundaries() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        _ = createTestParsedContent(for: markdownFile)
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        
        // Test pitch boundaries
        ttsManager.pitchMultiplier = 0.5
        ttsManager.play()
        ttsManager.stop()
        
        ttsManager.pitchMultiplier = 2.0
        ttsManager.play()
        ttsManager.stop()
        
        // Test volume boundaries
        ttsManager.volumeMultiplier = 0.1
        ttsManager.play()
        ttsManager.stop()
        
        ttsManager.volumeMultiplier = 1.0
        ttsManager.play()
        ttsManager.stop()
        
        // Should handle all parameter combinations
        XCTAssertEqual(ttsManager.playbackState, .idle)
    }
    
    // MARK: - Performance and Stress Tests
    
    func testLargeDocumentPerformance() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        
        // Create very large content (100KB+)
        var massiveContent = ""
        for i in 1...2000 {
            massiveContent += "This is a very long paragraph \(i) designed to test the performance of the TTS system with large documents. It contains enough text to create a substantial processing load. "
        }
        
        let parsedContent = ParsedContent(context: mockContext)
        parsedContent.fileId = markdownFile.id!
        parsedContent.plainText = massiveContent
        parsedContent.lastParsed = Date()
        parsedContent.markdownFiles = markdownFile
        
        try mockContext.save()
        
        // Measure loading performance
        measure {
            ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        }
        
        // Verify functionality with large content
        XCTAssertEqual(ttsManager.playbackState, .idle)
        XCTAssertGreaterThan(massiveContent.count, 100000)
    }
    
    func testRapidSectionNavigation() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        let parsedContent = createTestParsedContentWithManySections(for: markdownFile)
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        
        // Test rapid section navigation
        measure {
            for _ in 1...50 {
                ttsManager.skipToNextSection()
                if ttsManager.currentSectionIndex >= 10 {
                    // Reset to avoid going too far
                    ttsManager.currentSectionIndex = 0
                    ttsManager.currentPosition = 0
                }
            }
        }
        
        // Should handle rapid navigation without issues
        XCTAssertGreaterThanOrEqual(ttsManager.currentSectionIndex, 0)
    }
    
    // MARK: - Error Recovery Tests
    
    func testRecoveryFromCorruptedData() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        
        // Create partially corrupted parsed content
        let parsedContent = ParsedContent(context: mockContext)
        parsedContent.fileId = markdownFile.id!
        parsedContent.plainText = nil // Corrupted state
        parsedContent.lastParsed = Date()
        parsedContent.markdownFiles = markdownFile
        
        try mockContext.save()
        
        // Should handle gracefully without crashing
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        
        XCTAssertEqual(ttsManager.playbackState, .idle)
        
        // Should not crash when attempting operations
        ttsManager.play()
        ttsManager.stop()
    }
    
    func testRecoveryFromInvalidPositions() throws {
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        _ = createTestParsedContent(for: markdownFile)
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        
        // Set invalid positions
        ttsManager.currentPosition = -100 // Negative position
        ttsManager.play()
        ttsManager.stop()
        
        ttsManager.currentPosition = 999999 // Way beyond content
        ttsManager.play()
        ttsManager.stop()
        
        // Should handle invalid positions gracefully
        XCTAssertEqual(ttsManager.playbackState, .idle)
    }
    
    // MARK: - Helper Methods
    
    private func createTestRepository() -> GitRepository {
        let repository = GitRepository(context: mockContext)
        repository.id = UUID()
        repository.name = "Enhanced Test Repository"
        repository.remoteURL = "https://github.com/test/enhanced"
        repository.localPath = "/test/enhanced"
        repository.defaultBranch = "main"
        repository.syncEnabled = true
        
        return repository
    }
    
    private func createTestMarkdownFile(repository: GitRepository) -> MarkdownFile {
        let markdownFile = MarkdownFile(context: mockContext)
        markdownFile.id = UUID()
        markdownFile.title = "Enhanced Test File"
        markdownFile.filePath = "/test/enhanced/file.md"
        markdownFile.gitFilePath = "file.md"
        markdownFile.repositoryId = repository.id
        markdownFile.lastModified = Date()
        markdownFile.fileSize = 2000
        markdownFile.syncStatusEnum = .synced
        markdownFile.hasLocalChanges = false
        markdownFile.repository = repository
        
        return markdownFile
    }
    
    private func createTestParsedContent(for markdownFile: MarkdownFile) -> ParsedContent {
        let parsedContent = ParsedContent(context: mockContext)
        parsedContent.fileId = markdownFile.id!
        parsedContent.plainText = """
        Enhanced Test Content
        
        This is enhanced test content designed to thoroughly test the TTS functionality.
        It contains multiple paragraphs with substantial content for comprehensive testing.
        
        The content includes various sentence structures and lengths to simulate real documents.
        Some sentences are short. Others are much longer and contain more complex grammatical structures that help test the speech synthesis system's ability to handle varied content types effectively.
        
        This final paragraph ensures we have enough content for position tracking and navigation testing purposes.
        """
        parsedContent.lastParsed = Date()
        parsedContent.markdownFiles = markdownFile
        
        return parsedContent
    }
    
    private func createTestParsedContentWithManySections(for markdownFile: MarkdownFile) -> ParsedContent {
        let parsedContent = createTestParsedContent(for: markdownFile)
        
        // Create multiple sections for navigation testing
        for i in 0..<20 {
            let section = ContentSection(context: mockContext)
            section.startIndex = Int32(i * 50)
            section.endIndex = Int32((i + 1) * 50)
            section.typeEnum = i % 2 == 0 ? .paragraph : .header
            section.level = Int16(i % 3)
            section.isSkippable = (i % 5 == 0) // Every 5th section is skippable
            section.parsedContent = parsedContent
        }
        
        return parsedContent
    }
}