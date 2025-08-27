import Foundation

print("Foundation UUID methods:")
print("- UUID() available: \(UUID.self)")

// Check if iOS 16+ UUID v7 methods exist
if #available(iOS 16.0, *) {
    print("- iOS 16+ features available")
    // Check for newer UUID methods
    let methods = UUID.self.description
    print("- UUID description: \(methods)")
} else {
    print("- iOS 16+ features not available")
}

// Test basic UUID creation
let uuid4 = UUID()
print("UUID v4 example: \(uuid4.uuidString)")
