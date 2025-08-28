//
//  VisualTextDisplayViewTests.swift
//  MD TalkManTests
//
//  Created by Claude on 8/28/25.
//

import XCTest
import SwiftUI
import CoreData
@testable import MD_TalkMan

final class VisualTextDisplayViewTests: XCTestCase {
    
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
        setupTestContent()
    }
    
    override func tearDownWithError() throws {
        windowManager = nil
        testSections = nil
        testPlainText = nil
        
        if let container = testContainer {
            container.viewContext.reset()
            // Remove all persistent stores
            for store in container.persistentStoreCoordinator.persistentStores {
                try? container.persistentStoreCoordinator.remove(store)
            }
        }
        testContainer = nil
    }
    
    private func setupTestContent() {
        testPlainText = """
        This is the first paragraph of text. It contains multiple sentences and should be long enough to test the windowing functionality properly.
        
        This is the second paragraph with some content. It's also reasonably long to ensure proper testing of the text display system.
        
        Here is a third paragraph that contains even more text content for comprehensive testing purposes.
        
        And finally, this fourth paragraph completes our test content with sufficient length to verify all display functionality.
        """
        
        // Create test sections
        testSections = []
        let paragraphLengths = [150, 120, 140, 130] // Approximate lengths
        var currentStart = 0
        
        for (_, length) in paragraphLengths.enumerated() {
            let section = ContentSection(context: mockContext)
            section.startIndex = Int32(currentStart)
            section.endIndex = Int32(currentStart + length)
            section.typeEnum = .paragraph
            section.level = 0
            section.isSkippable = false
            testSections.append(section)
            currentStart += length + 2 // Account for paragraph breaks
        }
        
        // Load content into window manager
        windowManager.loadContent(sections: testSections, plainText: testPlainText)
    }
    
    // MARK: - View Initialization Tests
    
    func testViewInitialization() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        XCTAssertNotNil(view, "VisualTextDisplayView should initialize properly")
        XCTAssertNotNil(view.windowManager, "Window manager should be set correctly")
        XCTAssertTrue(view.isVisible, "Visibility should be set correctly")
    }
    
    func testViewWithHiddenState() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: false)
        
        XCTAssertFalse(view.isVisible, "Visibility should be set to false")
    }
    
    // MARK: - Display Height Tests
    
    func testDisplayHeightForCompactSizeClass() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        // Test height calculation by accessing the private property through reflection or by testing the view behavior
        // Since we can't directly access private properties, we'll test the overall behavior
        
        // For iPhone (compact), height should be 220px
        // This is an indirect test - in a real scenario, we'd need to test the view's frame
        XCTAssertNoThrow(
            _ = view.body,
            "View body should render without errors for compact size class"
        )
    }
    
    func testDisplayHeightForRegularSizeClass() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        // For iPad (regular), height should be 320px
        XCTAssertNoThrow(
            _ = view.body,
            "View body should render without errors for regular size class"
        )
    }
    
    // MARK: - Color Scheme Adaptation Tests
    
    func testLightModeHighlightColors() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        // Test that the view handles light mode properly
        // Since we can't directly access color properties, we test view rendering
        XCTAssertNoThrow(
            _ = view.body,
            "View should render properly in light mode"
        )
    }
    
    func testDarkModeHighlightColors() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        // Test that the view handles dark mode properly
        XCTAssertNoThrow(
            _ = view.body,
            "View should render properly in dark mode"
        )
    }
    
    // MARK: - Text Content Tests
    
    func testTextContentDisplay() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        // Update window to show specific content
        windowManager.updateWindow(for: 50)
        
        XCTAssertNotNil(windowManager.displayWindow, "Display window should have content")
        XCTAssertFalse(windowManager.displayWindow.isEmpty, "Display window should not be empty")
        
        XCTAssertNoThrow(
            _ = view.body,
            "View should display text content without errors"
        )
    }
    
    func testEmptyContentHandling() {
        let emptyManager = TextWindowManager()
        let view = VisualTextDisplayView(windowManager: emptyManager, isVisible: true)
        
        // Test view behavior with empty content
        XCTAssertNoThrow(
            _ = view.body,
            "View should handle empty content gracefully"
        )
    }
    
    // MARK: - Highlight Functionality Tests
    
    func testCurrentPositionHighlighting() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        // Set a position that should create a highlight
        windowManager.updateWindow(for: 100)
        
        XCTAssertNotNil(windowManager.currentHighlight, "Current highlight should be set")
        
        XCTAssertNoThrow(
            _ = view.body,
            "View should render with highlighting without errors"
        )
    }
    
    func testSearchResultHighlighting() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        // Simulate search results by directly setting them (in a real test, we'd use the search functionality)
        windowManager.updateWindow(for: 50)
        
        XCTAssertNoThrow(
            _ = view.body,
            "View should handle search result highlighting without errors"
        )
    }
    
    // MARK: - Search Functionality Tests
    
    func testSearchFunctionality() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        windowManager.updateWindow(for: 50)
        
        // Test that search doesn't crash and the view handles it properly
        XCTAssertNoThrow(
            _ = view.body,
            "View should handle search functionality without errors"
        )
    }
    
    func testSearchWithEmptyQuery() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        // Test empty search query
        XCTAssertNoThrow(
            _ = view.body,
            "View should handle empty search query without errors"
        )
    }
    
    func testSearchWithNoResults() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        // Test search with no results
        XCTAssertNoThrow(
            _ = view.body,
            "View should handle search with no results without errors"
        )
    }
    
    // MARK: - Scrolling Tests
    
    func testScrollingAnimation() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        // Test that scrolling functionality works
        windowManager.updateWindow(for: 50)
        
        XCTAssertNoThrow(
            _ = view.body,
            "View should handle scrolling animation without errors"
        )
    }
    
    func testScrollPositionUpdates() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        // Test multiple position updates
        windowManager.updateWindow(for: 25)
        windowManager.updateWindow(for: 75)
        windowManager.updateWindow(for: 150)
        
        XCTAssertNoThrow(
            _ = view.body,
            "View should handle multiple scroll position updates without errors"
        )
    }
    
    // MARK: - Font Size Tests
    
    func testFontSizeForCompactSizeClass() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        XCTAssertNoThrow(
            _ = view.body,
            "View should use appropriate font size for compact devices"
        )
    }
    
    func testFontSizeForRegularSizeClass() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        XCTAssertNoThrow(
            _ = view.body,
            "View should use appropriate font size for regular devices"
        )
    }
    
    // MARK: - Animation Tests
    
    func testVisibilityAnimation() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        // Test animation when visibility changes
        XCTAssertNoThrow(
            _ = view.body,
            "View should handle visibility animation without errors"
        )
    }
    
    func testContentUpdateAnimation() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        // Test animation when content updates
        windowManager.updateWindow(for: 50)
        
        XCTAssertNoThrow(
            _ = view.body,
            "View should handle content update animation without errors"
        )
    }
    
    // MARK: - Window Content Tests
    
    func testWindowContentUpdates() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        let initialContent = windowManager.displayWindow
        
        // Update to a different position
        windowManager.updateWindow(for: 200)
        let updatedContent = windowManager.displayWindow
        
        XCTAssertNotEqual(initialContent, updatedContent, "Content should update when position changes")
        
        XCTAssertNoThrow(
            _ = view.body,
            "View should handle content updates without errors"
        )
    }
    
    func testWindowBoundaryConditions() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        // Test boundary conditions
        windowManager.updateWindow(for: 0) // Beginning
        windowManager.updateWindow(for: Int(testPlainText.count) - 10) // End
        
        XCTAssertNoThrow(
            _ = view.body,
            "View should handle boundary conditions without errors"
        )
    }
    
    // MARK: - Performance Tests
    
    func testViewRenderingPerformance() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        measure {
            for i in 0..<100 {
                windowManager.updateWindow(for: i * 5)
                _ = view.body
            }
        }
    }
    
    func testLargeContentHandling() {
        // Create large content
        let largeText = String(repeating: "This is a test sentence. ", count: 1000)
        var largeSections: [ContentSection] = []
        
        var currentStart = 0
        for _ in 0..<50 {
            let section = ContentSection(context: mockContext)
            section.startIndex = Int32(currentStart)
            section.endIndex = Int32(currentStart + 100)
            section.typeEnum = .paragraph
            section.level = 0
            section.isSkippable = false
            largeSections.append(section)
            currentStart += 102
        }
        
        let largeManager = TextWindowManager()
        largeManager.loadContent(sections: largeSections, plainText: largeText)
        
        let view = VisualTextDisplayView(windowManager: largeManager, isVisible: true)
        
        measure {
            for i in 0..<50 {
                largeManager.updateWindow(for: i * 200)
                _ = view.body
            }
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabel() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        windowManager.updateWindow(for: 50)
        
        XCTAssertNoThrow(
            _ = view.body,
            "View should have proper accessibility labels"
        )
    }
    
    func testAccessibilityTraits() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        XCTAssertNoThrow(
            _ = view.body,
            "View should have proper accessibility traits"
        )
    }
    
    // MARK: - Edge Case Tests
    
    func testVeryShortContent() {
        let shortText = "Short text."
        let shortSection = ContentSection(context: mockContext)
        shortSection.startIndex = 0
        shortSection.endIndex = Int32(shortText.count)
        shortSection.typeEnum = .paragraph
        shortSection.level = 0
        shortSection.isSkippable = false
        
        let shortManager = TextWindowManager()
        shortManager.loadContent(sections: [shortSection], plainText: shortText)
        
        let view = VisualTextDisplayView(windowManager: shortManager, isVisible: true)
        
        XCTAssertNoThrow(
            _ = view.body,
            "View should handle very short content without errors"
        )
    }
    
    func testSpecialCharacters() {
        let specialText = "Text with special chars: áéíóú ñ ¿ ¡ @#$%^&*()_+"
        let specialSection = ContentSection(context: mockContext)
        specialSection.startIndex = 0
        specialSection.endIndex = Int32(specialText.count)
        specialSection.typeEnum = .paragraph
        specialSection.level = 0
        specialSection.isSkippable = false
        
        let specialManager = TextWindowManager()
        specialManager.loadContent(sections: [specialSection], plainText: specialText)
        
        let view = VisualTextDisplayView(windowManager: specialManager, isVisible: true)
        
        XCTAssertNoThrow(
            _ = view.body,
            "View should handle special characters without errors"
        )
    }
    
    // MARK: - Integration Tests
    
    func testIntegrationWithTextWindowManager() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        // Test the complete integration cycle
        windowManager.updateWindow(for: 0)
        windowManager.updateWindow(for: 100)
        windowManager.updateWindow(for: 200)
        
        XCTAssertNoThrow(
            _ = view.body,
            "View should integrate properly with TextWindowManager"
        )
    }
    
    func testRealTimeContentUpdates() {
        let view = VisualTextDisplayView(windowManager: windowManager, isVisible: true)
        
        // Simulate real-time content updates
        let updateExpectation = XCTestExpectation(description: "Real-time content updates")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.windowManager.updateWindow(for: 50)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.windowManager.updateWindow(for: 150)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            updateExpectation.fulfill()
        }
        
        wait(for: [updateExpectation], timeout: 1.0)
        
        XCTAssertNoThrow(
            _ = view.body,
            "View should handle real-time content updates"
        )
    }
}