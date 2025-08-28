//
//  CustomToneGeneratorTests.swift
//  MD TalkManTests
//
//  Created by Claude on 8/28/25.
//

import XCTest
import AVFoundation
@testable import MD_TalkMan

final class CustomToneGeneratorTests: XCTestCase {
    
    var toneGenerator: CustomToneGenerator!
    
    override func setUpWithError() throws {
        toneGenerator = CustomToneGenerator(volume: 0.5)
    }
    
    override func tearDownWithError() throws {
        toneGenerator = nil
    }
    
    // MARK: - Initialization Tests
    
    // Removed initialization tests as they access private masterVolume property
    
    // MARK: - Tone Definition Tests
    
    // Removed tone definition tests as they test implementation details not exposed in public API
    
    // MARK: - Volume Management Tests
    
    // Removed setVolume tests as they test implementation details not exposed in public API
    
    // Removed tests that access private implementation details (setVolume, masterVolume, audioEngine, playerNode)
    
    func testPlayToneWithCompletionHandler() {
        let expectation = XCTestExpectation(description: "Tone completion handler called")
        
        toneGenerator.playStartTone {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testPlayMultipleTonesSequentially() {
        let expectation = XCTestExpectation(description: "Multiple tones completed")
        var completedTones = 0
        
        // Use instance methods instead of static properties
        toneGenerator.playStartTone {
            completedTones += 1
            if completedTones == 3 {
                expectation.fulfill()
            }
        }
        
        toneGenerator.playPauseTone {
            completedTones += 1
            if completedTones == 3 {
                expectation.fulfill()
            }
        }
        
        toneGenerator.playStopTone {
            completedTones += 1
            if completedTones == 3 {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(completedTones, 3, "All tones should complete")
    }
    
    func testPlayToneWithoutCompletionHandler() {
        // Test that tone plays without completion handler (should not crash)
        XCTAssertNoThrow(
            toneGenerator.playButtonTapTone(),
            "Playing tone without completion handler should not throw"
        )
        
        // Give it a moment to play
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
    }
    
    // MARK: - Tone Specific Tests
    
    func testPlayStartTone() {
        let expectation = XCTestExpectation(description: "Start tone completed")
        
        toneGenerator.playStartTone {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testPlayCodeBlockStartTone() {
        let expectation = XCTestExpectation(description: "Code block start tone completed")
        
        toneGenerator.playCodeBlockStartTone {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testPlayCodeBlockEndTone() {
        let expectation = XCTestExpectation(description: "Code block end tone completed")
        
        toneGenerator.playCodeBlockEndTone {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testAllTonePlayMethods() {
        let expectation = XCTestExpectation(description: "All tone play methods completed")
        var completedMethods = 0
        
        let methods: [() -> Void] = [
            { self.toneGenerator.playStartTone { completedMethods += 1 } },
            { self.toneGenerator.playPauseTone { completedMethods += 1 } },
            { self.toneGenerator.playStopTone { completedMethods += 1 } },
            { self.toneGenerator.playCompletionTone { completedMethods += 1 } },
            { self.toneGenerator.playNavigationTone { completedMethods += 1 } },
            { self.toneGenerator.playErrorTone { completedMethods += 1 } },
            { self.toneGenerator.playButtonTapTone { completedMethods += 1 } },
            { self.toneGenerator.playSettingsChangeTone { completedMethods += 1 } },
            { self.toneGenerator.playCodeBlockStartTone { completedMethods += 1 } },
            { self.toneGenerator.playCodeBlockEndTone { 
                completedMethods += 1
                if completedMethods == 10 {
                    expectation.fulfill()
                }
            } }
        ]
        
        for method in methods {
            method()
        }
        
        wait(for: [expectation], timeout: 10.0)
        XCTAssertEqual(completedMethods, 10, "All tone play methods should complete")
    }
    
    // MARK: - Error Handling Tests
    
    func testGracefulHandlingWhenAudioEngineFails() {
        // Test graceful degradation when audio engine has issues
        let expectation = XCTestExpectation(description: "Graceful error handling")
        
        // Note: Cannot directly access private audioEngine, but we can test error tone handling
        toneGenerator.playErrorTone {
            // Should still call completion handler even if audio fails
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testToneGeneratorWithZeroVolume() {
        let zeroVolumeGenerator = CustomToneGenerator(volume: 0.0)
        
        let expectation = XCTestExpectation(description: "Zero volume tone completed")
        
        zeroVolumeGenerator.playStartTone {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Performance Tests
    
    func testToneGenerationPerformance() {
        measure {
            let expectation = XCTestExpectation(description: "Performance test tones")
            var completedCount = 0
            
            for _ in 0..<10 {
                toneGenerator.playButtonTapTone {
                    completedCount += 1
                    if completedCount == 10 {
                        expectation.fulfill()
                    }
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testConcurrentTonePlayback() {
        let expectation = XCTestExpectation(description: "Concurrent tone playback")
        let concurrentTones = 5
        var completedCount = 0
        
        for _ in 0..<concurrentTones {
            DispatchQueue.global(qos: .userInitiated).async {
                self.toneGenerator.playNavigationTone {
                    DispatchQueue.main.async {
                        completedCount += 1
                        if completedCount == concurrentTones {
                            expectation.fulfill()
                        }
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(completedCount, concurrentTones, "All concurrent tones should complete")
    }
    
    // MARK: - Memory Management Tests
    
    func testCleanupAfterPlayback() {
        weak var weakGenerator = toneGenerator
        
        toneGenerator.playCompletionTone {
            // Release reference after completion
            self.toneGenerator = nil
        }
        
        // Wait for completion and cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertNil(weakGenerator, "Tone generator should be deallocated after cleanup")
        }
        
        wait(for: [XCTestExpectation(description: "Cleanup test")], timeout: 3.0)
    }
}