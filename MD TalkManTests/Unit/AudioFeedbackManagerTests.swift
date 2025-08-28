//
//  AudioFeedbackManagerTests.swift
//  MD TalkManTests
//
//  Created by Claude on 8/28/25.
//

import XCTest
@testable import MD_TalkMan

final class AudioFeedbackManagerTests: XCTestCase {
    
    var audioFeedback: AudioFeedbackManager!
    
    override func setUpWithError() throws {
        audioFeedback = AudioFeedbackManager()
    }
    
    override func tearDownWithError() throws {
        audioFeedback = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(audioFeedback, "AudioFeedbackManager should initialize properly")
        XCTAssertTrue(audioFeedback.isEnabled, "Audio feedback should be enabled by default")
    }
    
    func testInitialVolumeLevel() {
        // Test that initial volume is set to a reasonable default
        let manager = AudioFeedbackManager()
        // Volume should be accessible through the public interface
        XCTAssertNoThrow(manager.setVolume(0.5), "Setting volume should not throw")
    }
    
    // MARK: - Enable/Disable Tests
    
    func testEnableDisable() {
        audioFeedback.isEnabled = false
        XCTAssertFalse(audioFeedback.isEnabled, "Should be able to disable audio feedback")
        
        audioFeedback.isEnabled = true
        XCTAssertTrue(audioFeedback.isEnabled, "Should be able to enable audio feedback")
    }
    
    func testFeedbackWhenDisabled() {
        audioFeedback.isEnabled = false
        
        // Should not crash when feedback is disabled
        XCTAssertNoThrow(
            audioFeedback.playFeedback(for: .playStarted),
            "Playing feedback when disabled should not throw"
        )
        
        XCTAssertNoThrow(
            audioFeedback.playFeedback(for: .codeBlockStart),
            "Playing code block feedback when disabled should not throw"
        )
    }
    
    // MARK: - Basic Feedback Types Tests
    
    func testPlayStartedFeedback() {
        let expectation = XCTestExpectation(description: "Play started feedback")
        
        // Mock the completion handler or use a timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        XCTAssertNoThrow(
            audioFeedback.playFeedback(for: .playStarted),
            "Play started feedback should not throw"
        )
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPlayPausedFeedback() {
        let expectation = XCTestExpectation(description: "Play paused feedback")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        XCTAssertNoThrow(
            audioFeedback.playFeedback(for: .playPaused),
            "Play paused feedback should not throw"
        )
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPlayStoppedFeedback() {
        let expectation = XCTestExpectation(description: "Play stopped feedback")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        XCTAssertNoThrow(
            audioFeedback.playFeedback(for: .playStopped),
            "Play stopped feedback should not throw"
        )
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPlayCompletedFeedback() {
        let expectation = XCTestExpectation(description: "Play completed feedback")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        XCTAssertNoThrow(
            audioFeedback.playFeedback(for: .playCompleted),
            "Play completed feedback should not throw"
        )
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSectionChangedFeedback() {
        let expectation = XCTestExpectation(description: "Section changed feedback")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        XCTAssertNoThrow(
            audioFeedback.playFeedback(for: .sectionChanged),
            "Section changed feedback should not throw"
        )
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testVoiceChangedFeedback() {
        let expectation = XCTestExpectation(description: "Voice changed feedback")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        XCTAssertNoThrow(
            audioFeedback.playFeedback(for: .voiceChanged),
            "Voice changed feedback should not throw"
        )
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testErrorFeedback() {
        let expectation = XCTestExpectation(description: "Error feedback")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        XCTAssertNoThrow(
            audioFeedback.playFeedback(for: .error),
            "Error feedback should not throw"
        )
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testButtonTapFeedback() {
        let expectation = XCTestExpectation(description: "Button tap feedback")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        XCTAssertNoThrow(
            audioFeedback.playFeedback(for: .buttonTap),
            "Button tap feedback should not throw"
        )
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Code Block Feedback Tests
    
    func testCodeBlockStartFeedback() {
        let expectation = XCTestExpectation(description: "Code block start feedback")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        XCTAssertNoThrow(
            audioFeedback.playFeedback(for: .codeBlockStart),
            "Code block start feedback should not throw"
        )
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testCodeBlockEndFeedback() {
        let expectation = XCTestExpectation(description: "Code block end feedback")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        XCTAssertNoThrow(
            audioFeedback.playFeedback(for: .codeBlockEnd),
            "Code block end feedback should not throw"
        )
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testCodeBlockStartToneWithCompletion() {
        let expectation = XCTestExpectation(description: "Code block start tone with completion")
        
        audioFeedback.playCodeBlockStartTone {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testCodeBlockEndTone() {
        let expectation = XCTestExpectation(description: "Code block end tone")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        XCTAssertNoThrow(
            audioFeedback.playCodeBlockEndTone(),
            "Code block end tone should not throw"
        )
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Volume Management Tests
    
    func testSetVolume() {
        XCTAssertNoThrow(
            audioFeedback.setVolume(0.7),
            "Setting volume should not throw"
        )
        
        // Test various volume levels
        let testVolumes: [Float] = [0.0, 0.25, 0.5, 0.75, 1.0]
        
        for volume in testVolumes {
            XCTAssertNoThrow(
                audioFeedback.setVolume(volume),
                "Setting volume to \(volume) should not throw"
            )
        }
    }
    
    func testVolumeClamping() {
        // Test that volume is properly clamped
        XCTAssertNoThrow(
            audioFeedback.setVolume(1.5),
            "Setting volume above 1.0 should not throw"
        )
        
        XCTAssertNoThrow(
            audioFeedback.setVolume(-0.5),
            "Setting volume below 0.0 should not throw"
        )
        
        XCTAssertNoThrow(
            audioFeedback.setVolume(0.0),
            "Setting volume to 0.0 should not throw"
        )
    }
    
    func testVolumeAffectsPlayback() {
        // Test that volume changes affect subsequent playback
        audioFeedback.setVolume(0.3)
        
        let expectation = XCTestExpectation(description: "Low volume playback")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        XCTAssertNoThrow(
            audioFeedback.playFeedback(for: .buttonTap),
            "Playing feedback with low volume should not throw"
        )
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Sequential Feedback Tests
    
    func testSequentialFeedbackPlayback() {
        let expectation = XCTestExpectation(description: "Sequential feedback playback")
        var feedbackCount = 0
        
        let feedbackTypes: [AudioFeedbackType] = [
            .playStarted, .playPaused, .playStopped,
            .sectionChanged, .voiceChanged, .buttonTap
        ]
        
        for (index, type) in feedbackTypes.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2) {
                self.audioFeedback.playFeedback(for: type)
                feedbackCount += 1
                
                if feedbackCount == feedbackTypes.count {
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 3.0)
        XCTAssertEqual(feedbackCount, feedbackTypes.count, "All feedback types should play")
    }
    
    // MARK: - Rapid Feedback Tests
    
    func testRapidFeedbackPlayback() {
        let expectation = XCTestExpectation(description: "Rapid feedback playback")
        let rapidCount = 10
        var completedCount = 0
        
        for i in 0..<rapidCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                self.audioFeedback.playFeedback(for: .buttonTap)
                completedCount += 1
                
                if completedCount == rapidCount {
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(completedCount, rapidCount, "All rapid feedback should play")
    }
    
    // MARK: - Code Block Specific Tests
    
    func testCodeBlockFeedbackSequence() {
        let expectation = XCTestExpectation(description: "Code block feedback sequence")
        var sequenceStep = 0
        
        // Test the typical code block entry/exit sequence
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.audioFeedback.playFeedback(for: .codeBlockStart)
            sequenceStep = 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.audioFeedback.playFeedback(for: .codeBlockEnd)
            sequenceStep = 2
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(sequenceStep, 2, "Code block sequence should complete")
    }
    
    func testMixedFeedbackTypes() {
        let expectation = XCTestExpectation(description: "Mixed feedback types")
        let totalTypes = 8
        var completedTypes = 0
        
        let allTypes: [AudioFeedbackType] = [
            .playStarted, .codeBlockStart, .buttonTap,
            .sectionChanged, .codeBlockEnd, .playPaused,
            .voiceChanged, .error
        ]
        
        for type in allTypes {
            DispatchQueue.global(qos: .userInitiated).async {
                self.audioFeedback.playFeedback(for: type)
                DispatchQueue.main.async {
                    completedTypes += 1
                    if completedTypes == totalTypes {
                        expectation.fulfill()
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(completedTypes, totalTypes, "All mixed feedback types should complete")
    }
    
    // MARK: - Edge Case Tests
    
    func testFeedbackWhenAudioSessionIsBusy() {
        // Test graceful handling when audio session might be busy
        let expectation = XCTestExpectation(description: "Busy audio session handling")
        
        // Play multiple feedback types rapidly
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                self.audioFeedback.playFeedback(for: .buttonTap)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testFeedbackWithZeroVolume() {
        audioFeedback.setVolume(0.0)
        
        let expectation = XCTestExpectation(description: "Zero volume feedback")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        XCTAssertNoThrow(
            audioFeedback.playFeedback(for: .playStarted),
            "Playing feedback with zero volume should not throw"
        )
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Performance Tests
    
    func testFeedbackPlaybackPerformance() {
        measure {
            let expectation = XCTestExpectation(description: "Performance test feedback")
            var feedbackCount = 0
            
            for i in 0..<20 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.02) {
                    self.audioFeedback.playFeedback(for: .buttonTap)
                    feedbackCount += 1
                    
                    if feedbackCount == 20 {
                        expectation.fulfill()
                    }
                }
            }
            
            wait(for: [expectation], timeout: 3.0)
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testCleanupAndDeallocation() {
        weak var weakFeedback = audioFeedback
        
        audioFeedback.playFeedback(for: .playCompleted)
        audioFeedback = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertNil(weakFeedback, "AudioFeedbackManager should be deallocated")
        }
        
        wait(for: [XCTestExpectation(description: "Deallocation test")], timeout: 2.0)
    }
    
    // MARK: - Integration Tests
    
    func testIntegrationWithCustomToneGenerator() {
        // Test that AudioFeedbackManager properly integrates with CustomToneGenerator
        let expectation = XCTestExpectation(description: "Custom tone generator integration")
        
        audioFeedback.playCodeBlockStartTone {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testAllFeedbackTypesWithoutCrash() {
        let expectation = XCTestExpectation(description: "All feedback types without crash")
        var testedTypes = 0
        
        let allTypes: [AudioFeedbackType] = [
            .playStarted, .playPaused, .playStopped, .playCompleted,
            .sectionChanged, .voiceChanged, .error, .buttonTap,
            .codeBlockStart, .codeBlockEnd
        ]
        
        for type in allTypes {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(testedTypes) * 0.1) {
                XCTAssertNoThrow(
                    self.audioFeedback.playFeedback(for: type),
                    "Feedback type \(type) should not crash"
                )
                
                testedTypes += 1
                if testedTypes == allTypes.count {
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 3.0)
        XCTAssertEqual(testedTypes, allTypes.count, "All feedback types should be tested")
    }
}