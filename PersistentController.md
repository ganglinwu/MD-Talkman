# Core Data Architecture Guide

## Overview
Core Data is Apple's Object-Relational Mapping (ORM) framework that sits on top of SQLite. It provides a high-level interface for managing object graphs and persistence.

## Core Data Stack Components

### NSPersistentContainer
- **Purpose**: High-level wrapper that bundles all Core Data components
- **Introduced**: iOS 10 (replaces manual stack setup)
- **Contains**:
  - NSManagedObjectModel (schema/data model)
  - NSPersistentStoreCoordinator (manages SQLite file)
  - NSManagedObjectContext (main context for UI)
  - Background contexts for async operations

### Traditional vs Modern Approach

**Pre-iOS 10 (Manual Setup):**
```swift
let model = NSManagedObjectModel(contentsOf: modelURL)
let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
context.persistentStoreCoordinator = coordinator
// Add persistent store to coordinator...
```

**iOS 10+ (NSPersistentContainer):**
```swift
let container = NSPersistentContainer(name: "DataModel")
container.loadPersistentStores { _, error in ... }
```

## PersistenceController Implementation

### Singleton vs Testing Pattern
```swift
struct PersistenceController {
    static let shared = PersistenceController()          // Production singleton
    
    static var preview: PersistenceController = {       // Testing instance
        let controller = PersistenceController(inMemory: true)  // ← Not singleton!
        return controller
    }()
}
```

**Key Points:**
- `shared`: Production singleton that saves to disk
- `preview`: Separate testing instance for SwiftUI previews (memory-only)
- `inMemory: true`: Data stored in RAM, disappears when app closes
- SwiftUI previews use `preview`, real app uses `shared`

### Core Methods Explained

#### container.loadPersistentStores
```swift
container.loadPersistentStores { _, error in
    if let error = error as NSError? {
        fatalError("Unresolved error \(error), \(error.userInfo)")
    }
}
```

**What it does:**
1. **Creates/Opens SQLite file** (usually in Documents directory)
2. **Runs migrations** if schema changed between app versions
3. **Connects to database** and makes it ready for queries
4. **Is asynchronous** - takes time to open large databases
5. **Calls completion handler** when done (success or error)

**Think of it as:** `database.connect()` in other frameworks

#### automaticallyMergesChangesFromParent
```swift
container.viewContext.automaticallyMergesChangesFromParent = true
```

**Core Data Context Hierarchy:**
```
PersistentStoreCoordinator (SQLite file)
├── viewContext (UI thread - main queue)
└── backgroundContext (background thread)
```

**The Problem:** 
- Background thread saves data
- UI context doesn't automatically see changes
- Results in stale data in SwiftUI views

**The Solution:**
- `automaticallyMergesChangesFromParent = true`
- When background saves occur → UI context automatically updates
- No manual refresh needed

**Example Scenario:**
1. Background sync downloads new markdown files
2. Without this setting: UI still shows old file list
3. With this setting: UI automatically shows new files

## .xcdatamodeld File

### What is .xcdatamodeld?
- **Visual schema editor** for defining Core Data models
- **Contains**: Entities, attributes, relationships, validation rules
- **Compiled**: Xcode compiles it into `.mom` (managed object model) files
- **Version Control**: XML-based, can be tracked in Git

### Entity Configuration
- **Codegen**: "Class Definition" lets Xcode auto-generate Swift classes
- **Language**: Swift (vs Objective-C)
- **Relationships**: Must have inverse relationships properly configured

### Relationship Types
- **To One**: `maxCount="1"` (foreign key)
- **To Many**: `toMany="YES"` (one-to-many relationship)
- **Delete Rules**:
  - **Cascade**: Delete related objects when parent is deleted
  - **Nullify**: Set relationship to nil when parent is deleted
  - **Deny**: Prevent deletion if relationships exist

## Data Model Schema

### Current Entities

**GitRepository**
- Primary entity for GitHub repositories
- One-to-many relationship with MarkdownFile
- Stores authentication and sync information

**MarkdownFile** 
- Individual markdown files within repositories
- Many-to-one relationship with GitRepository
- Tracks file metadata and sync status

### Relationships
```
GitRepository (1) ←→ (Many) MarkdownFile
- GitRepository.markdownFiles ← Cascade Delete
- MarkdownFile.repository ← Nullify Delete
```

## Best Practices

### Entity Design
- Always use UUID for primary keys
- Set appropriate default values
- Mark optional attributes correctly
- Use descriptive attribute names

### Relationship Configuration
- Always set inverse relationships
- Choose appropriate delete rules
- Avoid retain cycles in object graphs

### Performance
- Use background contexts for heavy operations
- Batch operations when possible
- Implement proper error handling
- Consider lazy loading for large datasets

## Common Issues & Solutions

### Compilation Errors
- **Problem**: "Cannot find type 'GitRepository'"
- **Solution**: Ensure .xcdatamodeld is added to app target and Codegen is set correctly

### Relationship Issues
- **Problem**: Crashes when accessing relationships
- **Solution**: Verify inverse relationships are configured properly

### Migration Failures
- **Problem**: App crashes after schema changes
- **Solution**: Core Data will handle lightweight migrations automatically for simple changes

### Memory Issues
- **Problem**: High memory usage
- **Solution**: Use background contexts and proper object lifecycle management