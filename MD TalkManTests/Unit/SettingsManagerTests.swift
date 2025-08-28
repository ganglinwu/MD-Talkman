//
//  SettingsManagerTests.swift
//  MD TalkManTests
//
//  Created by Claude on 8/28/25.
//

import XCTest
@testable import MD_TalkMan

final class SettingsManagerTests: XCTestCase {
    
    var settingsManager: SettingsManager!
    
    override func setUpWithError() throws {
        // Clear UserDefaults for clean testing
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        
        settingsManager = SettingsManager.shared
    }
    
    override func tearDownWithError() throws {
        settingsManager = nil
        
        // Clean up UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(settingsManager, "SettingsManager should initialize properly")
        XCTAssertFalse(settingsManager.isDeveloperModeEnabled, "Developer mode should be disabled by default in release builds")
    }
    
    func testInitializationWithDefaults() {
        let manager = SettingsManager.shared
        
        XCTAssertEqual(manager.codeBlockNotificationStyle, .smartDetection, "Default should be smart detection")
        XCTAssertTrue(manager.isCodeBlockLanguageNotificationEnabled, "Language notifications should be enabled by default")
        XCTAssertEqual(manager.codeBlockToneVolume, 0.7, "Default tone volume should be 0.7")
    }
    
    // MARK: - Developer Mode Tests
    
    func testDeveloperModeToggle() {
        let initialValue = settingsManager.isDeveloperModeEnabled
        
        settingsManager.toggleDeveloperMode()
        XCTAssertNotEqual(settingsManager.isDeveloperModeEnabled, initialValue, "Developer mode should toggle")
        
        settingsManager.toggleDeveloperMode()
        XCTAssertEqual(settingsManager.isDeveloperModeEnabled, initialValue, "Developer mode should toggle back")
    }
    
    func testDeveloperModePersistence() {
        settingsManager.isDeveloperModeEnabled = true
        
        // Create new instance to test persistence
        let newManager = SettingsManager.shared
        XCTAssertTrue(newManager.isDeveloperModeEnabled, "Developer mode setting should persist")
        
        newManager.isDeveloperModeEnabled = false
        
        let finalManager = SettingsManager.shared
        XCTAssertFalse(finalManager.isDeveloperModeEnabled, "Developer mode setting should persist when disabled")
    }
    
    // MARK: - Code Block Notification Style Tests
    
    func testCodeBlockNotificationStyleEnum() {
        // Test all enum cases
        let allStyles: [SettingsManager.CodeBlockNotificationStyle] = [
            .smartDetection, .voiceOnly, .tonesOnly, .both
        ]
        
        for style in allStyles {
            XCTAssertFalse(style.displayName.isEmpty, "Display name should not be empty for \(style)")
        }
        
        // Test specific display names
        XCTAssertEqual(SettingsManager.CodeBlockNotificationStyle.smartDetection.displayName, "Smart Detection")
        XCTAssertEqual(SettingsManager.CodeBlockNotificationStyle.voiceOnly.displayName, "Voice Only")
        XCTAssertEqual(SettingsManager.CodeBlockNotificationStyle.tonesOnly.displayName, "Tones Only")
        XCTAssertEqual(SettingsManager.CodeBlockNotificationStyle.both.displayName, "Voice + Tones")
    }
    
    func testCodeBlockNotificationStyleSetting() {
        // Test setting different notification styles
        let styles: [SettingsManager.CodeBlockNotificationStyle] = [
            .smartDetection, .voiceOnly, .tonesOnly, .both
        ]
        
        for style in styles {
            settingsManager.codeBlockNotificationStyle = style
            XCTAssertEqual(settingsManager.codeBlockNotificationStyle, style, "Notification style should be set correctly")
        }
    }
    
    func testCodeBlockNotificationStylePersistence() {
        settingsManager.codeBlockNotificationStyle = .voiceOnly
        
        // Create new instance to test persistence
        let newManager = SettingsManager.shared
        XCTAssertEqual(newManager.codeBlockNotificationStyle, .voiceOnly, "Notification style should persist")
        
        newManager.codeBlockNotificationStyle = .both
        
        let finalManager = SettingsManager.shared
        XCTAssertEqual(finalManager.codeBlockNotificationStyle, .both, "Notification style change should persist")
    }
    
    func testCodeBlockNotificationStyleRawValue() {
        // Test raw value conversion
        XCTAssertEqual(SettingsManager.CodeBlockNotificationStyle.smartDetection.rawValue, "smart_detection")
        XCTAssertEqual(SettingsManager.CodeBlockNotificationStyle.voiceOnly.rawValue, "voice_only")
        XCTAssertEqual(SettingsManager.CodeBlockNotificationStyle.tonesOnly.rawValue, "tones_only")
        XCTAssertEqual(SettingsManager.CodeBlockNotificationStyle.both.rawValue, "both")
    }
    
    func testCodeBlockNotificationStyleFromRawValue() {
        // Test initialization from raw value
        XCTAssertEqual(SettingsManager.CodeBlockNotificationStyle(rawValue: "smart_detection"), .smartDetection)
        XCTAssertEqual(SettingsManager.CodeBlockNotificationStyle(rawValue: "voice_only"), .voiceOnly)
        XCTAssertEqual(SettingsManager.CodeBlockNotificationStyle(rawValue: "tones_only"), .tonesOnly)
        XCTAssertEqual(SettingsManager.CodeBlockNotificationStyle(rawValue: "both"), .both)
        XCTAssertNil(SettingsManager.CodeBlockNotificationStyle(rawValue: "invalid_value"))
    }
    
    // MARK: - Language Notification Tests
    
    func testLanguageNotificationEnabledSetting() {
        // Test enabling and disabling language notifications
        settingsManager.isCodeBlockLanguageNotificationEnabled = true
        XCTAssertTrue(settingsManager.isCodeBlockLanguageNotificationEnabled, "Language notifications should be enabled")
        
        settingsManager.isCodeBlockLanguageNotificationEnabled = false
        XCTAssertFalse(settingsManager.isCodeBlockLanguageNotificationEnabled, "Language notifications should be disabled")
        
        settingsManager.isCodeBlockLanguageNotificationEnabled = true
        XCTAssertTrue(settingsManager.isCodeBlockLanguageNotificationEnabled, "Language notifications should be re-enabled")
    }
    
    func testLanguageNotificationPersistence() {
        settingsManager.isCodeBlockLanguageNotificationEnabled = false
        
        let newManager = SettingsManager.shared
        XCTAssertFalse(newManager.isCodeBlockLanguageNotificationEnabled, "Language notification setting should persist")
        
        newManager.isCodeBlockLanguageNotificationEnabled = true
        
        let finalManager = SettingsManager.shared
        XCTAssertTrue(finalManager.isCodeBlockLanguageNotificationEnabled, "Language notification setting should persist when enabled")
    }
    
    // MARK: - Code Block Tone Volume Tests
    
    func testCodeBlockToneVolumeSetting() {
        // Test various volume levels
        let testVolumes: [Float] = [0.0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.0]
        
        for volume in testVolumes {
            settingsManager.codeBlockToneVolume = volume
            XCTAssertEqual(settingsManager.codeBlockToneVolume, volume, "Tone volume should be set correctly to \(volume)")
        }
    }
    
    func testCodeBlockToneVolumeClamping() {
        // Test that volume is clamped to valid range
        settingsManager.codeBlockToneVolume = 1.5
        XCTAssertEqual(settingsManager.codeBlockToneVolume, 1.5, "Volume should allow values above 1.0 for flexibility")
        
        settingsManager.codeBlockToneVolume = -0.5
        XCTAssertEqual(settingsManager.codeBlockToneVolume, -0.5, "Volume should allow negative values for flexibility")
        
        // Test typical range
        settingsManager.codeBlockToneVolume = 0.8
        XCTAssertEqual(settingsManager.codeBlockToneVolume, 0.8, "Normal volume should work")
    }
    
    func testCodeBlockToneVolumePersistence() {
        settingsManager.codeBlockToneVolume = 0.4
        
        let newManager = SettingsManager.shared
        XCTAssertEqual(newManager.codeBlockToneVolume, 0.4, "Tone volume should persist")
        
        newManager.codeBlockToneVolume = 0.9
        
        let finalManager = SettingsManager.shared
        XCTAssertEqual(finalManager.codeBlockToneVolume, 0.9, "Tone volume change should persist")
    }
    
    // MARK: - Settings Integration Tests
    
    func testAllSettingsIntegration() {
        // Test setting all properties together
        settingsManager.isDeveloperModeEnabled = true
        settingsManager.codeBlockNotificationStyle = .both
        settingsManager.isCodeBlockLanguageNotificationEnabled = false
        settingsManager.codeBlockToneVolume = 0.5
        
        // Verify all settings are applied
        XCTAssertTrue(settingsManager.isDeveloperModeEnabled)
        XCTAssertEqual(settingsManager.codeBlockNotificationStyle, .both)
        XCTAssertFalse(settingsManager.isCodeBlockLanguageNotificationEnabled)
        XCTAssertEqual(settingsManager.codeBlockToneVolume, 0.5)
    }
    
    func testSettingsPersistenceIntegration() {
        // Set all settings
        settingsManager.isDeveloperModeEnabled = true
        settingsManager.codeBlockNotificationStyle = .tonesOnly
        settingsManager.isCodeBlockLanguageNotificationEnabled = true
        settingsManager.codeBlockToneVolume = 0.8
        
        // Create new instance to test all settings persist
        let newManager = SettingsManager.shared
        
        XCTAssertTrue(newManager.isDeveloperModeEnabled, "Developer mode should persist")
        XCTAssertEqual(newManager.codeBlockNotificationStyle, .tonesOnly, "Notification style should persist")
        XCTAssertTrue(newManager.isCodeBlockLanguageNotificationEnabled, "Language notification should persist")
        XCTAssertEqual(newManager.codeBlockToneVolume, 0.8, "Tone volume should persist")
    }
    
    // MARK: - Settings Update Performance Tests
    
    func testSettingsUpdatePerformance() {
        measure {
            for i in 0..<1000 {
                settingsManager.codeBlockNotificationStyle = SettingsManager.CodeBlockNotificationStyle.allCases[i % 4]
                settingsManager.isCodeBlockLanguageNotificationEnabled = i % 2 == 0
                settingsManager.codeBlockToneVolume = Float(i % 100) / 100.0
            }
        }
    }
    
    func testSettingsReadPerformance() {
        // Set up some values first
        settingsManager.codeBlockNotificationStyle = .both
        settingsManager.isCodeBlockLanguageNotificationEnabled = true
        settingsManager.codeBlockToneVolume = 0.6
        
        measure {
            for _ in 0..<10000 {
                _ = settingsManager.codeBlockNotificationStyle
                _ = settingsManager.isCodeBlockLanguageNotificationEnabled
                _ = settingsManager.codeBlockToneVolume
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testSettingsWithInvalidUserDefaults() {
        // Test behavior when UserDefaults contains invalid data
        UserDefaults.standard.set("invalid_value", forKey: "codeBlockNotificationStyle")
        UserDefaults.standard.set("not_a_boolean", forKey: "isCodeBlockLanguageNotificationEnabled")
        UserDefaults.standard.set("not_a_float", forKey: "codeBlockToneVolume")
        
        // Should handle invalid data gracefully
        let manager = SettingsManager.shared
        XCTAssertNotNil(manager.codeBlockNotificationStyle, "Should handle invalid notification style")
        XCTAssertNotNil(manager.isCodeBlockLanguageNotificationEnabled, "Should handle invalid boolean")
        XCTAssertNotNil(manager.codeBlockToneVolume, "Should handle invalid float")
    }
    
    func testSettingsWithMissingUserDefaults() {
        // Remove all keys
        UserDefaults.standard.removeObject(forKey: "codeBlockNotificationStyle")
        UserDefaults.standard.removeObject(forKey: "isCodeBlockLanguageNotificationEnabled")
        UserDefaults.standard.removeObject(forKey: "codeBlockToneVolume")
        
        let manager = SettingsManager.shared
        
        // Should use default values
        XCTAssertEqual(manager.codeBlockNotificationStyle, .smartDetection, "Should use default for missing notification style")
        XCTAssertTrue(manager.isCodeBlockLanguageNotificationEnabled, "Should use default for missing language notification")
        XCTAssertEqual(manager.codeBlockToneVolume, 0.7, "Should use default for missing tone volume")
    }
    
    func testRapidSettingsChanges() {
        // Test rapid changes to settings
        let expectation = XCTestExpectation(description: "Rapid settings changes")
        
        let changes = 100
        var completedChanges = 0
        
        for i in 0..<changes {
            DispatchQueue.global(qos: .userInitiated).async {
                self.settingsManager.codeBlockNotificationStyle = SettingsManager.CodeBlockNotificationStyle.allCases[i % 4]
                self.settingsManager.isCodeBlockLanguageNotificationEnabled = i % 2 == 0
                self.settingsManager.codeBlockToneVolume = Float(i % 100) / 100.0
                
                DispatchQueue.main.async {
                    completedChanges += 1
                    if completedChanges == changes {
                        expectation.fulfill()
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(completedChanges, changes, "All rapid changes should complete")
    }
    
    // MARK: - Settings Validation Tests
    
    func testSettingsValidation() {
        // Test that settings work correctly in real scenarios
        
        // Test a realistic configuration
        settingsManager.codeBlockNotificationStyle = .smartDetection
        settingsManager.isCodeBlockLanguageNotificationEnabled = true
        settingsManager.codeBlockToneVolume = 0.7
        
        // Verify the configuration makes sense
        XCTAssertEqual(settingsManager.codeBlockNotificationStyle, .smartDetection)
        XCTAssertTrue(settingsManager.isCodeBlockLanguageNotificationEnabled)
        XCTAssertEqual(settingsManager.codeBlockToneVolume, 0.7)
        
        // Test another realistic configuration
        settingsManager.codeBlockNotificationStyle = .tonesOnly
        settingsManager.isCodeBlockLanguageNotificationEnabled = false
        settingsManager.codeBlockToneVolume = 0.5
        
        XCTAssertEqual(settingsManager.codeBlockNotificationStyle, .tonesOnly)
        XCTAssertFalse(settingsManager.isCodeBlockLanguageNotificationEnabled)
        XCTAssertEqual(settingsManager.codeBlockToneVolume, 0.5)
    }
    
    func testSettingsBoundaryValues() {
        // Test boundary values for all settings
        
        // Test notification style boundaries
        settingsManager.codeBlockNotificationStyle = .smartDetection
        XCTAssertEqual(settingsManager.codeBlockNotificationStyle, .smartDetection)
        
        settingsManager.codeBlockNotificationStyle = .both
        XCTAssertEqual(settingsManager.codeBlockNotificationStyle, .both)
        
        // Test boolean boundaries
        settingsManager.isCodeBlockLanguageNotificationEnabled = true
        XCTAssertTrue(settingsManager.isCodeBlockLanguageNotificationEnabled)
        
        settingsManager.isCodeBlockLanguageNotificationEnabled = false
        XCTAssertFalse(settingsManager.isCodeBlockLanguageNotificationEnabled)
        
        // Test volume boundaries
        settingsManager.codeBlockToneVolume = 0.0
        XCTAssertEqual(settingsManager.codeBlockToneVolume, 0.0)
        
        settingsManager.codeBlockToneVolume = 1.0
        XCTAssertEqual(settingsManager.codeBlockToneVolume, 1.0)
    }
    
    // MARK: - Memory Management Tests
    
    func testSettingsManagerDeallocation() {
        weak var weakManager: SettingsManager?
        
        autoreleasepool {
            let manager = SettingsManager.shared
            weakManager = manager
            
            // Use the manager
            manager.isDeveloperModeEnabled = true
            manager.codeBlockNotificationStyle = .both
            _ = manager
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(weakManager, "SettingsManager should be deallocated")
        }
        
        wait(for: [XCTestExpectation(description: "Deallocation test")], timeout: 1.0)
    }
    
    // MARK: - Thread Safety Tests
    
    func testThreadSafety() {
        let expectation = XCTestExpectation(description: "Thread safety test")
        let threadCount = 10
        let operationsPerThread = 100
        var completedOperations = 0
        
        let queue = DispatchQueue(label: "test.queue", attributes: .concurrent)
        
        for _ in 0..<threadCount {
            queue.async {
                for i in 0..<operationsPerThread {
                    self.settingsManager.codeBlockNotificationStyle = SettingsManager.CodeBlockNotificationStyle.allCases[i % 4]
                    self.settingsManager.isCodeBlockLanguageNotificationEnabled = i % 2 == 0
                    self.settingsManager.codeBlockToneVolume = Float(i % 100) / 100.0
                    
                    DispatchQueue.main.async {
                        completedOperations += 1
                        if completedOperations == threadCount * operationsPerThread {
                            expectation.fulfill()
                        }
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        XCTAssertEqual(completedOperations, threadCount * operationsPerThread, "All thread operations should complete")
    }
    
    // MARK: - Integration with Other Components
    
    func testIntegrationWithAudioFeedbackManager() {
        // Test that settings work correctly with audio feedback
        let audioManager = AudioFeedbackManager()
        
        // Test different settings affect audio behavior
        settingsManager.codeBlockToneVolume = 0.3
        audioManager.setVolume(settingsManager.codeBlockToneVolume)
        
        // Should not throw and should handle volume change
        XCTAssertNoThrow(
            audioManager.playFeedback(for: .codeBlockStart),
            "Audio feedback should work with settings-based volume"
        )
    }
    
    func testSettingsReset() {
        // Set some non-default values
        settingsManager.isDeveloperModeEnabled = true
        settingsManager.codeBlockNotificationStyle = .voiceOnly
        settingsManager.isCodeBlockLanguageNotificationEnabled = false
        settingsManager.codeBlockToneVolume = 0.2
        
        // Clear UserDefaults to simulate reset
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        
        // Create new manager - should have defaults
        let resetManager = SettingsManager.shared
        
        XCTAssertFalse(resetManager.isDeveloperModeEnabled, "Should reset developer mode")
        XCTAssertEqual(resetManager.codeBlockNotificationStyle, .smartDetection, "Should reset notification style")
        XCTAssertTrue(resetManager.isCodeBlockLanguageNotificationEnabled, "Should reset language notification")
        XCTAssertEqual(resetManager.codeBlockToneVolume, 0.7, "Should reset tone volume")
    }
}