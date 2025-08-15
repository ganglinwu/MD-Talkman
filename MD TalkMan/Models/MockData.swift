//
//  MockData.swift
//  MD TalkMan
//
//  Created by Claude on 8/14/25.
//

import CoreData
import Foundation

struct MockData {
    static func createSampleData(in context: NSManagedObjectContext) {
        print("🏗️ MockData.createSampleData: Starting to create sample data")
        
        // Create sample repository
        let sampleRepo = GitRepository(context: context)
        sampleRepo.id = UUID()
        sampleRepo.name = "Swift Learning Notes"
        sampleRepo.remoteURL = "https://github.com/user/swift-learning"
        sampleRepo.localPath = "/Users/ganglinwu/code/swiftui/markdown"
        sampleRepo.defaultBranch = "main"
        sampleRepo.lastSyncDate = Date()
        sampleRepo.syncEnabled = true
        
        // Create sample markdown files
        let articles = createSampleFiles(in: context, repository: sampleRepo)
        
        // Create parsed content for all real markdown files
        for (index, article) in articles.enumerated() {
            if index == 0 {
                // First article gets detailed progress tracking
                createSampleProgress(in: context, for: article)
            }
            
            // Parse real markdown content for all files
            createRealParsedContent(in: context, for: article)
        }
        
        // Save context
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            fatalError("Failed to create sample data: \(nsError), \(nsError.userInfo)")
        }
    }
    
    private static func createSampleFiles(in context: NSManagedObjectContext, repository: GitRepository) -> [MarkdownFile] {
        print("📁 MockData.createSampleFiles: Creating sample files with embedded content")
        
        // Create realistic Swift learning files with embedded content
        let sampleFiles = [
            ("SwiftUI Fundamentals", "swift-swiftui-fundamentals.md", swiftUIFundamentalsContent),
            ("Memory Management & ARC", "swift-memory-management.md", memoryManagementContent),
            ("iOS App Architecture", "swift-app-architecture.md", appArchitectureContent),
            ("Networking & API Calls", "swift-networking.md", networkingContent),
            ("Core Data Essentials", "swift-coredata.md", coreDataContent),
            ("Advanced Swift Features", "swift-advanced-features.md", advancedSwiftContent),
            ("UIKit Integration", "swift-uikit-bridge.md", uikitBridgeContent),
            ("Performance Optimization", "swift-performance.md", performanceContent),
            ("Testing Best Practices", "swift-testing.md", testingContent),
            ("Concurrency & Async/Await", "swift-concurrency.md", concurrencyContent),
            ("SwiftUI Navigation", "swift-navigation.md", navigationContent),
            ("Data Binding Patterns", "swift-data-binding.md", dataBindingContent),
            ("Error Handling", "swift-error-handling.md", errorHandlingContent),
            ("Design Patterns in iOS", "swift-design-patterns.md", designPatternsContent),
            ("Debugging Techniques", "swift-debugging.md", debuggingContent)
        ]
        
        var markdownFiles: [MarkdownFile] = []
        
        for (index, (title, fileName, content)) in sampleFiles.enumerated() {
            let file = MarkdownFile(context: context)
            file.id = UUID()
            file.title = title
            file.filePath = "embedded://\(fileName)"
            file.gitFilePath = "learning_points/\(fileName)"
            file.repository = repository
            file.repositoryId = repository.id
            file.lastCommitHash = "swift\(Int.random(in: 100...999))"
            file.lastModified = Date().addingTimeInterval(-Double.random(in: 0...604800))
            file.fileSize = Int64(content.count)
            file.syncStatusEnum = SyncStatus.synced
            file.hasLocalChanges = false
            
            markdownFiles.append(file)
            
            print("📚 [\(index + 1)/\(sampleFiles.count)] Created: \(title) (\(content.count) bytes)")
        }
        
        print("✅ Successfully created \(markdownFiles.count) Swift learning files")
        return markdownFiles
    }
    
    private static func createReadableTitle(from fileName: String) -> String {
        // Convert "swift-01-camera-implementation.md" to "Camera Implementation"
        let nameWithoutExtension = String(fileName.dropLast(3)) // Remove .md
        
        // Remove swift-XX- prefix if present
        let withoutPrefix = nameWithoutExtension.replacingOccurrences(
            of: #"^swift-\d+-"#,
            with: "",
            options: .regularExpression
        )
        
        // Replace hyphens with spaces and capitalize words
        let readable = withoutPrefix
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
        
        return readable
    }
    
    private static func createPlaceholderFiles(in context: NSManagedObjectContext, repository: GitRepository) -> [MarkdownFile] {
        let files = [
            ("Getting Started with SwiftUI", "getting-started.md"),
            ("Advanced Core Data", "advanced-coredata.md"),
            ("iOS Speech Recognition", "speech-recognition.md"),
            ("Git Workflows", "git-workflows.md")
        ]
        
        return files.map { (title, fileName) in
            let file = MarkdownFile(context: context)
            file.id = UUID()
            file.title = title
            file.filePath = "/Documents/Repositories/personal-notes/\(fileName)"
            file.gitFilePath = fileName
            file.repository = repository
            file.repositoryId = repository.id
            file.lastCommitHash = "abc\(Int.random(in: 100...999))"
            file.lastModified = Date().addingTimeInterval(-Double.random(in: 0...86400))
            file.fileSize = Int64.random(in: 1000...5000)
            file.syncStatusEnum = SyncStatus.allCases.randomElement()!
            file.hasLocalChanges = Bool.random()
            return file
        }
    }
    
    private static func createSampleProgress(in context: NSManagedObjectContext, for file: MarkdownFile) {
        let progress = ReadingProgress(context: context)
        progress.fileId = file.id!
        progress.currentPosition = Int32.random(in: 0...1000)
        progress.lastReadDate = Date().addingTimeInterval(-3600) // 1 hour ago
        progress.totalDuration = TimeInterval.random(in: 300...1800) // 5-30 minutes
        progress.isCompleted = false
        progress.markdownFile = file
        
        // Add sample bookmarks
        let bookmark1 = Bookmark(context: context)
        bookmark1.id = UUID()
        bookmark1.position = Int32.random(in: 0...300)
        bookmark1.title = "Key SwiftUI concept"
        bookmark1.timestamp = Date().addingTimeInterval(-1800) // 30 minutes ago
        bookmark1.readingProgress = progress
        
        let bookmark2 = Bookmark(context: context)
        bookmark2.id = UUID()
        bookmark2.position = Int32.random(in: 400...800)
        bookmark2.title = nil // Test optional title
        bookmark2.timestamp = Date().addingTimeInterval(-900) // 15 minutes ago
        bookmark2.readingProgress = progress
    }
    
    
    static func createSampleRepository() -> (String, String, String) {
        return ("Sample Repo", "https://github.com/user/sample", "/Documents/Repositories/sample")
    }
    
    
    private static func createRealParsedContent(in context: NSManagedObjectContext, for file: MarkdownFile) {
        guard let filePath = file.filePath else {
            print("❌ No file path for \(file.title ?? "unknown file")")
            return
        }
        
        // Get embedded content based on file path
        let markdownContent = getEmbeddedContent(for: filePath)
        
        // Parse it using our MarkdownParser
        let parser = MarkdownParser()
        parser.processAndSaveMarkdownFile(file, content: markdownContent, in: context)
        
        print("✅ Parsed embedded content for: \(file.title ?? "Unknown") (\(markdownContent.count) characters)")
    }
    
    private static func getEmbeddedContent(for filePath: String) -> String {
        // Extract the filename from the embedded path
        if filePath.contains("swiftui-fundamentals") {
            return swiftUIFundamentalsContent
        } else if filePath.contains("memory-management") {
            return memoryManagementContent
        } else if filePath.contains("app-architecture") {
            return appArchitectureContent
        } else if filePath.contains("networking") {
            return networkingContent
        } else if filePath.contains("coredata") {
            return coreDataContent
        } else if filePath.contains("advanced-features") {
            return advancedSwiftContent
        } else if filePath.contains("uikit-bridge") {
            return uikitBridgeContent
        } else if filePath.contains("performance") {
            return performanceContent
        } else if filePath.contains("testing") {
            return testingContent
        } else if filePath.contains("concurrency") {
            return concurrencyContent
        } else if filePath.contains("navigation") {
            return navigationContent
        } else if filePath.contains("data-binding") {
            return dataBindingContent
        } else if filePath.contains("error-handling") {
            return errorHandlingContent
        } else if filePath.contains("design-patterns") {
            return designPatternsContent
        } else if filePath.contains("debugging") {
            return debuggingContent
        } else {
            // Default fallback content
            return """
            # Swift Learning Content
            
            This is a sample Swift learning article covering important iOS development concepts.
            
            ## Overview
            
            This article provides practical examples and best practices for Swift development.
            
            ## Key Points
            
            - Learn modern Swift techniques
            - Understand iOS development patterns  
            - Practice with real examples
            
            ## Conclusion
            
            Mastering these concepts will make you a better iOS developer.
            """
        }
    }
    
    private static func createPlaceholderParsedContent(in context: NSManagedObjectContext, for file: MarkdownFile) {
        let parsedContent = ParsedContent(context: context)
        parsedContent.fileId = file.id!
        parsedContent.lastParsed = Date()
        parsedContent.markdownFiles = file
        
        // Simple placeholder content
        parsedContent.plainText = """
        Heading level 1: \(file.title ?? "Learning Topic"). This is a Swift learning article covering important concepts and best practices. The content includes code examples, explanations, and key takeaways to help you master iOS development.
        """
        
        // Create basic sections
        let basicSections = [
            (0, 50, ContentSectionType.header, 1, false),
            (51, 200, ContentSectionType.paragraph, 0, false)
        ]
        
        for (startIdx, endIdx, sectionType, level, skippable) in basicSections {
            if startIdx < parsedContent.plainText?.count ?? 0 {
                let section = ContentSection(context: context)
                section.startIndex = Int32(startIdx)
                section.endIndex = Int32(min(endIdx, parsedContent.plainText?.count ?? 0))
                section.typeEnum = sectionType
                section.level = Int16(level)
                section.isSkippable = skippable
                section.parsedContent = parsedContent
            }
        }
    }
    
    static func createSampleFile() -> (String, String, String) {
        return ("Sample Article", "sample.md", "# Sample Content\n\nThis is a sample markdown file for testing.")
    }
}

// MARK: - Embedded Content for Sample Files
private let swiftUIFundamentalsContent = """
# SwiftUI Fundamentals

SwiftUI is Apple's modern declarative framework for building user interfaces across all Apple platforms.

## Key Concepts

### Declarative Syntax
SwiftUI uses a **declarative approach** where you describe what the UI should look like, not how to build it.

```swift
struct ContentView: View {
    var body: some View {
        Text("Hello, SwiftUI!")
            .font(.title)
            .foregroundColor(.blue)
    }
}
```

### Views and Modifiers
- Views are the building blocks of SwiftUI
- Modifiers transform and style views
- Order matters with modifiers

### State Management
SwiftUI provides several property wrappers for state management:

- `@State` for local view state
- `@Binding` for two-way connections
- `@ObservedObject` for external objects
- `@StateObject` for owned objects
- `@EnvironmentObject` for shared data

## Best Practices

1. Keep views small and focused
2. Extract complex logic into view models
3. Use proper state management patterns
4. Leverage SwiftUI's data flow principles

SwiftUI makes iOS development more intuitive and powerful than ever before.
"""

private let memoryManagementContent = """
# Memory Management & ARC

Automatic Reference Counting (ARC) is Swift's memory management system that automatically handles allocation and deallocation of memory.

## How ARC Works

ARC tracks how many references point to each object:
- When references reach zero, the object is deallocated
- No garbage collection overhead
- Deterministic deallocation

## Strong, Weak, and Unowned References

### Strong References (Default)
```swift
class Person {
    let name: String
    var apartment: Apartment?
}
```

### Weak References
```swift
class Apartment {
    weak var tenant: Person?  // Prevents retain cycles
}
```

### Unowned References
```swift
class Customer {
    unowned let creditCard: CreditCard  // Always expected to have a value
}
```

## Common Memory Issues

### Retain Cycles
```swift
// BAD - Creates retain cycle
class Parent {
    var child: Child?
}
class Child {
    var parent: Parent?  // Should be weak!
}

// GOOD - Breaks retain cycle
class Child {
    weak var parent: Parent?
}
```

### Closure Capture Lists
```swift
// BAD - Creates retain cycle
self.completionHandler = {
    self.updateUI()
}

// GOOD - Uses capture list
self.completionHandler = { [weak self] in
    self?.updateUI()
}
```

## Memory Debugging Tools

1. **Instruments** - Track memory usage and leaks
2. **Memory Graph Debugger** - Visualize object relationships
3. **Address Sanitizer** - Detect memory errors

Understanding ARC is crucial for building efficient iOS applications.
"""

private let appArchitectureContent = """
# iOS App Architecture Patterns

Choosing the right architecture is crucial for maintainable and scalable iOS apps.

## MVC (Model-View-Controller)

Apple's traditional pattern:
- **Model**: Data and business logic
- **View**: UI components
- **Controller**: Coordinates between Model and View

```swift
class WeatherViewController: UIViewController {
    @IBOutlet weak var temperatureLabel: UILabel!
    private let weatherService = WeatherService()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadWeatherData()
    }
}
```

## MVVM (Model-View-ViewModel)

Popular with SwiftUI and Combine:
- **ViewModel**: Prepares data for the view
- Enables better testability
- Supports data binding

```swift
class WeatherViewModel: ObservableObject {
    @Published var temperature: String = ""
    @Published var isLoading = false
    
    private let weatherService: WeatherService
    
    func loadWeather() {
        isLoading = true
        weatherService.getCurrentWeather { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                // Update properties
            }
        }
    }
}
```

## Best Practices

Start simple and evolve your architecture as your app grows.
"""

private let networkingContent = """
# Networking & API Calls in iOS

Modern iOS networking using URLSession, Combine, and async/await.

## URLSession Basics

```swift
func fetchData() {
    let url = URL(string: "https://api.example.com/data")!
    
    URLSession.shared.dataTask(with: url) { data, response, error in
        if let data = data {
            // Process data
            DispatchQueue.main.async {
                // Update UI
            }
        }
    }.resume()
}
```

## Modern Async/Await Approach

```swift
func fetchUserData() async throws -> User {
    let url = URL(string: "https://api.example.com/user")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(User.self, from: data)
}

// Usage
Task {
    do {
        let user = try await fetchUserData()
        // Update UI
    } catch {
        // Handle error
    }
}
```

Proper networking is essential for modern iOS apps.
"""

private let coreDataContent = """
# Core Data Essentials

Core Data is Apple's object graph and persistence framework for iOS and macOS applications.

## Core Data Stack

The main components:
- **NSManagedObjectModel**: Describes your data model
- **NSPersistentStoreCoordinator**: Manages the persistent store
- **NSManagedObjectContext**: Your working scratchpad for objects

```swift
lazy var persistentContainer: NSPersistentContainer = {
    let container = NSPersistentContainer(name: "DataModel")
    container.loadPersistentStores { _, error in
        if let error = error {
            fatalError("Core Data error: \\(error)")
        }
    }
    return container
}()
```

Core Data provides powerful data persistence capabilities when used correctly.
"""

private let advancedSwiftContent = """
# Advanced Swift Features

Explore powerful Swift language features that can make your code more elegant and efficient.

## Generics

Write flexible, reusable code:

```swift
// Generic function
func swapValues<T>(_ a: inout T, _ b: inout T) {
    let temp = a
    a = b
    b = temp
}

// Generic types
struct Stack<Element> {
    private var items: [Element] = []
    
    mutating func push(_ item: Element) {
        items.append(item)
    }
    
    mutating func pop() -> Element? {
        return items.popLast()
    }
}
```

These advanced features help you write more expressive and maintainable Swift code.
"""

private let uikitBridgeContent = """
# UIKit Integration with SwiftUI

Bridge the gap between UIKit and SwiftUI for maximum flexibility.

## UIViewRepresentable

Wrap UIKit views for use in SwiftUI:

```swift
struct MapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)
    }
}
```

Bridging UIKit and SwiftUI allows you to leverage the best of both frameworks.
"""

private let performanceContent = """
# Performance Optimization in iOS

Optimize your iOS apps for smooth user experiences and efficient resource usage.

## Profiling with Instruments

Use Xcode's Instruments to identify bottlenecks:

- **Time Profiler**: Find CPU-intensive code
- **Allocations**: Track memory usage
- **Leaks**: Detect memory leaks

Regular profiling and optimization ensure your app performs well across all devices.
"""

private let testingContent = """
# Testing Best Practices in iOS

Comprehensive testing ensures code quality and prevents regressions.

## Unit Testing Fundamentals

```swift
import XCTest
@testable import MyApp

class CalculatorTests: XCTestCase {
    var calculator: Calculator!
    
    override func setUp() {
        super.setUp()
        calculator = Calculator()
    }
    
    func testAddition() {
        // Given
        let result = calculator.add(5.0, 3.0)
        
        // Then
        XCTAssertEqual(result, 8.0, accuracy: 0.001)
    }
}
```

Good testing practices lead to more reliable and maintainable code.
"""

private let concurrencyContent = """
# Concurrency & Async/Await

Modern Swift concurrency makes asynchronous programming safer and more intuitive.

## Async/Await Basics

```swift
func fetchUserProfile(id: String) async throws -> UserProfile {
    let url = URL(string: "https://api.example.com/users/\\(id)")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(UserProfile.self, from: data)
}
```

Swift's modern concurrency model makes writing safe, efficient asynchronous code much easier.
"""

private let navigationContent = """
# SwiftUI Navigation Patterns

Master navigation in SwiftUI apps across different iOS versions and use cases.

## NavigationStack (iOS 16+)

```swift
struct ContentView: View {
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                NavigationLink("Profile", value: NavigationDestination.profile)
                NavigationLink("Settings", value: NavigationDestination.settings)
            }
        }
    }
}
```

Proper navigation architecture creates intuitive user experiences.
"""

private let dataBindingContent = """
# Data Binding Patterns in SwiftUI

Master SwiftUI's powerful data binding system for reactive user interfaces.

## Property Wrappers Overview

SwiftUI provides several property wrappers for different data binding scenarios:

```swift
struct ContentView: View {
    @State private var localValue = ""           // Local view state
    @Binding var sharedValue: String             // Two-way binding
    @ObservedObject var viewModel: UserViewModel // External object
    @StateObject private var manager = DataManager() // Owned object
}
```

Mastering SwiftUI's binding system enables reactive, maintainable user interfaces.
"""

private let errorHandlingContent = """
# Error Handling in Swift and iOS

Robust error handling is essential for creating reliable iOS applications.

## Swift Error Handling Fundamentals

```swift
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case serverError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is invalid"
        case .noData:
            return "No data received from server"
        case .serverError(let statusCode):
            return "Server error with status code: \\(statusCode)"
        }
    }
}
```

Proper error handling makes your app more reliable and provides better user experiences.
"""

private let designPatternsContent = """
# Design Patterns in iOS Development

Learn essential design patterns that improve code organization and maintainability.

## Model-View-ViewModel (MVVM)

Perfect for SwiftUI and data binding:

```swift
class UserProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    
    @MainActor
    func loadUser(id: String) async {
        isLoading = true
        // Load user logic
        isLoading = false
    }
}
```

Design patterns provide proven solutions to common problems.
"""

private let debuggingContent = """
# Advanced Debugging Techniques in iOS

Master debugging tools and techniques to efficiently identify and fix issues.

## Xcode Debugger Essentials

### LLDB Commands

```swift
// Basic debugging commands
(lldb) po variable         // Print object description
(lldb) p variable          // Print variable value
(lldb) bt                  // Show stack trace
(lldb) continue           // Continue execution
```

Mastering these debugging techniques will make you much more efficient at identifying and fixing issues.
"""