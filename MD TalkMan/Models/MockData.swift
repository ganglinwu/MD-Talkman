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
        // Load real markdown files from learning_points directory
        let learningPointsPath = "/Users/ganglinwu/code/swiftui/markdown/learning_points"
        let fileManager = FileManager.default
        
        var markdownFiles: [MarkdownFile] = []
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(atPath: learningPointsPath)
            let mdFiles = fileURLs.filter { $0.hasSuffix(".md") }.sorted()
            
            for fileName in mdFiles.prefix(10) { // Limit to first 10 files
                let file = MarkdownFile(context: context)
                file.id = UUID()
                
                // Create readable title from filename
                let title = createReadableTitle(from: fileName)
                file.title = title
                
                file.filePath = "\(learningPointsPath)/\(fileName)"
                file.gitFilePath = "learning_points/\(fileName)"
                file.repository = repository
                file.repositoryId = repository.id
                file.lastCommitHash = "swift\(Int.random(in: 100...999))"
                file.lastModified = Date().addingTimeInterval(-Double.random(in: 0...604800)) // Random within last week
                
                // Get actual file size
                if let attributes = try? fileManager.attributesOfItem(atPath: "\(learningPointsPath)/\(fileName)"),
                   let fileSize = attributes[.size] as? Int64 {
                    file.fileSize = fileSize
                } else {
                    file.fileSize = Int64.random(in: 500...3000)
                }
                
                file.syncStatusEnum = SyncStatus.synced // Learning materials are synced
                file.hasLocalChanges = false
                
                markdownFiles.append(file)
                
                print("📚 Added learning file: \(title)")
            }
            
        } catch {
            print("❌ Error loading learning files: \(error)")
            // Fall back to placeholder files if real files can't be loaded
            return createPlaceholderFiles(in: context, repository: repository)
        }
        
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
        
        do {
            // Read the actual markdown content
            let markdownContent = try String(contentsOfFile: filePath, encoding: .utf8)
            
            // Parse it using our MarkdownParser
            let parser = MarkdownParser()
            parser.processAndSaveMarkdownFile(file, content: markdownContent, in: context)
            
            print("✅ Parsed real content for: \(file.title ?? "Unknown")")
            
        } catch {
            print("❌ Error reading \(file.title ?? "unknown"): \(error)")
            
            // Fall back to placeholder content
            createPlaceholderParsedContent(in: context, for: file)
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