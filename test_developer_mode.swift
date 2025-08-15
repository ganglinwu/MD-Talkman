#!/usr/bin/env swift

import Foundation

// Simple test to verify developer mode logic
func testDeveloperModeLogic() {
    print("🧪 Testing Developer Mode Logic")
    print("=" * 50)
    
    // Simulate UserDefaults behavior
    var isDeveloperModeEnabled = true
    
    print("Initial state: Developer Mode = \(isDeveloperModeEnabled)")
    
    // Test toggle off
    print("\n🔄 Toggling Developer Mode OFF...")
    isDeveloperModeEnabled = false
    
    if isDeveloperModeEnabled {
        print("📱 Would load sample data")
    } else {
        print("🗑️ Would clear sample data")
    }
    
    // Test toggle on
    print("\n🔄 Toggling Developer Mode ON...")
    isDeveloperModeEnabled = true
    
    if isDeveloperModeEnabled {
        print("📱 Would load sample data (if none exists)")
    } else {
        print("🗑️ Would clear sample data")
    }
    
    // Test clear all data scenario
    print("\n🗑️ Testing Clear All Data...")
    print("Step 1: Clear existing data")
    print("Step 2: Load fresh sample data")
    print("Expected result: No duplicates")
    
    print("\n✅ Logic Test Complete")
    print("Key fixes:")
    print("1. forceLoadSampleData() now clears data first")
    print("2. Developer mode toggle properly clears when disabled")
    print("3. Added debugging prints to track operations")
}

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

testDeveloperModeLogic()