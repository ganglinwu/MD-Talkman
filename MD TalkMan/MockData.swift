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
        
        // Create sample reading progress and parsed content
        createSampleProgress(in: context, for: articles.first!)
        createSampleParsedContent(in: context, for: articles.first!)
        
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
        parsedContent.plainText = """
        Getting Started with SwiftUI
        
        SwiftUI is Apple's modern framework for building user interfaces across all Apple platforms. 
        It uses a declarative syntax that makes it easy to create complex UIs with minimal code.
        
        Key Benefits:
        • Cross-platform compatibility
        • Live previews in Xcode
        • Automatic dark mode support
        
        Here's a simple example:
        
        struct ContentView: View {
            var body: some View {
                Text("Hello, SwiftUI!")
                    .font(.title)
            }
        }
        
        This creates a text view with a title font style.
        """
        parsedContent.lastParsed = Date()
        parsedContent.markdownFiles = file
        
        // Create sample content sections
        let sections = [
            (0, 26, ContentSectionType.header, 1),
            (28, 187, ContentSectionType.paragraph, 0),
            (189, 200, ContentSectionType.header, 2),
            (202, 298, ContentSectionType.list, 0),
            (300, 330, ContentSectionType.paragraph, 0),
            (332, 453, ContentSectionType.codeBlock, 0),
            (455, 500, ContentSectionType.paragraph, 0)
        ]
        
        for (startIdx, endIdx, sectionType, level) in sections {
            let section = ContentSection(context: context)
            section.startIndex = Int32(startIdx)
            section.endIndex = Int32(endIdx)
            section.typeEnum = sectionType
            section.level = Int16(level)
            section.parsedContent = parsedContent
        }
    }
    
    static func createSampleRepository() -> (String, String, String) {
        return ("Sample Repo", "https://github.com/user/sample", "/Documents/Repositories/sample")
    }
    
    static func createSampleFile() -> (String, String, String) {
        return ("Sample Article", "sample.md", "# Sample Content\n\nThis is a sample markdown file for testing.")
    }
}