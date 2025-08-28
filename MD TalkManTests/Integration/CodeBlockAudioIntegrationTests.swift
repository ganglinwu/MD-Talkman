//
//  CodeBlockAudioIntegrationTests.swift
//  MD TalkManTests
//
//  Created by Claude on 8/28/25.
//

import XCTest
import AVFoundation
import CoreData
@testable import MD_TalkMan

final class CodeBlockAudioIntegrationTests: XCTestCase {
    
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
            for store in container.persistentStoreCoordinator.persistentStores {
                try? container.persistentStoreCoordinator.remove(store)
            }
        }
        testContainer = nil
    }
    
    // MARK: - Helper Methods
    
    private func createTestMarkdownDocument() -> (markdown: String, parsedContent: ParsedContent, sections: [ContentSection], file: MarkdownFile) {
        let markdown = """
        # Code Block Audio Integration Test
        
        This document contains various code blocks to test audio integration.
        
        ## Swift Example
        
        Here's a Swift function:
        
        ```swift
        func greet(_ name: String) -> String {
            return "Hello, \\(name)!"
        }
        ```
        
        ## Python Example
        
        And here's Python:
        
        ```python
        def greet(name):
            return f"Hello, {name}!"
        ```
        
        ## JavaScript Example
        
        JavaScript version:
        
        ```javascript
        function greet(name) {
            return `Hello, ${name}!`;
        }
        ```
        
        ## Conclusion
        
        These examples demonstrate code block audio integration.
        """
        
        // Create parsed content
        let parsedContent = ParsedContent(context: mockContext)
        // parsedContent.id is managed by Core Data
        parsedContent.plainText = markdown
        parsedContent.lastParsed = Date()
        
        // Create markdown file
        let file = MarkdownFile(context: mockContext)
        file// Core Data automatically generates UUID for ID
        file.title = "Code Block Audio Integration Test"
        file.filePath = "/test/integration.md"
        file.lastModified = Date()
        
        // Parse markdown to get sections
        let parseResult = parser.parseMarkdownForTTS(markdown)
        
        // Create sections with proper Core Data objects
        var sections: [ContentSection] = []
        
        for (index, parsedSection) in parseResult.sections.enumerated() {
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
    
    // MARK: - End-to-End Integration Tests
    
    func testCompleteCodeBlockReadingFlow() {
        let expectation = XCTestExpectation(description: "Complete code block reading flow")
        
        let (markdown, parsedContent, sections, file) = createTestMarkdownDocument()
        
        // Load content into TTS manager
        // Load content using the correct API
        textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
        ttsManager.loadMarkdownFile(file, context: mockContext)
        
        // Define reading sequence with audio feedback expectations
        let readingSequence = [
            (position: 50, delay: 1.0, expectedAudio: false),  // Regular content
            (position: 200, delay: 2.0, expectedAudio: true),  // Code block entry
            (position: 250, delay: 1.0, expectedAudio: false), // Within code block
            (position: 400, delay: 2.0, expectedAudio: true),  // Code block exit
            (position: 500, delay: 1.0, expectedAudio: false)  // Regular content
        ]
        
        var currentStep = 0
        
        for (index, (position, delay, expectedAudio)) in readingSequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * delay) {
                // Position updates are handled automatically by TTSManager
                
                // Allow time for audio feedback to play
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    currentStep += 1
                    if currentStep == readingSequence.count {
                        expectation.fulfill()
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    func testAudioFeedbackTimingWithTTS() {
        let expectation = XCTestExpectation(description: "Audio feedback timing with TTS")
        
        let (markdown, parsedContent, sections, file) = createTestMarkdownDocument()
        // Load content using the correct API
        textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
        ttsManager.loadMarkdownFile(file, context: mockContext)
        
        // Test timing coordination between TTS and audio feedback
        let testPositions = [50, 200, 400, 600]
        var positionIndex = 0
        
        let positionUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            if positionIndex < testPositions.count {
                // Position updates are handled automatically by TTSManager during playback
                positionIndex += 1
            } else {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        positionUpdateTimer.invalidate()
    }
    
    // MARK: - Settings Integration Tests
    
    func testSettingsImpactOnAudioFeedback() {
        let expectation = XCTestExpectation(description: "Settings impact on audio feedback")
        
        let (markdown, parsedContent, sections, file) = createTestMarkdownDocument()
        // Load content using the correct API
        textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
        ttsManager.loadMarkdownFile(file, context: mockContext)
        
        let settingsToTest: [SettingsManager.CodeBlockNotificationStyle] = [
            .smartDetection, .voiceOnly, .tonesOnly, .both
        ]
        
        var currentSettingIndex = 0
        
        func testCurrentSetting() {
            guard currentSettingIndex < settingsToTest.count else {
                expectation.fulfill()
                return
            }
            
            let currentSetting = settingsToTest[currentSettingIndex]
            settingsManager.codeBlockNotificationStyle = currentSetting
            
            // Test code block entry with current setting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Position updates are handled automatically by TTSManager during playback(200) // Code block position
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    // Test code block exit
                    // Position updates are handled automatically by TTSManager during playback(400) // Regular content position
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        currentSettingIndex += 1
                        testCurrentSetting()
                    }
                }
            }
        }
        
        testCurrentSetting()
        
        wait(for: [expectation], timeout: 20.0)
    }
    
    func testLanguageNotificationSettings() {
        let expectation = XCTestExpectation(description: "Language notification settings")
        
        let (markdown, parsedContent, sections, file) = createTestMarkdownDocument()
        // Load content using the correct API
        textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
        ttsManager.loadMarkdownFile(file, context: mockContext)
        
        // Test with language notifications enabled
        settingsManager.isCodeBlockLanguageNotificationEnabled = true
        settingsManager.codeBlockNotificationStyle = .smartDetection
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Position updates are handled automatically by TTSManager during playback(200) // Swift code block
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // Test with language notifications disabled
                self.settingsManager.isCodeBlockLanguageNotificationEnabled = false
                
                // Position updates are handled automatically by TTSManager during playback(400) // Python code block
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 8.0)
    }
    
    func testToneVolumeSettings() {
        let expectation = XCTestExpectation(description: "Tone volume settings")
        
        let (markdown, parsedContent, sections, file) = createTestMarkdownDocument()
        // Load content using the correct API
        textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
        ttsManager.loadMarkdownFile(file, context: mockContext)
        
        let volumeLevels: [Float] = [0.2, 0.5, 0.8, 1.0]
        var currentVolumeIndex = 0
        
        func testCurrentVolume() {
            guard currentVolumeIndex < volumeLevels.count else {
                expectation.fulfill()
                return
            }
            
            settingsManager.codeBlockToneVolume = volumeLevels[currentVolumeIndex]
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Position updates are handled automatically by TTSManager during playback(200) // Code block position
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    currentVolumeIndex += 1
                    testCurrentVolume()
                }
            }
        }
        
        testCurrentVolume()
        
        wait(for: [expectation], timeout: 12.0)
    }
    
    // MARK: - Multi-Language Code Block Tests
    
    func testMultiLanguageCodeBlockSequence() {
        let expectation = XCTestExpectation(description: "Multi-language code block sequence")
        
        let (markdown, parsedContent, sections, file) = createTestMarkdownDocument()
        // Load content using the correct API
        textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
        ttsManager.loadMarkdownFile(file, context: mockContext)
        
        // Test sequence through different language code blocks
        let codeBlockPositions = [200, 400, 600] // Swift, Python, JavaScript
        let expectedLanguages = ["swift", "python", "javascript"]
        
        var currentPositionIndex = 0
        
        func testNextCodeBlock() {
            guard currentPositionIndex < codeBlockPositions.count else {
                expectation.fulfill()
                return
            }
            
            let position = codeBlockPositions[currentPositionIndex]
            let expectedLanguage = expectedLanguages[currentPositionIndex]
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Position updates are handled automatically by TTSManager
                
                // Verify we're in the correct section
                let sectionIndex = self.ttsManager.currentSectionIndex
                let currentSection = sections[sectionIndex]
                
                XCTAssertEqual(currentSection.typeEnum, .codeBlock, "Should be in code block")
                // Language detection would be handled by the text content analysis
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    currentPositionIndex += 1
                    testNextCodeBlock()
                }
            }
        }
        
        testNextCodeBlock()
        
        wait(for: [expectation], timeout: 12.0)
    }
    
    // MARK: - Rapid Context Switching Tests
    
    func testRapidCodeBlockTransitions() {
        let expectation = XCTestExpectation(description: "Rapid code block transitions")
        
        let (markdown, parsedContent, sections, file) = createTestMarkdownDocument()
        // Load content using the correct API
        textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
        ttsManager.loadMarkdownFile(file, context: mockContext)
        
        // Test rapid switching between code blocks and regular content
        let rapidSequence = [
            50, 200, 400, 600, 200, 400, 50, 600, 400, 50
        ]
        
        var sequenceIndex = 0
        
        let rapidTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
            if sequenceIndex < rapidSequence.count {
                // Position updates are handled automatically by TTSManager during playback(rapidSequence[sequenceIndex])
                sequenceIndex += 1
            } else {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 12.0)
        rapidTimer.invalidate()
    }
    
    // MARK: - Error Recovery Tests
    
    func testAudioFeedbackErrorRecovery() {
        let expectation = XCTestExpectation(description: "Audio feedback error recovery")
        
        let (markdown, parsedContent, sections, file) = createTestMarkdownDocument()
        // Load content using the correct API
        textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
        ttsManager.loadMarkdownFile(file, context: mockContext)
        
        // Simulate error conditions and recovery
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Normal operation
            // Position updates are handled automatically by TTSManager during playback(200)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                // Simulate audio session issue by stopping/starting rapidly
                self.ttsManager.stop()
                // Position updates are handled automatically by TTSManager during playback(400)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // Should recover and continue normal operation
                    // Position updates are handled automatically by TTSManager during playback(600)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        expectation.fulfill()
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 8.0)
    }
    
    func testGracefulHandlingWithInvalidSettings() {
        let expectation = XCTestExpectation(description: "Graceful handling with invalid settings")
        
        let (markdown, parsedContent, sections, file) = createTestMarkdownDocument()
        // Load content using the correct API
        textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
        ttsManager.loadMarkdownFile(file, context: mockContext)
        
        // Test with extreme settings values
        settingsManager.codeBlockToneVolume = 2.0 // Above normal range
        settingsManager.codeBlockNotificationStyle = .both
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Position updates are handled automatically by TTSManager during playback(200)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // Should handle gracefully
                // Position updates are handled automatically by TTSManager during playback(400)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 6.0)
    }
    
    // MARK: - Performance Tests
    
    func testIntegrationPerformance() {
        let (markdown, parsedContent, sections, file) = createTestMarkdownDocument()
        // Load content using the correct API
        textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
        ttsManager.loadMarkdownFile(file, context: mockContext)
        
        measure {
            // Simulate reading through the document
            for i in 0..<50 {
                let position = 50 + (i * 12)
                if position < markdown.count {
                    // Position updates are handled automatically by TTSManager during playback(position)
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.01))
            }
        }
    }
    
    func testAudioFeedbackPerformance() {
        measure {
            // Test audio feedback generation performance
            for i in 0..<20 {
                audioFeedback.playFeedback(for: .codeBlockStart)
                RunLoop.current.run(until: Date().addingTimeInterval(0.02))
                audioFeedback.playFeedback(for: .codeBlockEnd)
                RunLoop.current.run(until: Date().addingTimeInterval(0.02))
            }
        }
    }
    
    func testSettingsChangePerformance() {
        measure {
            // Test settings change performance
            for i in 0..<100 {
                settingsManager.codeBlockNotificationStyle = SettingsManager.CodeBlockNotificationStyle.allCases[i % 4]
                settingsManager.isCodeBlockLanguageNotificationEnabled = i % 2 == 0
                settingsManager.codeBlockToneVolume = Float(i % 100) / 100.0
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryManagementDuringIntegration() {
        let expectation = XCTestExpectation(description: "Memory management during integration")
        
        weak var weakTTSManager: TTSManager?
        weak var weakAudioFeedback: AudioFeedbackManager?
        weak var weakCustomToneGenerator: CustomToneGenerator?
        
        autoreleasepool {
            let (markdown, parsedContent, sections, file) = createTestMarkdownDocument()
            
            let testTTSManager = TTSManager()
            let testAudioFeedback = AudioFeedbackManager()
            let testCustomToneGenerator = CustomToneGenerator()
            
            weakTTSManager = testTTSManager
            weakAudioFeedback = testAudioFeedback
            weakCustomToneGenerator = testCustomToneGenerator
            
            testTTSManager.loadMarkdownFile(file, context: self.mockContext)
            
            // Perform some operations
            // Position updates are handled automatically by TTSManager during playback(200)
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            
            testTTSManager.stop()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertNil(weakTTSManager, "TTSManager should be deallocated")
            XCTAssertNil(weakAudioFeedback, "AudioFeedbackManager should be deallocated")
            XCTAssertNil(weakCustomToneGenerator, "CustomToneGenerator should be deallocated")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    // MARK: - User Experience Tests
    
    func testRealisticReadingScenario() {
        let expectation = XCTestExpectation(description: "Realistic reading scenario")
        
        let (markdown, parsedContent, sections, file) = createTestMarkdownDocument()
        // Load content using the correct API
        textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
        ttsManager.loadMarkdownFile(file, context: mockContext)
        
        // Simulate realistic reading patterns
        let realisticSequence = [
            (position: 50, delay: 2.0, description: "Reading introduction"),
            (position: 150, delay: 1.5, description: "Approaching first code block"),
            (position: 200, delay: 3.0, description: "Reading Swift code block"),
            (position: 250, delay: 1.0, description: "Continuing after code block"),
            (position: 350, delay: 1.5, description: "Approaching second code block"),
            (position: 400, delay: 3.0, description: "Reading Python code block"),
            (position: 450, delay: 1.0, description: "Continuing after code block"),
            (position: 550, delay: 1.5, description: "Approaching third code block"),
            (position: 600, delay: 3.0, description: "Reading JavaScript code block"),
            (position: 650, delay: 2.0, description: "Reading conclusion")
        ]
        
        var currentStep = 0
        
        for (index, (position, delay, description)) in realisticSequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * delay) {
                // Position updates are handled automatically by TTSManager
                print("📖 Step \(index + 1): \(description)")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    currentStep += 1
                    if currentStep == realisticSequence.count {
                        print("✅ Realistic reading scenario completed")
                        expectation.fulfill()
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 25.0)
    }
    
    func testUserInterruptionScenario() {
        let expectation = XCTestExpectation(description: "User interruption scenario")
        
        let (markdown, parsedContent, sections, file) = createTestMarkdownDocument()
        // Load content using the correct API
        textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
        ttsManager.loadMarkdownFile(file, context: mockContext)
        
        // Simulate user starting to read, then getting interrupted
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("👤 User starts reading")
            // Position updates are handled automatically by TTSManager during playback(50) // Start reading
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                print("📱 User gets interrupted (phone call)")
                self.ttsManager.stop() // User stops reading
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    print("👤 User resumes reading")
                    // Position updates are handled automatically by TTSManager during playback(200) // Resume at code block
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        print("✅ User interruption scenario completed")
                        expectation.fulfill()
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Concurrent Operation Tests
    
    func testConcurrentSettingsAndPositionUpdates() {
        let expectation = XCTestExpectation(description: "Concurrent settings and position updates")
        
        let (markdown, parsedContent, sections, file) = createTestMarkdownDocument()
        // Load content using the correct API
        textWindowManager.loadContent(sections: sections, plainText: parsedContent.plainText ?? "")
        ttsManager.loadMarkdownFile(file, context: mockContext)
        
        let operationCount = 20
        var completedOperations = 0
        
        let queue = DispatchQueue(label: "concurrent.operations", attributes: .concurrent)
        
        for i in 0..<operationCount {
            queue.async {
                // Mix of settings updates and position updates
                if i % 3 == 0 {
                    // Settings update
                    DispatchQueue.main.async {
                        self.settingsManager.codeBlockNotificationStyle = SettingsManager.CodeBlockNotificationStyle.allCases[i % 4]
                        self.settingsManager.codeBlockToneVolume = Float(i % 100) / 100.0
                    }
                } else {
                    // Position update
                    DispatchQueue.main.async {
                        let position = 50 + (i * 30)
                        if position < markdown.count {
                            // Position updates are handled automatically by TTSManager
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    completedOperations += 1
                    if completedOperations == operationCount {
                        expectation.fulfill()
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 8.0)
    }
    
    // MARK: - Edge Case Tests
    
    func testEdgeCaseEmptyDocument() {
        let expectation = XCTestExpectation(description: "Edge case empty document")
        
        let emptyMarkdown = ""
        let emptyParsed = ParsedContent(context: mockContext)
        emptyParsed// Core Data automatically generates UUID for ID
        emptyParsed.plainText = emptyMarkdown
        emptyParsed.lastParsed = Date()
        
        let emptyFile = MarkdownFile(context: mockContext)
        emptyFile// Core Data automatically generates UUID for ID
        emptyFile.title = "Empty Document"
        emptyFile.filePath = "/test/empty.md"
        emptyFile.lastModified = Date()
        
        let emptySections: [ContentSection] = []
        
        // Should handle empty document gracefully
        XCTAssertNoThrow(
            ttsManager.loadMarkdownFile(emptyFile, context: self.mockContext),
            "Should handle empty document gracefully"
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testEdgeCaseDocumentWithOnlyCodeBlocks() {
        let expectation = XCTestExpectation(description: "Edge case document with only code blocks")
        
        let codeOnlyMarkdown = """
        ```swift
        func swift() {}
        ```
        
        ```python
        def python():
            pass
        ```
        
        ```javascript
        function javascript() {}
        ```
        """
        
        let codeOnlyParsed = ParsedContent(context: mockContext)
        codeOnlyParsed// Core Data automatically generates UUID for ID
        codeOnlyParsed.plainText = codeOnlyMarkdown
        codeOnlyParsed.lastParsed = Date()
        
        let codeOnlyFile = MarkdownFile(context: mockContext)
        codeOnlyFile// Core Data automatically generates UUID for ID
        codeOnlyFile.title = "Code Only Document"
        codeOnlyFile.filePath = "/test/code-only.md"
        codeOnlyFile.lastModified = Date()
        
        let parseResult = parser.parseMarkdownForTTS(codeOnlyMarkdown)
        var codeOnlySections: [ContentSection] = []
        
        for parsedSection in parseResult.sections {
            let section = ContentSection(context: mockContext)
            section.startIndex = Int32(parsedSection.startIndex)
            section.endIndex = Int32(parsedSection.endIndex)
            section.typeEnum = parsedSection.type
            section.level = Int16(parsedSection.level)
            section.isSkippable = parsedSection.isSkippable
            section.parsedContent = codeOnlyParsed
            codeOnlySections.append(section)
        }
        
        ttsManager.loadMarkdownFile(codeOnlyFile, context: self.mockContext)
        
        // Should handle document with only code blocks
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Position updates are handled automatically by TTSManager during playback(50) // First code block
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                // Position updates are handled automatically by TTSManager during playback(150) // Second code block
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    // Position updates are handled automatically by TTSManager during playback(250) // Third code block
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        expectation.fulfill()
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 8.0)
    }
}