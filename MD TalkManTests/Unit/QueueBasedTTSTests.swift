//
//  QueueBasedTTSTests.swift
//  MD TalkManTests
//
//  Created by Claude on 1/09/25.
//  Comprehensive tests for queue-based TTS architecture
//

import XCTest
import CoreData
import AVFoundation
@testable import MD_TalkMan

final class QueueBasedTTSTests: XCTestCase {
    
    var queueManager: UtteranceQueueManager!
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
        queueManager = UtteranceQueueManager()
        ttsManager = TTSManager()
    }
    
    override func tearDownWithError() throws {
        ttsManager?.stop()
        queueManager = nil
        ttsManager = nil
        mockContext = nil
        testContainer = nil
    }
    
    // MARK: - CircularBuffer Tests
    
    func testCircularBufferInitialization() throws {
        let buffer = CircularBuffer<String>(capacity: 3)
        
        XCTAssertTrue(buffer.isEmpty)
        XCTAssertFalse(buffer.isFull)
        XCTAssertEqual(buffer.size, 0)
        XCTAssertEqual(buffer.elements.count, 0)
    }
    
    func testCircularBufferBasicOperations() throws {
        var buffer = CircularBuffer<String>(capacity: 3)
        
        // Test appending elements
        buffer.append("First")
        XCTAssertFalse(buffer.isEmpty)
        XCTAssertEqual(buffer.size, 1)
        XCTAssertEqual(buffer.elements, ["First"])
        
        buffer.append("Second")
        buffer.append("Third")
        XCTAssertTrue(buffer.isFull)
        XCTAssertEqual(buffer.size, 3)
        XCTAssertEqual(buffer.elements, ["First", "Second", "Third"])
    }
    
    func testCircularBufferWrapping() throws {
        var buffer = CircularBuffer<String>(capacity: 3)
        
        // Fill buffer beyond capacity
        buffer.append("First")
        buffer.append("Second")
        buffer.append("Third")
        buffer.append("Fourth") // Should wrap, evicting "First"
        
        XCTAssertTrue(buffer.isFull)
        XCTAssertEqual(buffer.size, 3)
        XCTAssertEqual(buffer.elements, ["Second", "Third", "Fourth"])
        
        // Continue wrapping
        buffer.append("Fifth") // Should evict "Second"
        XCTAssertEqual(buffer.elements, ["Third", "Fourth", "Fifth"])
    }
    
    func testCircularBufferReversed() throws {
        var buffer = CircularBuffer<String>(capacity: 4)
        
        buffer.append("A")
        buffer.append("B")
        buffer.append("C")
        
        let reversed = buffer.reversed()
        XCTAssertEqual(reversed, ["C", "B", "A"])
    }
    
    // MARK: - QueuedUtterance Tests
    
    func testQueuedUtteranceCreation() throws {
        let utterance = AVSpeechUtterance(string: "Test utterance")
        let metadata = UtteranceMetadata(
            contentType: .paragraph,
            language: "swift",
            isSkippable: false,
            interjectionEvents: []
        )
        
        let queuedUtterance = QueuedUtterance(
            utterance: utterance,
            startPosition: 0,
            endPosition: 13,
            sectionIndex: 0,
            isInterjection: false,
            priority: .normal,
            metadata: metadata,
            performance: nil
        )
        
        XCTAssertEqual(queuedUtterance.startPosition, 0)
        XCTAssertEqual(queuedUtterance.endPosition, 13)
        XCTAssertEqual(queuedUtterance.sectionIndex, 0)
        XCTAssertFalse(queuedUtterance.isInterjection)
        XCTAssertEqual(queuedUtterance.priority, .normal)
        XCTAssertEqual(queuedUtterance.utterance.speechString, "Test utterance")
    }
    
    func testUtteranceMetadata() throws {
        let interjectionEvent = InterjectionEvent.codeBlockStart(
            language: "swift",
            section: createMockContentSection()
        )
        
        let metadata = UtteranceMetadata(
            contentType: .codeBlock,
            language: "swift",
            isSkippable: true,
            interjectionEvents: [interjectionEvent]
        )
        
        XCTAssertEqual(metadata.contentType, .codeBlock)
        XCTAssertEqual(metadata.language, "swift")
        XCTAssertTrue(metadata.isSkippable)
        XCTAssertEqual(metadata.interjectionEvents.count, 1)
    }
    
    func testUtterancePerformance() throws {
        let performance = UtterancePerformance(
            actualDuration: 2.5,
            charactersPerSecond: 12.5,
            completedAt: Date()
        )
        
        XCTAssertEqual(performance.actualDuration, 2.5, accuracy: 0.01)
        XCTAssertEqual(performance.charactersPerSecond, 12.5, accuracy: 0.01)
        XCTAssertNotNil(performance.completedAt)
    }
    
    // MARK: - UtteranceQueueManager Tests
    
    func testQueueManagerInitialization() throws {
        XCTAssertEqual(queueManager.queueCount, 0)
        XCTAssertEqual(queueManager.recycleQueueCount, 0)
        XCTAssertTrue(queueManager.isMainQueueEmpty)
        XCTAssertFalse(queueManager.hasRecycledContent)
    }
    
    func testAppendUtterance() throws {
        let queuedUtterance = createTestQueuedUtterance(text: "First utterance", startPos: 0, endPos: 15)
        
        queueManager.appendUtterance(queuedUtterance)
        
        XCTAssertEqual(queueManager.queueCount, 1)
        XCTAssertFalse(queueManager.isMainQueueEmpty)
        
        let firstUtterance = queueManager.getFirstUtterance()
        XCTAssertNotNil(firstUtterance)
        XCTAssertEqual(firstUtterance?.startPosition, 0)
        XCTAssertEqual(firstUtterance?.endPosition, 15)
    }
    
    func testAppendMultipleUtterances() throws {
        let utterances = [
            createTestQueuedUtterance(text: "First", startPos: 0, endPos: 5),
            createTestQueuedUtterance(text: "Second", startPos: 5, endPos: 11),
            createTestQueuedUtterance(text: "Third", startPos: 11, endPos: 16)
        ]
        
        queueManager.appendUtterances(utterances)
        
        XCTAssertEqual(queueManager.queueCount, 3)
        
        let lastUtterance = queueManager.getLastUtterance()
        XCTAssertNotNil(lastUtterance)
        XCTAssertEqual(lastUtterance?.startPosition, 11)
        XCTAssertEqual(lastUtterance?.endPosition, 16)
    }
    
    func testFetchNextFromUtteranceQueue() throws {
        let utterance1 = createTestQueuedUtterance(text: "First", startPos: 0, endPos: 5)
        let utterance2 = createTestQueuedUtterance(text: "Second", startPos: 5, endPos: 11)
        
        queueManager.appendUtterance(utterance1)
        queueManager.appendUtterance(utterance2)
        XCTAssertEqual(queueManager.queueCount, 2)
        
        // Fetch first utterance
        let fetched1 = queueManager.fetchNextFromUtteranceQueue()
        XCTAssertNotNil(fetched1)
        XCTAssertEqual(fetched1?.startPosition, 0)
        XCTAssertEqual(fetched1?.endPosition, 5)
        XCTAssertEqual(queueManager.queueCount, 1)
        
        // Fetch second utterance
        let fetched2 = queueManager.fetchNextFromUtteranceQueue()
        XCTAssertNotNil(fetched2)
        XCTAssertEqual(fetched2?.startPosition, 5)
        XCTAssertEqual(fetched2?.endPosition, 11)
        XCTAssertEqual(queueManager.queueCount, 0)
        XCTAssertTrue(queueManager.isMainQueueEmpty)
        
        // Try to fetch from empty queue
        let fetchedEmpty = queueManager.fetchNextFromUtteranceQueue()
        XCTAssertNil(fetchedEmpty)
    }
    
    func testInsertAtFrontOfQueue() throws {
        let normalUtterance = createTestQueuedUtterance(text: "Normal", startPos: 0, endPos: 6, priority: .normal)
        let urgentUtterance = createTestQueuedUtterance(text: "Urgent", startPos: 6, endPos: 12, priority: .urgent, isInterjection: true)
        
        queueManager.appendUtterance(normalUtterance)
        queueManager.insertAtFrontOfQueue(urgentUtterance)
        
        XCTAssertEqual(queueManager.queueCount, 2)
        
        // Urgent utterance should be fetched first
        let fetched = queueManager.fetchNextFromUtteranceQueue()
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.priority, .urgent)
        XCTAssertTrue(fetched?.isInterjection ?? false)
        XCTAssertEqual(fetched?.utterance.speechString, "Urgent")
    }
    
    // MARK: - RecycleQueue Tests
    
    func testMoveToRecycleQueue() throws {
        let utterance = createTestQueuedUtterance(text: "Completed utterance", startPos: 0, endPos: 19)
        let performance = UtterancePerformance(actualDuration: 1.5, charactersPerSecond: 12.67)
        
        queueManager.moveToRecycleQueue(utterance, performance: performance)
        
        XCTAssertEqual(queueManager.recycleQueueCount, 1)
        XCTAssertTrue(queueManager.hasRecycledContent)
    }
    
    func testFindReplayUtterances() throws {
        // Create utterances with known performance data
        let utterance1 = createTestQueuedUtterance(text: "First", startPos: 0, endPos: 5)
        let performance1 = UtterancePerformance(actualDuration: 1.0, charactersPerSecond: 5.0)
        
        let utterance2 = createTestQueuedUtterance(text: "Second", startPos: 5, endPos: 11)
        let performance2 = UtterancePerformance(actualDuration: 1.5, charactersPerSecond: 4.0)
        
        let utterance3 = createTestQueuedUtterance(text: "Third", startPos: 11, endPos: 16)
        let performance3 = UtterancePerformance(actualDuration: 2.0, charactersPerSecond: 2.5)
        
        // Move to recycle queue in order
        queueManager.moveToRecycleQueue(utterance1, performance: performance1)
        queueManager.moveToRecycleQueue(utterance2, performance: performance2)
        queueManager.moveToRecycleQueue(utterance3, performance: performance3)
        
        // Find utterances for 2.5 seconds of replay (should get last 2 utterances)
        let replayUtterances = queueManager.findReplayUtterances(seconds: 2.5)
        
        XCTAssertNotNil(replayUtterances)
        XCTAssertEqual(replayUtterances?.count, 2)
        
        // Should be in chronological order (Second, Third)
        XCTAssertEqual(replayUtterances?[0].startPosition, 5)
        XCTAssertEqual(replayUtterances?[1].startPosition, 11)
    }
    
    func testGetLastMainContentUtterance() throws {
        let mainUtterance = createTestQueuedUtterance(text: "Main content", startPos: 0, endPos: 12, isInterjection: false)
        let interjectionUtterance = createTestQueuedUtterance(text: "swift code", startPos: 12, endPos: 12, isInterjection: true)
        let mainPerformance = UtterancePerformance(actualDuration: 1.0, charactersPerSecond: 12.0)
        let interjectionPerformance = UtterancePerformance(actualDuration: 0.5, charactersPerSecond: 20.0)
        
        queueManager.moveToRecycleQueue(mainUtterance, performance: mainPerformance)
        queueManager.moveToRecycleQueue(interjectionUtterance, performance: interjectionPerformance)
        
        let lastMainContent = queueManager.getLastMainContentUtterance()
        XCTAssertNotNil(lastMainContent)
        XCTAssertFalse(lastMainContent?.isInterjection ?? true)
        XCTAssertEqual(lastMainContent?.utterance.speechString, "Main content")
    }
    
    func testGetContextReplayUtterances() throws {
        // Create multiple main content utterances
        for i in 0..<5 {
            let utterance = createTestQueuedUtterance(
                text: "Content \(i)",
                startPos: i * 10,
                endPos: (i + 1) * 10,
                isInterjection: false
            )
            let performance = UtterancePerformance(actualDuration: 1.0, charactersPerSecond: 10.0)
            queueManager.moveToRecycleQueue(utterance, performance: performance)
        }
        
        let contextUtterances = queueManager.getContextReplayUtterances()
        
        // Should return last 3 main content utterances (contextReplayDepth = 3)
        XCTAssertEqual(contextUtterances.count, 3)
        XCTAssertEqual(contextUtterances[0].utterance.speechString, "Content 2")
        XCTAssertEqual(contextUtterances[1].utterance.speechString, "Content 3")
        XCTAssertEqual(contextUtterances[2].utterance.speechString, "Content 4")
    }
    
    // MARK: - Queue Management Tests
    
    func testClearMainQueue() throws {
        let utterances = [
            createTestQueuedUtterance(text: "First", startPos: 0, endPos: 5),
            createTestQueuedUtterance(text: "Second", startPos: 5, endPos: 11)
        ]
        
        queueManager.appendUtterances(utterances)
        XCTAssertEqual(queueManager.queueCount, 2)
        
        queueManager.clearMainQueue()
        XCTAssertEqual(queueManager.queueCount, 0)
        XCTAssertTrue(queueManager.isMainQueueEmpty)
    }
    
    func testResetAllQueues() throws {
        // Add to both main queue and recycle queue
        let utterance = createTestQueuedUtterance(text: "Test", startPos: 0, endPos: 4)
        queueManager.appendUtterance(utterance)
        
        let performance = UtterancePerformance(actualDuration: 1.0, charactersPerSecond: 4.0)
        queueManager.moveToRecycleQueue(utterance, performance: performance)
        
        XCTAssertEqual(queueManager.queueCount, 1)
        XCTAssertEqual(queueManager.recycleQueueCount, 1)
        
        queueManager.resetAllQueues()
        
        XCTAssertEqual(queueManager.queueCount, 0)
        XCTAssertEqual(queueManager.recycleQueueCount, 0)
        XCTAssertTrue(queueManager.isMainQueueEmpty)
        XCTAssertFalse(queueManager.hasRecycledContent)
    }
    
    // MARK: - Priority System Tests
    
    func testQueuePriorityOrdering() throws {
        let priorities: [QueuePriority] = [.background, .normal, .interjection, .urgent, .critical]
        
        // Test that priority raw values are correctly ordered
        for i in 0..<priorities.count - 1 {
            XCTAssertLessThan(priorities[i].rawValue, priorities[i + 1].rawValue)
        }
        
        XCTAssertEqual(QueuePriority.background.rawValue, 0)
        XCTAssertEqual(QueuePriority.normal.rawValue, 1)
        XCTAssertEqual(QueuePriority.interjection.rawValue, 2)
        XCTAssertEqual(QueuePriority.urgent.rawValue, 3)
        XCTAssertEqual(QueuePriority.critical.rawValue, 4)
    }
    
    // MARK: - Integration Tests with TTSManager
    
    func testQueueModeFeatureFlag() throws {
        // Test that TTSManager has isQueueMode property for dual-mode operation
        // This ensures backward compatibility is maintained
        
        // Initially should be in legacy single-utterance mode
        XCTAssertFalse(ttsManager.isQueueMode)
        
        // Enable queue mode
        ttsManager.isQueueMode = true
        XCTAssertTrue(ttsManager.isQueueMode)
        
        // Should be able to switch back
        ttsManager.isQueueMode = false
        XCTAssertFalse(ttsManager.isQueueMode)
    }
    
    func testTTSManagerQueueIntegration() throws {
        // Test that TTSManager can work with UtteranceQueueManager
        ttsManager.isQueueMode = true
        
        let repository = createTestRepository()
        let markdownFile = createTestMarkdownFile(repository: repository)
        _ = createTestParsedContent(for: markdownFile)
        
        ttsManager.loadMarkdownFile(markdownFile, context: mockContext)
        
        // Should be able to load content in queue mode
        XCTAssertEqual(ttsManager.playbackState, .idle)
        
        // Test basic queue mode functionality
        ttsManager.play()
        
        // In queue mode, should handle playback differently
        // (Detailed testing would require mocking AVSpeechSynthesizer)
    }
    
    // MARK: - Error Handling Tests
    
    func testEmptyQueueHandling() throws {
        // Test fetching from empty queue
        let fetched = queueManager.fetchNextFromUtteranceQueue()
        XCTAssertNil(fetched)
        
        // Test finding replay utterances with empty recycle queue
        let replayUtterances = queueManager.findReplayUtterances(seconds: 5.0)
        XCTAssertNil(replayUtterances)
        
        // Test getting last main content from empty recycle queue
        let lastMainContent = queueManager.getLastMainContentUtterance()
        XCTAssertNil(lastMainContent)
    }
    
    func testContextReplayWithInsufficientData() throws {
        // Add only 1 main content utterance (less than contextReplayDepth of 3)
        let utterance = createTestQueuedUtterance(text: "Only one", startPos: 0, endPos: 8, isInterjection: false)
        let performance = UtterancePerformance(actualDuration: 1.0, charactersPerSecond: 8.0)
        queueManager.moveToRecycleQueue(utterance, performance: performance)
        
        let contextUtterances = queueManager.getContextReplayUtterances()
        
        // Should return what's available (1 utterance instead of 3)
        XCTAssertEqual(contextUtterances.count, 1)
        XCTAssertEqual(contextUtterances[0].utterance.speechString, "Only one")
    }
    
    // MARK: - Helper Methods
    
    private func createTestQueuedUtterance(
        text: String,
        startPos: Int,
        endPos: Int,
        priority: QueuePriority = .normal,
        isInterjection: Bool = false
    ) -> QueuedUtterance {
        let utterance = AVSpeechUtterance(string: text)
        let metadata = UtteranceMetadata(
            contentType: isInterjection ? .codeBlock : .paragraph,
            language: isInterjection ? "swift" : nil,
            isSkippable: isInterjection,
            interjectionEvents: []
        )
        
        return QueuedUtterance(
            utterance: utterance,
            startPosition: startPos,
            endPosition: endPos,
            sectionIndex: 0,
            isInterjection: isInterjection,
            priority: priority,
            metadata: metadata,
            performance: nil
        )
    }
    
    private func createMockContentSection() -> ContentSection {
        let section = ContentSection(context: mockContext)
        section.startIndex = 0
        section.endIndex = 100
        section.typeEnum = .codeBlock
        section.level = 0
        section.isSkippable = true
        return section
    }
    
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
        Test content for queue-based TTS testing.
        
        This paragraph contains enough text to test multi-utterance queueing functionality.
        """
        parsedContent.lastParsed = Date()
        parsedContent.markdownFiles = markdownFile
        
        return parsedContent
    }
}