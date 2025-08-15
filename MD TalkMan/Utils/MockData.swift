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
        // Create sample repository
        let sampleRepo = GitRepository(context: context)
        sampleRepo.id = UUID()
        sampleRepo.name = "Personal Notes"
        sampleRepo.remoteURL = "https://github.com/user/personal-notes"
        sampleRepo.localPath = "/Documents/Repositories/personal-notes"
        sampleRepo.defaultBranch = "main"
        sampleRepo.lastSyncDate = Date()
        sampleRepo.syncEnabled = true
        
        // Create sample markdown files
        let articles = createSampleFiles(in: context, repository: sampleRepo)
        
        // Create sample reading progress and parsed content for multiple files
        for (index, article) in articles.enumerated() {
            if index == 0 {
                // First article gets detailed progress
                createSampleProgress(in: context, for: article)
                createSampleParsedContent(in: context, for: article)
            } else {
                // Other articles get basic parsed content
                createBasicParsedContent(in: context, for: article, index: index)
            }
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
        let files = [
            ("Getting Started with SwiftUI", "getting-started.md", "Learn the basics of SwiftUI development"),
            ("Advanced Core Data", "advanced-coredata.md", "Deep dive into Core Data relationships"),
            ("iOS Speech Recognition", "speech-recognition.md", "Implementing voice features in iOS"),
            ("Git Workflows", "git-workflows.md", "Best practices for version control")
        ]
        
        return files.map { (title, fileName, _) in
            let file = MarkdownFile(context: context)
            file.id = UUID()
            file.title = title
            file.filePath = "/Documents/Repositories/personal-notes/\(fileName)"
            file.gitFilePath = fileName
            file.repository = repository
            file.repositoryId = repository.id
            file.lastCommitHash = "abc\(Int.random(in: 100...999))"
            file.lastModified = Date().addingTimeInterval(-Double.random(in: 0...86400)) // Random within last day
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
    
    private static func createSampleParsedContent(in context: NSManagedObjectContext, for file: MarkdownFile) {
        let parsedContent = ParsedContent(context: context)
        parsedContent.fileId = file.id!
        
        // Create realistic TTS-converted content
        parsedContent.plainText = """
        Heading level 1: Getting Started with SwiftUI. SwiftUI is Apple's modern framework for building user interfaces across all Apple platforms. It uses a declarative syntax that makes it easy to create complex UIs with minimal code. Heading level 2: Key Benefits. • Cross-platform compatibility. • Live previews in Xcode. • Automatic dark mode support. • State management with property wrappers. Heading level 3: Simple Example. Code block in swift begins. [Code content omitted for brevity] Code block ends. This creates a text view with a title font style. You can customize the appearance using modifiers like font, foregroundColor, and padding. Quote: SwiftUI makes building great apps faster and more enjoyable than ever before. End quote. For more information, visit Apple's documentation.
        """
        parsedContent.lastParsed = Date()
        parsedContent.markdownFiles = file
        
        // Create sample content sections that match the TTS text
        let sections = [
            (0, 47, ContentSectionType.header, 1, false),    // "Heading level 1: Getting Started with SwiftUI."
            (48, 201, ContentSectionType.paragraph, 0, false), // Main description paragraph
            (202, 227, ContentSectionType.header, 2, false),   // "Heading level 2: Key Benefits."
            (228, 260, ContentSectionType.list, 0, false),     // Cross-platform compatibility
            (261, 291, ContentSectionType.list, 0, false),     // Live previews
            (292, 328, ContentSectionType.list, 0, false),     // Dark mode support
            (329, 375, ContentSectionType.list, 0, false),     // State management
            (376, 408, ContentSectionType.header, 3, false),   // "Heading level 3: Simple Example."
            (409, 490, ContentSectionType.codeBlock, 0, true), // Code block (skippable)
            (491, 625, ContentSectionType.paragraph, 0, false), // Explanation paragraph
            (626, 732, ContentSectionType.blockquote, 0, false), // Quote
            (733, 784, ContentSectionType.paragraph, 0, false)   // Final paragraph
        ]
        
        for (startIdx, endIdx, sectionType, level, skippable) in sections {
            let section = ContentSection(context: context)
            section.startIndex = Int32(startIdx)
            section.endIndex = Int32(endIdx)
            section.typeEnum = sectionType
            section.level = Int16(level)
            section.isSkippable = skippable
            section.parsedContent = parsedContent
        }
    }
    
    static func createSampleRepository() -> (String, String, String) {
        return ("Sample Repo", "https://github.com/user/sample", "/Documents/Repositories/sample")
    }
    
    private static func createBasicParsedContent(in context: NSManagedObjectContext, for file: MarkdownFile, index: Int) {
        let parsedContent = ParsedContent(context: context)
        parsedContent.fileId = file.id!
        parsedContent.lastParsed = Date()
        parsedContent.markdownFiles = file
        
        // Different content based on the file
        switch index {
        case 1: // Advanced Core Data
            parsedContent.plainText = """
            Heading level 1: Advanced Core Data. Core Data is Apple's framework for managing object graphs and persistence. It provides powerful features like relationship management, data validation, and performance optimization. Heading level 2: Key Features. • Object-relational mapping. • Automatic change tracking. • Lazy loading and batching. • Schema migration support. Code block in swift begins. [Code content omitted for brevity] Code block ends. Understanding these concepts will help you build efficient data-driven applications.
            """
            
        case 2: // iOS Speech Recognition
            parsedContent.plainText = """
            Heading level 1: iOS Speech Recognition. The Speech framework enables your app to convert audio to text with high accuracy. This guide covers implementation patterns and best practices. Heading level 2: Getting Started. • Request user permission for microphone access. • Set up audio session for recording. • Configure speech recognition parameters. • Handle real-time transcription results. Quote: Speech recognition opens up new possibilities for accessibility and hands-free interaction. End quote. Remember to handle errors gracefully and provide fallback options for users.
            """
            
        case 3: // Git Workflows
            parsedContent.plainText = """
            Heading level 1: Git Workflows. Version control is essential for modern software development. This article covers best practices for Git workflows in team environments. Heading level 2: Common Workflows. • Feature branch workflow for isolated development. • Git flow for release management. • GitHub flow for continuous deployment. Heading level 3: Best Practices. Always write descriptive commit messages. Use pull requests for code review. Keep your repository history clean with rebasing.
            """
            
        default:
            parsedContent.plainText = "Sample content for testing text-to-speech functionality."
        }
        
        // Create a few basic sections for each file
        let basicSections = [
            (0, 50, ContentSectionType.header, 1, false),
            (51, 200, ContentSectionType.paragraph, 0, false),
            (201, 250, ContentSectionType.header, 2, false),
            (251, 400, ContentSectionType.paragraph, 0, false)
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