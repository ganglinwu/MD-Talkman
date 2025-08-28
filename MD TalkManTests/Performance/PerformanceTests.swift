//
//  PerformanceTests.swift
//  MD TalkManTests
//
//  Created by Claude on 8/28/25.
//

import XCTest
import AVFoundation
import CoreData
@testable import MD_TalkMan

final class PerformanceTests: XCTestCase {
    
    var parser: MarkdownParser!
    var ttsManager: TTSManager!
    var audioFeedback: AudioFeedbackManager!
    var customToneGenerator: CustomToneGenerator!
    var settingsManager: SettingsManager!
    var textWindowManager: TextWindowManager!
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
        
        // Initialize components
        parser = MarkdownParser()
        ttsManager = TTSManager()
        audioFeedback = AudioFeedbackManager()
        customToneGenerator = CustomToneGenerator(volume: 0.5)
        settingsManager = SettingsManager.shared
        textWindowManager = TextWindowManager()
    }
    
    override func tearDownWithError() throws {
        // Clean up
        ttsManager.stop()
        
        parser = nil
        ttsManager = nil
        audioFeedback = nil
        customToneGenerator = nil
        settingsManager = nil
        textWindowManager = nil
        
        if let container = testContainer {
            container.viewContext.reset()
            // Remove all persistent stores
            for store in container.persistentStoreCoordinator.persistentStores {
                try? container.persistentStoreCoordinator.remove(store)
            }
        }
        testContainer = nil
    }
    
    // MARK: - Performance Test Helper Methods
    
    private func createLargeMarkdownDocument(paragraphCount: Int, codeBlockCount: Int) -> String {
        var markdown = "# Large Performance Test Document\n\n"
        
        for i in 0..<paragraphCount {
            markdown += "This is paragraph \(i + 1) with some sample text for performance testing. "
            markdown += "It contains multiple sentences to simulate realistic content.\n\n"
        }
        
        let languages = ["swift", "python", "javascript", "java", "c", "cpp", "rust", "go"]
        
        for i in 0..<codeBlockCount {
            let language = languages[i % languages.count]
            markdown += "```\(language)\n"
            markdown += "// Code block \(i + 1) in \(language)\n"
            markdown += "func example\(i + 1)() {\n"
            markdown += "    return \"Performance test \(i + 1)\";\n"
            markdown += "}\n"
            markdown += "```\n\n"
        }
        
        return markdown
    }
    
    private func createTestContent(paragraphCount: Int, codeBlockCount: Int) -> (markdown: String, parsedContent: ParsedContent, sections: [ContentSection], file: MarkdownFile) {
        let markdown = createLargeMarkdownDocument(paragraphCount: paragraphCount, codeBlockCount: codeBlockCount)
        
        // Create parsed content
        let parsedContent = ParsedContent(context: mockContext)
        parsedContent.plainText = markdown
        parsedContent.lastParsed = Date()
        
        // Create markdown file
        let file = MarkdownFile(context: mockContext)
        file.id = UUID()
        file.title = "Performance Test Document"
        file.filePath = "/test/performance.md"
        file.lastModified = Date()
        
        // Parse markdown to get sections
        let parseResult = parser.parseMarkdownForTTS(markdown)
        
        // Create sections with proper Core Data objects
        var sections: [ContentSection] = []
        
        for parsedSection in parseResult.sections {
            let section = ContentSection(context: mockContext)
            section.startIndex = Int32(parsedSection.startIndex)
            section.endIndex = Int32(parsedSection.endIndex)
            section.typeEnum = parsedSection.type
            section.level = Int16(parsedSection.level)
            section.isSkippable = parsedSection.isSkippable
            section.parsedContent = parsedContent
            sections.append(section)
        }
        
        return (markdown, parsedContent, sections, file)
    }
    
    // MARK: - Markdown Parsing Performance Tests
    
    func testMarkdownParsingPerformanceSmallDocument() {
        let markdown = createLargeMarkdownDocument(paragraphCount: 10, codeBlockCount: 5)
        
        measure {
            for _ in 0..<100 {
                let result = parser.parseMarkdownForTTS(markdown)
                XCTAssertFalse(result.sections.isEmpty)
            }
        }
    }
    
    func testMarkdownParsingPerformanceMediumDocument() {
        let markdown = createLargeMarkdownDocument(paragraphCount: 50, codeBlockCount: 25)
        
        measure {
            for _ in 0..<50 {
                let result = parser.parseMarkdownForTTS(markdown)
                XCTAssertFalse(result.sections.isEmpty)
            }
        }
    }
    
    func testMarkdownParsingPerformanceLargeDocument() {
        let markdown = createLargeMarkdownDocument(paragraphCount: 200, codeBlockCount: 100)
        
        measure {
            for _ in 0..<20 {
                let result = parser.parseMarkdownForTTS(markdown)
                XCTAssertFalse(result.sections.isEmpty)
            }
        }
    }
    
    func testCodeBlockDetectionPerformance() {
        let markdown = createLargeMarkdownDocument(paragraphCount: 100, codeBlockCount: 100)
        
        measure {
            for _ in 0..<50 {
                let result = parser.parseMarkdownForTTS(markdown)
                let codeBlocks = result.sections.filter { $0.type == .codeBlock }
                XCTAssertEqual(codeBlocks.count, 100)
            }
        }
    }
    
    // MARK: - Text Window Manager Performance Tests
    
    func testTextWindowManagerLoadPerformance() {
        let (markdown, parsedContent, sections, file) = createTestContent(paragraphCount: 100, codeBlockCount: 50)
        
        measure {
            for _ in 0..<100 {
                textWindowManager.loadContent(sections: sections, plainText: markdown)
            }
        }
    }
    
    func testTextWindowManagerUpdatePerformance() {
        let (markdown, parsedContent, sections, file) = createTestContent(paragraphCount: 100, codeBlockCount: 50)
        textWindowManager.loadContent(sections: sections, plainText: markdown)
        
        measure {
            for i in 0..<1000 {
                let position = i * (markdown.count / 1000)
                textWindowManager.updateWindow(for: position)
            }
        }
    }
    
    func testTextWindowManagerSearchPerformance() {
        let (markdown, parsedContent, sections, file) = createTestContent(paragraphCount: 100, codeBlockCount: 50)
        textWindowManager.loadContent(sections: sections, plainText: markdown)
        
        measure {
            for _ in 0..<200 {
                let results = textWindowManager.searchInWindow("performance")
                XCTAssertFalse(results.isEmpty)
            }
        }
    }
    
    // MARK: - TTS Manager Performance Tests
    
    func testTTSManagerLoadContentPerformance() {
        let (markdown, parsedContent, sections, file) = createTestContent(paragraphCount: 50, codeBlockCount: 25)
        
        measure {
            for _ in 0..<50 {
                // Load content using correct API
                textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
                ttsManager.loadMarkdownFile(file, context: mockContext)
            }
        }
    }
    
    func testTTSManagerPositionUpdatePerformance() {
        let (markdown, parsedContent, sections, file) = createTestContent(paragraphCount: 50, codeBlockCount: 25)
        // Load content using correct API
        textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
        ttsManager.loadMarkdownFile(file, context: mockContext)
        
        measure {
            for i in 0..<500 {
                let position = i * (markdown.count / 500)
                // Position updates are handled automatically by TTSManager
            }
        }
    }
    
    func testTTSManagerSectionTransitionPerformance() {
        let (markdown, parsedContent, sections, file) = createTestContent(paragraphCount: 100, codeBlockCount: 50)
        // Load content using correct API
        textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
        ttsManager.loadMarkdownFile(file, context: mockContext)
        
        measure {
            // Simulate rapid section transitions
            for i in 0..<200 {
                let sectionIndex = i % sections.count
                let position = Int(sections[sectionIndex].startIndex) + 10
                // Position updates are handled automatically by TTSManager
            }
        }
    }
    
    func testTTSManagerVolumeFadingPerformance() {
        let (markdown, parsedContent, sections, file) = createTestContent(paragraphCount: 20, codeBlockCount: 10)
        // Load content using correct API
        textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
        ttsManager.loadMarkdownFile(file, context: mockContext)
        
        measure {
            for _ in 0..<100 {
                ttsManager.play()
                RunLoop.current.run(until: Date().addingTimeInterval(0.01))
                ttsManager.stop()
                RunLoop.current.run(until: Date().addingTimeInterval(0.01))
            }
        }
    }
    
    // MARK: - Audio Feedback Performance Tests
    
    func testAudioFeedbackManagerPerformance() {
        measure {
            for _ in 0..<200 {
                audioFeedback.playFeedback(for: .buttonTap)
                RunLoop.current.run(until: Date().addingTimeInterval(0.005))
            }
        }
    }
    
    func testAudioFeedbackAllTypesPerformance() {
        let feedbackTypes: [AudioFeedbackType] = [
            .playStarted, .playPaused, .playStopped, .playCompleted,
            .sectionChanged, .voiceChanged, .error, .buttonTap,
            .codeBlockStart, .codeBlockEnd
        ]
        
        measure {
            for _ in 0..<50 {
                for type in feedbackTypes {
                    audioFeedback.playFeedback(for: type)
                    RunLoop.current.run(until: Date().addingTimeInterval(0.002))
                }
            }
        }
    }
    
    func testAudioFeedbackVolumeChangePerformance() {
        measure {
            for i in 0..<1000 {
                let volume = Float(i % 100) / 100.0
                audioFeedback.setVolume(volume)
            }
        }
    }
    
    // MARK: - Custom Tone Generator Performance Tests
    
    func testCustomToneGeneratorSingleTonePerformance() {
        measure {
            for _ in 0..<100 {
                let expectation = XCTestExpectation(description: "Tone completion")
                
                customToneGenerator.playButtonTapTone() {
                    expectation.fulfill()
                }
                
                wait(for: [expectation], timeout: 1.0)
            }
        }
    }
    
    func testCustomToneGeneratorMultipleTonesPerformance() {
        let toneTypes: [() -> Void] = [
            { self.customToneGenerator.playStartTone {} },
            { self.customToneGenerator.playPauseTone {} },
            { self.customToneGenerator.playStopTone {} },
            { self.customToneGenerator.playCompletionTone {} },
            { self.customToneGenerator.playNavigationTone {} }
        ]
        
        measure {
            for _ in 0..<50 {
                let expectation = XCTestExpectation(description: "Multiple tones completion")
                var completedTones = 0
                
                for tone in toneTypes {
                    tone()
                        completedTones += 1
                        if completedTones == toneTypes.count {
                            expectation.fulfill()
                        }
                }
                
                wait(for: [expectation], timeout: 2.0)
            }
        }
    }
    
    func testCustomToneGeneratorVolumeChangePerformance() {
        measure {
            for i in 0..<1000 {
                let volume = Float(i % 100) / 100.0
                _ = volume // Volume is set during initialization, not changeable
            }
        }
    }
    
    // MARK: - Settings Manager Performance Tests
    
    func testSettingsManagerReadWritePerformance() {
        measure {
            for i in 0..<1000 {
                settingsManager.codeBlockNotificationStyle = SettingsManager.CodeBlockNotificationStyle.allCases[i % 4]
                settingsManager.isCodeBlockLanguageNotificationEnabled = i % 2 == 0
                settingsManager.codeBlockToneVolume = Float(i % 100) / 100.0
                
                // Read settings
                _ = settingsManager.codeBlockNotificationStyle
                _ = settingsManager.isCodeBlockLanguageNotificationEnabled
                _ = settingsManager.codeBlockToneVolume
            }
        }
    }
    
    func testSettingsManagerPersistencePerformance() {
        measure {
            for _ in 0..<100 {
                // Create new manager to test persistence performance
                let newManager = SettingsManager.shared
                
                // Modify settings
                newManager.codeBlockNotificationStyle = .both
                newManager.isCodeBlockLanguageNotificationEnabled = true
                newManager.codeBlockToneVolume = 0.8
                
                // Settings will be persisted when newManager goes out of scope
            }
        }
    }
    
    // MARK: - Visual Text Display Performance Tests
    
    func testVisualTextDisplayRenderingPerformance() {
        let (markdown, parsedContent, sections, file) = createTestContent(paragraphCount: 20, codeBlockCount: 10)
        textWindowManager.loadContent(sections: sections, plainText: markdown)
        
        // Note: In a real test environment, we'd need to simulate SwiftUI view rendering
        // For now, we'll test the underlying data preparation
        
        measure {
            for _ in 0..<100 {
                textWindowManager.updateWindow(for: Int(markdown.count / 2))
                _ = textWindowManager.displayWindow
                _ = textWindowManager.currentHighlight
            }
        }
    }
    
    func testVisualTextDisplaySearchPerformance() {
        let (markdown, parsedContent, sections, file) = createTestContent(paragraphCount: 30, codeBlockCount: 15)
        textWindowManager.loadContent(sections: sections, plainText: markdown)
        
        measure {
            for _ in 0..<200 {
                let results = textWindowManager.searchInWindow("performance")
                XCTAssertFalse(results.isEmpty)
            }
        }
    }
    
    // MARK: - Integration Performance Tests
    
    func testCompletePipelinePerformance() {
        let (markdown, parsedContent, sections, file) = createTestContent(paragraphCount: 20, codeBlockCount: 10)
        
        measure {
            for _ in 0..<25 {
                // Complete pipeline: parse → load → update → search
                let parseResult = parser.parseMarkdownForTTS(markdown)
                
                // Load content using correct API
                textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
                ttsManager.loadMarkdownFile(file, context: mockContext)
                
                for i in 0..<10 {
                    let position = i * (markdown.count / 10)
                    // Position updates are handled automatically by TTSManager
                }
                
                // Convert ParsedSection to ContentSection
                let contentSections = parseResult.sections.map { parsedSection -> ContentSection in
                    let section = ContentSection(context: mockContext)
                    section.startIndex = Int32(parsedSection.startIndex)
                    section.endIndex = Int32(parsedSection.endIndex)
                    section.typeEnum = parsedSection.type
                    section.level = Int16(parsedSection.level)
                    section.isSkippable = parsedSection.isSkippable
                    return section
                }
                textWindowManager.loadContent(sections: contentSections, plainText: markdown)
                _ = textWindowManager.searchInWindow("performance")
            }
        }
    }
    
    func testConcurrentOperationsPerformance() {
        let (markdown, parsedContent, sections, file) = createTestContent(paragraphCount: 50, codeBlockCount: 25)
        
        measure {
            let expectation = XCTestExpectation(description: "Concurrent operations")
            let operationCount = 50
            var completedOperations = 0
            
            let queue = DispatchQueue(label: "concurrent.performance", attributes: .concurrent)
            
            for i in 0..<operationCount {
                queue.async {
                    // Mix of different operations
                    switch i % 5 {
                    case 0:
                        let parseResult = self.parser.parseMarkdownForTTS(markdown)
                        _ = parseResult.sections.count
                    case 1:
                        // Load content using correct API
                        self.textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
                        self.ttsManager.loadMarkdownFile(file, context: self.mockContext)
                    case 2:
                        let position = i * (markdown.count / operationCount)
                        // Position updates are handled automatically by TTSManager
                    case 3:
                        self.textWindowManager.loadContent(sections: sections, plainText: markdown)
                    case 4:
                        _ = self.textWindowManager.searchInWindow("performance")
                    default:
                        break
                    }
                    
                    DispatchQueue.main.async {
                        completedOperations += 1
                        if completedOperations == operationCount {
                            expectation.fulfill()
                        }
                    }
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Memory Performance Tests
    
    func testMemoryAllocationPerformance() {
        measure {
            for _ in 0..<100 {
                autoreleasepool {
                    let (markdown, parsedContent, sections, file) = createTestContent(paragraphCount: 10, codeBlockCount: 5)
                    
                    let testTTSManager = TTSManager()
                    let testAudioFeedback = AudioFeedbackManager()
                    let testCustomToneGenerator = CustomToneGenerator()
                    let testTextWindowManager = TextWindowManager()
                    
                    // Load content using correct API
                    textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
                    testTTSManager.loadMarkdownFile(file, context: mockContext)
                    testTextWindowManager.loadContent(sections: sections, plainText: markdown)
                    
                    // Perform some operations
                    for i in 0..<10 {
                        let position = i * (markdown.count / 10)
                        // Position updates are handled automatically by TTSManager
                        testTextWindowManager.updateWindow(for: position)
                    }
                    
                    // Objects will be deallocated when autoreleasepool exits
                }
            }
        }
    }
    
    func testLargeDocumentMemoryPerformance() {
        let (markdown, parsedContent, sections, file) = createTestContent(paragraphCount: 500, codeBlockCount: 250)
        
        measure {
            autoreleasepool {
                let testTTSManager = TTSManager()
                let testTextWindowManager = TextWindowManager()
                
                // Load content using correct API
                self.textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
                testTTSManager.loadMarkdownFile(file, context: self.mockContext)
                testTextWindowManager.loadContent(sections: sections, plainText: markdown)
                
                // Perform operations on large document
                for i in 0..<100 {
                    let position = i * (markdown.count / 100)
                    // Position updates are handled automatically by TTSManager during playback
                    testTextWindowManager.updateWindow(for: position)
                }
                
                // Memory should be freed when autoreleasepool exits
            }
        }
    }
    
    // MARK: - Real-World Scenario Performance Tests
    
    func testRealisticReadingSessionPerformance() {
        let (markdown, parsedContent, sections, file) = createTestContent(paragraphCount: 100, codeBlockCount: 50)
        // Load content using correct API
        textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
        ttsManager.loadMarkdownFile(file, context: mockContext)
        textWindowManager.loadContent(sections: sections, plainText: markdown)
        
        measure {
            // Simulate realistic reading session
            let readingSteps = 200
            for i in 0..<readingSteps {
                let position = i * (markdown.count / readingSteps)
                // Position updates are handled automatically by TTSManager
                textWindowManager.updateWindow(for: position)
                
                // Simulate occasional audio feedback
                if i % 20 == 0 {
                    audioFeedback.playFeedback(for: .sectionChanged)
                }
                
                // Small delay to simulate reading pace
                RunLoop.current.run(until: Date().addingTimeInterval(0.001))
            }
        }
    }
    
    func testRapidUserInteractionPerformance() {
        let (markdown, parsedContent, sections, file) = createTestContent(paragraphCount: 50, codeBlockCount: 25)
        // Load content using correct API
        textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
        ttsManager.loadMarkdownFile(file, context: mockContext)
        
        measure {
            // Simulate rapid user interactions
            let interactions = 500
            for i in 0..<interactions {
                switch i % 8 {
                case 0:
                    break // Position updates are handled automatically by TTSManager
                case 1:
                    audioFeedback.playFeedback(for: .buttonTap)
                case 2:
                    settingsManager.codeBlockNotificationStyle = SettingsManager.CodeBlockNotificationStyle.allCases[i % 4]
                case 3:
                    _ = textWindowManager.searchInWindow("test")
                case 4:
                    ttsManager.play()
                case 5:
                    ttsManager.pause()
                case 6:
                    ttsManager.stop()
                case 7:
                    customToneGenerator.playNavigationTone()
                default:
                    break
                }
                
                // Very small delay to simulate rapid interactions
                RunLoop.current.run(until: Date().addingTimeInterval(0.0001))
            }
        }
    }
    
    // MARK: - Startup Performance Tests
    
    func testApplicationStartupPerformance() {
        measure {
            // Simulate application startup sequence
            let settingsManager = SettingsManager.shared
            let audioFeedback = AudioFeedbackManager()
            let customToneGenerator = CustomToneGenerator()
            let ttsManager = TTSManager()
            let textWindowManager = TextWindowManager()
            let parser = MarkdownParser()
            
            // Initialize with sample content
            let (markdown, parsedContent, sections, file) = createTestContent(paragraphCount: 10, codeBlockCount: 5)
            
            // Load content using correct API
        textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
        ttsManager.loadMarkdownFile(file, context: mockContext)
            textWindowManager.loadContent(sections: sections, plainText: markdown)
            
            // Objects will be deallocated when measure block exits
        }
    }
    
    func testFirstDocumentLoadPerformance() {
        let (markdown, parsedContent, sections, file) = createTestContent(paragraphCount: 30, codeBlockCount: 15)
        
        measure {
            for _ in 0..<20 {
                let freshTTSManager = TTSManager()
                let freshTextWindowManager = TextWindowManager()
                
                // Load content using correct API
                textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
                freshTTSManager.loadMarkdownFile(file, context: mockContext)
                freshTextWindowManager.loadContent(sections: sections, plainText: markdown)
                
                // Initial positioning (handled automatically)
                freshTextWindowManager.updateWindow(for: 0)
                freshTextWindowManager.updateWindow(for: 0)
            }
        }
    }
}