#!/usr/bin/env swift

import Foundation
import AVFoundation

// Test script to demonstrate voice quality improvements
func testVoiceQuality() {
    print("🎵 TTS Voice Quality Improvements")
    print("=" * 50)
    
    print("🔍 Available Voice Types:")
    let allVoices = AVSpeechSynthesisVoice.speechVoices()
    let englishVoices = allVoices.filter { $0.language.hasPrefix("en-") }
    
    var qualityGroups: [AVSpeechSynthesisVoiceQuality: [AVSpeechSynthesisVoice]] = [:]
    
    for voice in englishVoices {
        if qualityGroups[voice.quality] == nil {
            qualityGroups[voice.quality] = []
        }
        qualityGroups[voice.quality]?.append(voice)
    }
    
    for (quality, voices) in qualityGroups.sorted(by: { $0.key.rawValue > $1.key.rawValue }) {
        let qualityName = quality == .default ? "Standard" : 
                         quality == .enhanced ? "Enhanced" : 
                         quality == .premium ? "Premium" : "Unknown"
        print("\n\(qualityName) Quality (\(voices.count) voices):")
        
        for voice in voices.prefix(3) {
            let gender = voice.gender == .male ? "♂" : 
                        voice.gender == .female ? "♀" : "⚪"
            print("  \(gender) \(voice.name) (\(voice.language))")
        }
        
        if voices.count > 3 {
            print("  ... and \(voices.count - 3) more")
        }
    }
    
    // Test preferred voices
    print("\n🎯 Preferred High-Quality Voices:")
    let preferredVoices = [
        "com.apple.voice.enhanced.en-US.Ava",
        "com.apple.voice.enhanced.en-US.Samantha", 
        "com.apple.voice.enhanced.en-US.Alex",
        "com.apple.voice.premium.en-US.Zoe",
        "com.apple.voice.premium.en-US.Evan"
    ]
    
    for voiceId in preferredVoices {
        if let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            print("✅ \(voice.name) - Available")
        } else {
            print("❌ \(voiceId) - Not available")
        }
    }
    
    print("\n🎚️ Voice Parameters:")
    print("• Rate: 0.5 - 2.0 (optimized for driving: 0.4-0.7)")
    print("• Pitch: 0.5 - 2.0 (natural: 0.8-1.2)")  
    print("• Volume: 0.1 - 1.0 (clear: 0.8-1.0)")
    print("• Pre/Post Delays: 0.1s for natural pacing")
    
    print("\n📱 Features Added:")
    print("✅ Auto-select best available voice quality")
    print("✅ Voice picker with quality indicators")
    print("✅ Real-time voice parameter adjustment")
    print("✅ Voice testing with custom text")
    print("✅ Enhanced audio session for driving")
    print("✅ Bluetooth audio optimization")
    
    print("\n🚗 Driving Optimizations:")
    print("• Spoken Audio category for CarPlay")
    print("• Bluetooth A2DP support") 
    print("• Background playback capability")
    print("• Large touch targets for voice controls")
    print("• Speed optimized for listening while driving")
    
    print("\n🎯 Expected Improvements:")
    print("• More natural, human-like speech")
    print("• Better pronunciation of technical terms")
    print("• Reduced robotic sound")
    print("• Clearer audio in car environments")
    print("• Customizable voice personality")
}

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

testVoiceQuality()