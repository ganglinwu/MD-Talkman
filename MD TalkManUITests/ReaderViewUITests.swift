//
//  ReaderViewUITests.swift
//  MD TalkManUITests
//
//  Created by Claude on 8/14/25.
//

import XCTest
@testable import MD_TalkMan

final class ReaderViewUITests: XCTestCase {

    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Navigation Tests
    
    func testNavigationToReaderView() throws {
        // Wait for main view to load
        XCTAssertTrue(app.navigationBars["Repositories"].waitForExistence(timeout: 5))
        
        // If there are repositories, tap the first one
        let repositoryList = app.lists.firstMatch
        if repositoryList.exists {
            let firstRepository = repositoryList.cells.firstMatch
            if firstRepository.exists {
                firstRepository.tap()
                
                // Should navigate to repository detail
                XCTAssertTrue(app.navigationBars.element.waitForExistence(timeout: 3))
                
                // If there are files, tap the first one
                let fileList = app.lists.firstMatch
                if fileList.exists {
                    let firstFile = fileList.cells.firstMatch
                    if firstFile.exists {
                        firstFile.tap()
                        
                        // Should navigate to reader view
                        XCTAssertTrue(app.buttons["play.fill"].waitForExistence(timeout: 3))
                    }
                }
            }
        }
    }
    
    // MARK: - Reader View Control Tests
    
    func testReaderViewControls() throws {
        // Navigate to reader view first
        navigateToReaderView()
        
        // Test play button exists
        let playButton = app.buttons["play.fill"]
        XCTAssertTrue(playButton.exists)
        
        // Test speed slider exists
        let speedSlider = app.sliders.firstMatch
        XCTAssertTrue(speedSlider.exists)
        
        // Test rewind button exists  
        let rewindButton = app.buttons["gobackward.5"]
        XCTAssertTrue(rewindButton.exists)
        
        // Test stop button exists
        let stopButton = app.buttons["stop.fill"]
        XCTAssertTrue(stopButton.exists)
        
        // Test navigation buttons exist
        XCTAssertTrue(app.buttons["Previous Section"].exists)
        XCTAssertTrue(app.buttons["Next Section"].exists)
    }
    
    func testPlaybackControls() throws {
        navigateToReaderView()
        
        let playButton = app.buttons["play.fill"]
        let stopButton = app.buttons["stop.fill"]
        let rewindButton = app.buttons["gobackward.5"]
        
        // Initially, stop button should be disabled
        XCTAssertFalse(stopButton.isEnabled)
        
        // Tap play button
        if playButton.exists && playButton.isEnabled {
            playButton.tap()
            
            // After tapping play, the button might change to pause
            // and stop should become enabled
            let pauseButton = app.buttons["pause.fill"]
            
            // Give some time for state change
            usleep(500000) // 0.5 seconds
            
            // Stop button should now be enabled
            XCTAssertTrue(stopButton.isEnabled)
            
            // Test rewind
            if rewindButton.isEnabled {
                rewindButton.tap()
            }
            
            // Test stop
            stopButton.tap()
            
            // After stopping, play button should be available again
            XCTAssertTrue(app.buttons["play.fill"].waitForExistence(timeout: 2))
        }
    }
    
    func testSpeedControl() throws {
        navigateToReaderView()
        
        let speedSlider = app.sliders.firstMatch
        XCTAssertTrue(speedSlider.exists)
        
        // Test adjusting speed
        speedSlider.adjust(toNormalizedSliderPosition: 0.8) // Increase speed
        speedSlider.adjust(toNormalizedSliderPosition: 0.2) // Decrease speed
        speedSlider.adjust(toNormalizedSliderPosition: 0.5) // Reset to middle
    }
    
    func testSectionNavigation() throws {
        navigateToReaderView()
        
        let nextSectionButton = app.buttons["Next Section"]
        let previousSectionButton = app.buttons["Previous Section"]
        
        // Initially, previous section might be disabled
        // (depends on if we're at the beginning)
        
        // Try to navigate to next section
        if nextSectionButton.isEnabled {
            nextSectionButton.tap()
            
            // Previous section should now be enabled
            XCTAssertTrue(previousSectionButton.isEnabled)
            
            // Navigate back
            previousSectionButton.tap()
        }
    }
    
    func testSkipFunctionality() throws {
        navigateToReaderView()
        
        // Navigate through sections to find a skippable one
        let nextSectionButton = app.buttons["Next Section"]
        let skipButton = app.buttons["Skip Technical Section"]
        
        // Navigate through sections to find a skippable one
        for _ in 0..<5 {
            if skipButton.exists {
                // Found a skippable section, test skip functionality
                skipButton.tap()
                
                // Should advance to next section
                break
            } else if nextSectionButton.isEnabled {
                nextSectionButton.tap()
                // Wait a moment for UI to update
                usleep(200000) // 0.2 seconds
            } else {
                break
            }
        }
    }
    
    // MARK: - Section Information Display Tests
    
    func testSectionInfoDisplay() throws {
        navigateToReaderView()
        
        // Check that section info is displayed
        // Look for common section indicators
        let possibleSectionTypes = ["Header", "Paragraph", "Code Block", "List", "Quote"]
        
        var foundSectionType = false
        for sectionType in possibleSectionTypes {
            if app.staticTexts[sectionType].exists {
                foundSectionType = true
                break
            }
        }
        
        // Should show some section information
        XCTAssertTrue(foundSectionType, "Should display section type information")
        
        // Test section level indicators for headers
        if app.staticTexts["Header"].exists {
            // Look for level indicators
            let levelIndicators = ["Level 1", "Level 2", "Level 3"]
            for level in levelIndicators {
                if app.staticTexts[level].exists {
                    break
                }
            }
        }
        
        // Test skippable section indicator
        if app.staticTexts["Skippable"].exists {
            XCTAssertTrue(app.buttons["Skip Technical Section"].exists)
        }
    }
    
    func testFileInfoDisplay() throws {
        navigateToReaderView()
        
        // Should display file title
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Test' OR label CONTAINS 'Sample' OR label CONTAINS 'Getting Started'")).firstMatch.exists)
        
        // Should display sync status
        let syncStatuses = ["Local Only", "Synced", "Needs Sync", "Conflicted"]
        var foundSyncStatus = false
        
        for status in syncStatuses {
            if app.staticTexts[status].exists {
                foundSyncStatus = true
                break
            }
        }
        
        XCTAssertTrue(foundSyncStatus, "Should display sync status")
        
        // Should show playback status
        let playbackStatuses = ["Ready to Play", "Playing", "Paused", "Preparing..."]
        var foundPlaybackStatus = false
        
        for status in playbackStatuses {
            if app.staticTexts[status].exists {
                foundPlaybackStatus = true
                break
            }
        }
        
        XCTAssertTrue(foundPlaybackStatus, "Should display playback status")
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() throws {
        navigateToReaderView()
        
        // Test that main controls have accessibility labels
        let playButton = app.buttons["play.fill"]
        XCTAssertTrue(playButton.isHittable)
        
        let speedSlider = app.sliders.firstMatch
        XCTAssertTrue(speedSlider.isHittable)
        
        let rewindButton = app.buttons["gobackward.5"]
        XCTAssertTrue(rewindButton.isHittable)
        
        // Test navigation buttons
        XCTAssertTrue(app.buttons["Previous Section"].isHittable)
        XCTAssertTrue(app.buttons["Next Section"].isHittable)
    }
    
    // MARK: - Error State Tests
    
    func testEmptyContentHandling() throws {
        // This test would require creating a file with no content
        // For now, we'll test that the app doesn't crash with minimal content
        navigateToReaderView()
        
        // App should still show controls even with minimal or no content
        XCTAssertTrue(app.buttons["play.fill"].exists)
        XCTAssertTrue(app.buttons["stop.fill"].exists)
    }
    
    // MARK: - Helper Methods
    
    private func navigateToReaderView() {
        // Wait for main view
        XCTAssertTrue(app.navigationBars["Repositories"].waitForExistence(timeout: 5))
        
        // Navigate to first repository if it exists
        let repositoryList = app.lists.firstMatch
        if repositoryList.exists && repositoryList.cells.count > 0 {
            repositoryList.cells.firstMatch.tap()
            
            // Navigate to first file if it exists
            let fileList = app.lists.firstMatch
            if fileList.waitForExistence(timeout: 3) && fileList.cells.count > 0 {
                fileList.cells.firstMatch.tap()
                
                // Wait for reader view to load
                XCTAssertTrue(app.buttons["play.fill"].waitForExistence(timeout: 3))
            }
        }
    }
    
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}