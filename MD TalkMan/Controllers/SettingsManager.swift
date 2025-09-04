//
//  SettingsManager.swift
//  MD TalkMan
//
//  Created by Claude on 8/15/25.
//

import Foundation
import CoreData
import AVFoundation

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
    
    @Published var selectedInterjectionVoiceIdentifier: String? {
        didSet {
            print("🔄 SettingsManager: selectedInterjectionVoiceIdentifier changed from \(oldValue ?? "nil") to \(selectedInterjectionVoiceIdentifier ?? "nil")")
            UserDefaults.standard.set(selectedInterjectionVoiceIdentifier, forKey: "selectedInterjectionVoiceIdentifier")
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
        
        self.selectedInterjectionVoiceIdentifier = UserDefaults.standard.string(forKey: "selectedInterjectionVoiceIdentifier")
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
    
    // MARK: - Interjection Voice Management
    func getAvailableFemaleVoices() -> [AVSpeechSynthesisVoice] {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        print("🔍 SettingsManager: Checking \(allVoices.count) total voices for female voices")
        
        // Filter for English voices and prioritize female voices
        var femaleVoices: [AVSpeechSynthesisVoice] = []
        
        // First priority: Voices with gender property set to female
        let genderFemaleVoices = allVoices.filter { voice in
            voice.language.hasPrefix("en") && voice.gender == .female
        }
        femaleVoices.append(contentsOf: genderFemaleVoices)
        print("🔍 SettingsManager: Found \(genderFemaleVoices.count) voices with gender == .female")
        
        // Debug: Print all English voices to see what's available  
        let englishVoices = allVoices.filter { $0.language.hasPrefix("en") }
        print("🔍 SettingsManager: All \(englishVoices.count) English voices available")
        
        // Log only first 5 voices for brevity
        for voice in englishVoices.prefix(5) {
            print("  - \(voice.name) (\(voice.language)) - Gender: \(voice.gender) - Quality: \(voice.quality)")
        }
        if englishVoices.count > 5 {
            print("  ... and \(englishVoices.count - 5) more voices")
        }
        
        // Second priority: Known female names
        let femaleNamePatterns = ["samantha", "ava", "victoria", "allison", "susan", "zoe", "karen", "fiona", "moira", "tessa"]
        
        for voice in allVoices {
            if voice.language.hasPrefix("en") && !femaleVoices.contains(voice) {
                let voiceName = voice.name.lowercased()
                if femaleNamePatterns.contains(where: { voiceName.contains($0) }) {
                    print("✅ SettingsManager: Adding female voice by name: \(voice.name)")
                    femaleVoices.append(voice)
                }
            }
        }
        
        // Third priority: Any non-male names
        let maleNames = ["alex", "daniel", "tom", "fred", "aaron", "arthur", "albert", "diego", "jorge", "rishi"]
        
        for voice in allVoices {
            if voice.language.hasPrefix("en") && !femaleVoices.contains(voice) {
                let voiceName = voice.name.lowercased()
                let isMale = maleNames.contains { voiceName.contains($0) }
                
                if !isMale {
                    print("✅ SettingsManager: Adding non-male voice: \(voice.name)")
                    femaleVoices.append(voice)
                }
            }
        }
        
        print("🎵 SettingsManager: Final female voices list: \(femaleVoices.count) voices")
        for voice in femaleVoices {
            print("  ✓ \(voice.name) (\(voice.language)) - Gender: \(voice.gender)")
        }
        
        // If no female voices found, include all English voices as fallback
        if femaleVoices.isEmpty {
            print("⚠️ SettingsManager: No female voices found, using all English voices as fallback")
            return englishVoices
        }
        
        return femaleVoices
    }
    
    func getSelectedInterjectionVoice() -> AVSpeechSynthesisVoice? {
        guard let identifier = selectedInterjectionVoiceIdentifier else { return nil }
        return AVSpeechSynthesisVoice(identifier: identifier)
    }
    
    func setInterjectionVoice(_ voice: AVSpeechSynthesisVoice) {
        print("🎵 SettingsManager: setInterjectionVoice called with \(voice.name) (identifier: \(voice.identifier))")
        selectedInterjectionVoiceIdentifier = voice.identifier
    }
    
    func getDefaultInterjectionVoice() -> AVSpeechSynthesisVoice? {
        let femaleVoices = getAvailableFemaleVoices()
        return femaleVoices.first ?? AVSpeechSynthesisVoice(language: "en-US")
    }
}