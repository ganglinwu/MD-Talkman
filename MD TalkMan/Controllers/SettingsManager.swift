//
//  SettingsManager.swift
//  MD TalkMan
//
//  Created by Claude on 8/15/25.
//

import Foundation
import CoreData

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var isDeveloperModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isDeveloperModeEnabled, forKey: "isDeveloperModeEnabled")
        }
    }
    
    // MARK: - Code Block Notification Settings
    enum CodeBlockNotificationStyle: String, CaseIterable {
        case smartDetection = "smart_detection"
        case voiceOnly = "voice_only"
        case tonesOnly = "tones_only"
        case both = "both"
        
        var displayName: String {
            switch self {
            case .smartDetection: return "Smart Detection"
            case .voiceOnly: return "Voice Only"
            case .tonesOnly: return "Tones Only"
            case .both: return "Voice + Tones"
            }
        }
    }
    
    @Published var codeBlockNotificationStyle: CodeBlockNotificationStyle {
        didSet {
            UserDefaults.standard.set(codeBlockNotificationStyle.rawValue, forKey: "codeBlockNotificationStyle")
        }
    }
    
    @Published var isCodeBlockLanguageNotificationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isCodeBlockLanguageNotificationEnabled, forKey: "isCodeBlockLanguageNotificationEnabled")
        }
    }
    
    @Published var codeBlockToneVolume: Float {
        didSet {
            UserDefaults.standard.set(codeBlockToneVolume, forKey: "codeBlockToneVolume")
        }
    }
    
    private init() {
        // Check if running in debug mode by default
        #if DEBUG
        self.isDeveloperModeEnabled = UserDefaults.standard.object(forKey: "isDeveloperModeEnabled") as? Bool ?? true
        #else
        self.isDeveloperModeEnabled = UserDefaults.standard.object(forKey: "isDeveloperModeEnabled") as? Bool ?? false
        #endif
        
        // Load code block notification settings
        let notificationStyleRaw = UserDefaults.standard.string(forKey: "codeBlockNotificationStyle") ?? CodeBlockNotificationStyle.smartDetection.rawValue
        self.codeBlockNotificationStyle = CodeBlockNotificationStyle(rawValue: notificationStyleRaw) ?? .smartDetection
        
        self.isCodeBlockLanguageNotificationEnabled = UserDefaults.standard.object(forKey: "isCodeBlockLanguageNotificationEnabled") as? Bool ?? true
        
        self.codeBlockToneVolume = UserDefaults.standard.object(forKey: "codeBlockToneVolume") as? Float ?? 0.7
    }
    
    func toggleDeveloperMode() {
        isDeveloperModeEnabled.toggle()
    }
    
    func loadSampleDataIfNeeded(in context: NSManagedObjectContext) {
        print("🔍 SettingsManager: loadSampleDataIfNeeded called")
        print("🔍 Developer mode enabled: \(isDeveloperModeEnabled)")
        
        guard isDeveloperModeEnabled else { 
            print("🔍 Developer mode disabled, skipping sample data load")
            return 
        }
        
        // Check if we already have repositories
        let request: NSFetchRequest<GitRepository> = GitRepository.fetchRequest()
        request.fetchLimit = 1
        
        do {
            let count = try context.count(for: request)
            print("🔍 Found \(count) existing repositories")
            
            if count == 0 {
                print("🧪 Developer Mode: Loading sample data...")
                MockData.createSampleData(in: context)
                print("✅ Sample data loaded successfully!")
            } else {
                print("🔍 Sample data already exists, skipping")
            }
        } catch {
            print("❌ Error checking for existing data: \(error)")
        }
    }
    
    func clearSampleData(in context: NSManagedObjectContext) {
        print("🗑️ Starting to clear all data...")
        
        // Clear in dependency order (children first, then parents)
        clearBookmarks(in: context)
        clearContentSections(in: context)
        clearParsedContent(in: context)
        clearReadingProgress(in: context)
        clearMarkdownFiles(in: context)
        clearRepositories(in: context)
        
        do {
            try context.save()
            print("✅ All data cleared and saved")
        } catch {
            print("❌ Error saving after clearing data: \(error)")
        }
    }
    
    private func clearBookmarks(in context: NSManagedObjectContext) {
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        do {
            let bookmarks = try context.fetch(request)
            for bookmark in bookmarks {
                context.delete(bookmark)
            }
            print("🗑️ Cleared \(bookmarks.count) bookmarks")
        } catch {
            print("❌ Error clearing bookmarks: \(error)")
        }
    }
    
    private func clearContentSections(in context: NSManagedObjectContext) {
        let request: NSFetchRequest<ContentSection> = ContentSection.fetchRequest()
        do {
            let sections = try context.fetch(request)
            for section in sections {
                context.delete(section)
            }
            print("🗑️ Cleared \(sections.count) content sections")
        } catch {
            print("❌ Error clearing content sections: \(error)")
        }
    }
    
    private func clearParsedContent(in context: NSManagedObjectContext) {
        let request: NSFetchRequest<ParsedContent> = ParsedContent.fetchRequest()
        do {
            let parsedContent = try context.fetch(request)
            for content in parsedContent {
                context.delete(content)
            }
            print("🗑️ Cleared \(parsedContent.count) parsed content items")
        } catch {
            print("❌ Error clearing parsed content: \(error)")
        }
    }
    
    private func clearReadingProgress(in context: NSManagedObjectContext) {
        let request: NSFetchRequest<ReadingProgress> = ReadingProgress.fetchRequest()
        do {
            let progress = try context.fetch(request)
            for item in progress {
                context.delete(item)
            }
            print("🗑️ Cleared \(progress.count) reading progress items")
        } catch {
            print("❌ Error clearing reading progress: \(error)")
        }
    }
    
    private func clearMarkdownFiles(in context: NSManagedObjectContext) {
        let request: NSFetchRequest<MarkdownFile> = MarkdownFile.fetchRequest()
        do {
            let files = try context.fetch(request)
            for file in files {
                context.delete(file)
            }
            print("🗑️ Cleared \(files.count) markdown files")
        } catch {
            print("❌ Error clearing markdown files: \(error)")
        }
    }
    
    private func clearRepositories(in context: NSManagedObjectContext) {
        let request: NSFetchRequest<GitRepository> = GitRepository.fetchRequest()
        do {
            let repositories = try context.fetch(request)
            for repo in repositories {
                context.delete(repo)
            }
            print("🗑️ Cleared \(repositories.count) repositories")
        } catch {
            print("❌ Error clearing repositories: \(error)")
        }
    }
    
    func forceLoadSampleData(in context: NSManagedObjectContext) {
        // Clear existing data first, then load fresh sample data
        clearSampleData(in: context)
        
        print("🧪 Force loading sample data...")
        
        // Check if directory exists
        let learningPointsPath = "/Users/ganglinwu/code/swiftui/markdown/learning_points"
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: learningPointsPath) {
            print("✅ Directory exists: \(learningPointsPath)")
            do {
                let files = try fileManager.contentsOfDirectory(atPath: learningPointsPath)
                let mdFiles = files.filter { $0.hasSuffix(".md") }
                print("✅ Found \(mdFiles.count) .md files in directory")
            } catch {
                print("❌ Error reading directory: \(error)")
            }
        } else {
            print("❌ Directory does not exist: \(learningPointsPath)")
        }
        
        MockData.createSampleData(in: context)
        print("✅ Sample data loaded successfully!")
    }
}