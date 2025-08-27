import Foundation

print("Testing UUID support in iOS 18.5:")

// UUID v4 (random) - available since iOS 2.0
let uuid4 = UUID()
print("UUID v4: \(uuid4.uuidString)")

// Check what's available in Foundation
print("UUID type: \(type(of: uuid4))")

// Test if we can access newer UUID methods
if #available(iOS 16.0, *) {
    print("iOS 16+ available - checking for UUID v7 support")
    
    // Try to see if there are any time-based UUID methods
    // Note: UUID v7 might not be in Foundation yet, even on newer iOS
    let mirror = Mirror(reflecting: UUID.self)
    print("Available methods:")
    for child in mirror.children {
        print("- \(child.label ?? "unknown"): \(child.value)")
    }
}

print("Standard UUID v4 is definitely available")
