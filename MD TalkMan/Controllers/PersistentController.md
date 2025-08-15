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

## Core Data Migrations: The Swift Equivalent

### Understanding Core Data vs JavaScript ORM Migrations

While JavaScript ORMs require manual migration commands, Core Data handles schema evolution automatically. This is a fundamental difference in philosophy and approach.

#### JavaScript ORMs (Manual Approach)
```javascript
// Manual migration files
// migrations/001_create_users.js
exports.up = (knex) => {
  return knex.schema.createTable('users', (table) => {
    table.increments('id')
    table.string('email')
  })
}

// Manual execution required
npm run migrate:up        # Apply migrations
npm run migrate:down      # Rollback
npm run migrate:status    # Check state
```

#### Core Data (Automatic Approach)
```swift
// Migrations happen automatically during loadPersistentStores
container.loadPersistentStores { _, error in
    // Core Data automatically:
    // 1. Detects schema changes
    // 2. Runs lightweight migrations if possible
    // 3. Updates database structure
    // 4. Makes data available for use
}
```

### When Do Core Data Migrations Run?

**Migration Trigger Points:**
```swift
// In PersistenceController initialization
container.loadPersistentStores { _, error in
    // Core Data migration process:
    // 1. Compare existing database schema with current .xcdatamodeld
    // 2. If schemas match → Skip migration, load immediately
    // 3. If schemas differ → Run automatic migration
    // 4. If migration succeeds → Database ready for use
    // 5. If migration fails → Error callback with details
}
```

**Migration Frequency:**
- ✅ **Only when schema changes** are detected between app versions
- ✅ **Once per app launch** (if migration needed)  
- ✅ **Automatic** - no manual commands or intervention required
- ✅ **Cached** - subsequent launches skip if no changes detected

### Core Data Version Management

#### Folder Structure Purpose
```
DataModel.xcdatamodeld/           # Model Bundle (supports versioning)
└── DataModel.xcdatamodel/        # Version Container (current schema)
    └── contents                  # Actual Schema XML Definition
```

**Why Two Layers Deep?**

1. **`.xcdatamodeld` (Model Bundle)**
   - Container for **multiple versions** of your data model
   - Supports **automatic versioning** and **migration tracking**
   - Similar to a Git repository for your database schema

2. **`.xcdatamodel` (Version Container)**  
   - Represents **one specific version** of your schema
   - Multiple versions can coexist: `DataModel.xcdatamodel`, `DataModel_v2.xcdatamodel`
   - Contains the actual schema definition in XML format

3. **`contents` (Schema XML)**
   - The **actual Core Data schema** in XML format
   - **Generated by Xcode's visual editor** (not at runtime)
   - **Static file** that gets compiled into your app bundle

#### Real-World Versioning Example
```
MyApp.xcdatamodeld/
├── MyApp.xcdatamodel/         # Version 1.0 (original schema)
│   └── contents
├── MyApp_v2.xcdatamodel/      # Version 2.0 (added User.email field)
│   └── contents  
└── MyApp_v3.xcdatamodel/      # Version 3.0 (added Post entity)
    └── contents
```

### Migration Types and Capabilities

#### Automatic Lightweight Migrations
Core Data can automatically handle many common schema changes:

```swift
// These changes trigger automatic lightweight migration:
// ✅ Adding new optional attributes
// ✅ Adding new entities  
// ✅ Renaming entities (with renaming identifier)
// ✅ Adding new relationships
// ✅ Changing optional to required (with default value)
// ✅ Removing attributes or entities
```

#### Manual Complex Migrations
For complex changes requiring custom data transformation:

```swift
// Custom migration for complex scenarios:
let sourceModel = NSManagedObjectModel.mergedModel(from: [Bundle.main])!
let destinationModel = NSManagedObjectModel(contentsOf: modelURL)!
let mappingModel = NSMappingModel(from: [Bundle.main], 
                                 forSourceModel: sourceModel,
                                 destinationModel: destinationModel)

// Required for:
// - Complex data transformations
// - Merging entities
// - Splitting entities
// - Custom business logic during migration
```

### Migration Process Deep Dive

#### What Happens During `loadPersistentStores`?

```swift
container.loadPersistentStores { description, error in
    // Step-by-step migration process:
    
    // 1. SCHEMA COMPARISON
    // Core Data compares existing SQLite schema with current .xcdatamodeld
    
    // 2. MIGRATION DECISION
    // IF schemas match     → Skip to Step 5
    // IF simple changes    → Automatic lightweight migration
    // IF complex changes   → Require manual migration model
    
    // 3. BACKUP CREATION
    // Core Data creates backup of existing database
    
    // 4. SCHEMA TRANSFORMATION
    // - Create new SQLite tables with updated schema
    // - Copy and transform existing data
    // - Update indexes and constraints
    
    // 5. COMPLETION
    // Database ready for use with new schema
    
    if let error = error {
        // Migration failed - handle gracefully
        // Common causes: incompatible changes, insufficient storage
    }
    // Migration succeeded - app can proceed
}
```

#### Performance Characteristics

**Migration Impact:**
- ⏱️ **Duration**: Proportional to database size (MB = seconds, GB = minutes)
- 🔒 **App Blocking**: Migration blocks app launch until complete
- 💾 **Storage**: Requires ~2x database size during migration
- 🔄 **Recovery**: Failed migrations preserve original database

### Migration Best Practices

#### Development Workflow
```swift
// 1. Schema Design Phase
// Edit DataModel.xcdatamodeld in Xcode visual editor
// Add entities, attributes, relationships

// 2. Testing Phase  
// Build and run → Core Data migrates automatically
// Test with existing data to ensure migration works

// 3. Production Deployment
// Deploy app → Users get automatic migration on launch
// Monitor crash reports for migration failures
```

#### Migration Safety Guidelines

**Safe Changes (Automatic):**
```swift
// ✅ Safe additions
@NSManaged public var newOptionalField: String?     // New optional attribute
@NSManaged public var newRequiredWithDefault: Int32 = 0  // Required with default

// ✅ Safe relationships
@NSManaged public var posts: NSSet?  // New to-many relationship

// ✅ Safe entity additions
class NewEntity: NSManagedObject { ... }  // Entirely new entity
```

**Dangerous Changes (Manual Migration Required):**
```swift
// ❌ Requires manual migration
// - Changing attribute types (String → Int)
// - Removing required attributes with existing data  
// - Complex relationship restructuring
// - Merging or splitting entities
```

### Comparison: Core Data vs JavaScript ORMs

| Aspect | JavaScript ORMs | Core Data |
|--------|----------------|-----------|
| **Migration Trigger** | Manual `npm run migrate` | Automatic on app launch |
| **Migration Files** | Separate JavaScript/SQL files | Visual model versions |
| **Rollback Support** | Manual `migrate:down` commands | Forward-only (no rollbacks) |
| **Version Control** | Individual migration files | Complete `.xcdatamodeld` bundle |
| **Development Flow** | Write migration → Run command | Edit visual model → Build app |
| **Production Flow** | Deploy → SSH → Run migrations | Deploy → Users get auto-migration |
| **Error Handling** | Manual intervention required | App handles gracefully or fails safely |
| **Schema Inspection** | Database tools or migration status | Xcode visual model editor |

### Troubleshooting Migration Issues

#### Common Migration Errors
```swift
// Error: Cannot automatically migrate
// Cause: Complex schema changes requiring manual mapping
// Solution: Create NSMappingModel for custom migration

// Error: Insufficient storage space
// Cause: Migration requires temporary space (2x database size)
// Solution: User needs to free device storage

// Error: Incompatible schema versions
// Cause: Database from newer app version opened by older app
// Solution: App version validation and graceful degradation
```

## .xcdatamodeld File Structure

### What is .xcdatamodeld?
- **Visual schema editor** for defining Core Data models in Xcode
- **Contains**: Entities, attributes, relationships, validation rules  
- **Compiled**: Xcode compiles it into `.mom` (managed object model) files at build time
- **Version Control**: XML-based contents file can be tracked in Git
- **Migration Support**: Bundle structure enables automatic schema versioning

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
- **Solution**: Core Data handles lightweight migrations automatically for simple changes
- **Details**: See "Core Data Migrations: The Swift Equivalent" section for comprehensive migration guide

### Memory Issues
- **Problem**: High memory usage
- **Solution**: Use background contexts and proper object lifecycle management