//
//  TextWindowManagerTests.swift
//  MD TalkManTests
//
//  Created by Claude on 8/16/25.
//

import XCTest
import CoreData
@testable import MD_TalkMan

final class TextWindowManagerTests: XCTestCase {
    
    var windowManager: TextWindowManager!
    var mockContext: NSManagedObjectContext!
    var testContainer: NSPersistentContainer!
    var testSections: [ContentSection]!
    var testPlainText: String!
    
    override func setUpWithError() throws {
        // Create in-memory Core Data stack for testing
        testContainer = NSPersistentContainer(name: "DataModel")
        let description = testContainer.persistentStoreDescriptions.first!
        description.url = URL(fileURLWithPath: "/dev/null")
        
        testContainer.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        
        mockContext = testContainer.viewContext
        windowManager = TextWindowManager()
        
        // Create test content
        createTestContent()
    }
    
    override func tearDownWithError() throws {
        windowManager = nil
        mockContext = nil
        testContainer = nil
        testSections = nil
        testPlainText = nil
    }
    
    // MARK: - Test Content Creation
    
    private func createTestContent() {
        testPlainText = """
        This is the first paragraph with some introductory content about the topic we're discussing.
        
        This is the second paragraph that continues the discussion with more detailed information and examples.
        
        This is the third paragraph which provides additional context and concludes the section with important points.
        
        This is the fourth paragraph that starts a new section with different information and perspectives.
        
        This is the fifth and final paragraph that wraps up all the content with a comprehensive summary.
        """
        
        // Create test sections matching the text above
        testSections = [
            createTestSection(start: 0, end: 102, type: .paragraph, level: 0), // First paragraph
            createTestSection(start: 104, end: 211, type: .paragraph, level: 0), // Second paragraph
            createTestSection(start: 213, end: 319, type: .paragraph, level: 0), // Third paragraph
            createTestSection(start: 321, end: 430, type: .paragraph, level: 0), // Fourth paragraph
            createTestSection(start: 432, end: 541, type: .paragraph, level: 0)  // Fifth paragraph
        ]
    }
    
    private func createTestSection(start: Int, end: Int, type: ContentSectionType, level: Int) -> ContentSection {
        let section = ContentSection(context: mockContext)
        section.startIndex = Int32(start)
        section.endIndex = Int32(end)
        section.typeEnum = type
        section.level = Int16(level)
        section.isSkippable = false
        return section
    }
    
    // MARK: - Content Loading Tests
    
    func testContentLoading() throws {
        // Test initial state
        XCTAssertEqual(windowManager.displayWindow, "")
        XCTAssertNil(windowManager.currentHighlight)
        XCTAssertEqual(windowManager.currentSectionIndex, 0)
        
        // Load content
        windowManager.loadContent(sections: testSections, plainText: testPlainText)
        
        // Verify content loaded
        XCTAssertGreaterThan(windowManager.displayWindow.count, 0)
        XCTAssertEqual(windowManager.getTotalSections(), 5)
    }
    
    func testEmptyContentHandling() throws {
        // Test with empty content
        windowManager.loadContent(sections: [], plainText: "")
        
        XCTAssertEqual(windowManager.displayWindow, "")
        XCTAssertNil(windowManager.currentHighlight)
        XCTAssertEqual(windowManager.getTotalSections(), 0)
    }
    
    // MARK: - Window Update Tests
    
    func testWindowUpdateFirstSection() throws {
        windowManager.loadContent(sections: testSections, plainText: testPlainText)
        
        // Update to position in first section
        windowManager.updateWindow(for: 50)
        
        // Should display first 3 sections (window size = 3)
        XCTAssertGreaterThan(windowManager.displayWindow.count, 0)
        XCTAssertEqual(windowManager.currentSectionIndex, 0)
        XCTAssertNotNil(windowManager.currentHighlight)
        
        // Display should contain content from multiple sections
        XCTAssertTrue(windowManager.displayWindow.contains("first paragraph"))
        XCTAssertTrue(windowManager.displayWindow.contains("second paragraph"))
    }
    
    func testWindowUpdateMiddleSection() throws {
        windowManager.loadContent(sections: testSections, plainText: testPlainText)
        
        // Update to position in middle section (section 2, index 1)
        windowManager.updateWindow(for: 250)
        
        XCTAssertEqual(windowManager.currentSectionIndex, 2)
        
        // Should display sections around current position
        XCTAssertTrue(windowManager.displayWindow.contains("second paragraph"))
        XCTAssertTrue(windowManager.displayWindow.contains("third paragraph"))
        XCTAssertTrue(windowManager.displayWindow.contains("fourth paragraph"))
    }
    
    func testWindowUpdateLastSection() throws {
        windowManager.loadContent(sections: testSections, plainText: testPlainText)
        
        // Update to position in last section
        windowManager.updateWindow(for: 500)
        
        XCTAssertEqual(windowManager.currentSectionIndex, 4)
        
        // Should display last few sections
        XCTAssertTrue(windowManager.displayWindow.contains("fourth paragraph"))
        XCTAssertTrue(windowManager.displayWindow.contains("fifth"))
    }
    
    // MARK: - Highlighting Tests
    
    func testHighlightCalculation() throws {
        windowManager.loadContent(sections: testSections, plainText: testPlainText)
        windowManager.updateWindow(for: 50)
        
        let highlight = windowManager.currentHighlight
        XCTAssertNotNil(highlight)
        
        if let highlight = highlight {
            XCTAssertGreaterThanOrEqual(highlight.location, 0)
            XCTAssertGreaterThan(highlight.length, 0)
            XCTAssertLessThanOrEqual(highlight.location + highlight.length, windowManager.displayWindow.count)
        }
    }
    
    func testHighlightBoundaries() throws {
        windowManager.loadContent(sections: testSections, plainText: testPlainText)
        
        // Test highlight at beginning
        windowManager.updateWindow(for: 0)
        let highlightStart = windowManager.currentHighlight
        XCTAssertNotNil(highlightStart)
        XCTAssertEqual(highlightStart?.location, 0)
        
        // Test highlight at end of content
        windowManager.updateWindow(for: testPlainText.count - 10)
        let highlightEnd = windowManager.currentHighlight
        XCTAssertNotNil(highlightEnd)
    }
    
    // MARK: - Search Functionality Tests
    
    func testSearchInWindow() throws {
        windowManager.loadContent(sections: testSections, plainText: testPlainText)
        windowManager.updateWindow(for: 50)
        
        // Search for common word
        let results = windowManager.searchInWindow("paragraph")
        XCTAssertGreaterThan(results.count, 0)
        
        // Verify search results are valid ranges
        for result in results {
            XCTAssertGreaterThanOrEqual(result.location, 0)
            XCTAssertGreaterThan(result.length, 0)
            XCTAssertLessThanOrEqual(result.location + result.length, windowManager.displayWindow.count)
        }
    }
    
    func testSearchCaseInsensitive() throws {
        windowManager.loadContent(sections: testSections, plainText: testPlainText)
        windowManager.updateWindow(for: 50)
        
        let resultsLower = windowManager.searchInWindow("this")
        let resultsUpper = windowManager.searchInWindow("THIS")
        let resultsMixed = windowManager.searchInWindow("This")
        
        // All should return same number of results (case insensitive)
        XCTAssertEqual(resultsLower.count, resultsUpper.count)
        XCTAssertEqual(resultsLower.count, resultsMixed.count)
        XCTAssertGreaterThan(resultsLower.count, 0)
    }
    
    func testSearchEmptyResults() throws {
        windowManager.loadContent(sections: testSections, plainText: testPlainText)
        windowManager.updateWindow(for: 50)
        
        let results = windowManager.searchInWindow("xyz123notfound")
        XCTAssertEqual(results.count, 0)
        
        let emptyResults = windowManager.searchInWindow("")
        XCTAssertEqual(emptyResults.count, 0)
    }
    
    // MARK: - Section Navigation Tests
    
    func testSectionNavigation() throws {
        windowManager.loadContent(sections: testSections, plainText: testPlainText)
        
        // Navigate to specific section
        let position = windowManager.navigateToSection(2)
        XCTAssertNotNil(position)
        XCTAssertEqual(windowManager.currentSectionIndex, 2)
        
        if let position = position {
            XCTAssertEqual(position, 213) // Start of third section
        }
    }
    
    func testSectionNavigationBoundaries() throws {
        windowManager.loadContent(sections: testSections, plainText: testPlainText)
        
        // Test invalid section indices
        let negativeResult = windowManager.navigateToSection(-1)
        XCTAssertNil(negativeResult)
        
        let tooHighResult = windowManager.navigateToSection(100)
        XCTAssertNil(tooHighResult)
        
        // Test valid boundaries
        let firstSection = windowManager.navigateToSection(0)
        XCTAssertNotNil(firstSection)
        XCTAssertEqual(firstSection, 0)
        
        let lastSection = windowManager.navigateToSection(4)
        XCTAssertNotNil(lastSection)
        XCTAssertEqual(lastSection, 432)
    }
    
    func testGetCurrentSectionInfo() throws {
        windowManager.loadContent(sections: testSections, plainText: testPlainText)
        windowManager.updateWindow(for: 250) // Should be in section 2
        
        let sectionInfo = windowManager.getCurrentSectionInfo()
        XCTAssertEqual(sectionInfo.type, .paragraph)
        XCTAssertEqual(sectionInfo.level, 0)
        XCTAssertFalse(sectionInfo.isSkippable)
    }
    
    // MARK: - Performance Tests
    
    func testLargeContentHandling() throws {
        // Create large content for performance testing
        let largeText = String(repeating: "This is a performance test paragraph with sufficient content to test large document handling. ", count: 100)
        let largeSections = (0..<50).map { index in
            createTestSection(start: index * 100, end: (index + 1) * 100, type: .paragraph, level: 0)
        }
        
        // Test should complete quickly
        let startTime = CFAbsoluteTimeGetCurrent()
        windowManager.loadContent(sections: largeSections, plainText: largeText)
        windowManager.updateWindow(for: 2500)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertLessThan(timeElapsed, 1.0) // Should complete in less than 1 second
        XCTAssertGreaterThan(windowManager.displayWindow.count, 0)
    }
    
    func testWindowSizeLimit() throws {
        windowManager.loadContent(sections: testSections, plainText: testPlainText)
        windowManager.updateWindow(for: 50)
        
        // Display window should be limited to reasonable size
        XCTAssertLessThanOrEqual(windowManager.displayWindow.count, 2000) // maxDisplayLength
    }
    
    // MARK: - Edge Case Tests
    
    func testInvalidPositions() throws {
        windowManager.loadContent(sections: testSections, plainText: testPlainText)
        
        // Test position beyond content
        windowManager.updateWindow(for: 10000)
        XCTAssertNotNil(windowManager.displayWindow) // Should handle gracefully
        
        // Test negative position
        windowManager.updateWindow(for: -100)
        XCTAssertNotNil(windowManager.displayWindow) // Should handle gracefully
    }
    
    func testDebugInfo() throws {
        windowManager.loadContent(sections: testSections, plainText: testPlainText)
        windowManager.updateWindow(for: 50)
        
        let debugInfo = windowManager.getDebugInfo()
        XCTAssertTrue(debugInfo.contains("TextWindowManager Debug"))
        XCTAssertTrue(debugInfo.contains("Sections: 5"))
        XCTAssertTrue(debugInfo.contains("Current Position: 50"))
    }
}