//
//  CoreDataEnums.swift
//  MD TalkMan
//
//  Created by Claude on 8/14/25.
//

import Foundation

// MARK: - SyncStatus Enum
enum SyncStatus: String, CaseIterable {
    case local = "local"
    case synced = "synced"
    case needsSync = "needsSync"
    case conflicted = "conflicted"
    
    var displayName: String {
        switch self {
        case .local:
            return "Local Only"
        case .synced:
            return "Synced"
        case .needsSync:
            return "Needs Sync"
        case .conflicted:
            return "Conflicted"
        }
    }
    
    var iconName: String {
        switch self {
        case .local:
            return "doc.text"
        case .synced:
            return "checkmark.circle.fill"
        case .needsSync:
            return "arrow.clockwise"
        case .conflicted:
            return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - ContentSectionType Enum
enum ContentSectionType: String, CaseIterable {
    case header = "header"
    case paragraph = "paragraph"
    case codeBlock = "codeBlock"
    case list = "list"
    case blockquote = "blockquote"
    case image = "image"
    case table = "table"
    case announcement = "announcement"
    
    var displayName: String {
        switch self {
        case .header:
            return "Header"
        case .paragraph:
            return "Paragraph"
        case .codeBlock:
            return "Code Block"
        case .list:
            return "List"
        case .blockquote:
            return "Quote"
        case .image:
            return "Image"
        case .table:
            return "Table"
        case .announcement:
            return "Announcement"
        }
    }
    
    var isSkippableByDefault: Bool {
        switch self {
        case .codeBlock, .table:
            return true  // Technical content users might want to skip
        case .header, .paragraph, .list, .blockquote, .image:
            return false
        case .announcement:
            return false  // Announcements should not be skipped by default
        }
    }
}

// MARK: - Core Data Extensions
extension MarkdownFile {
    var syncStatusEnum: SyncStatus {
        get { 
            SyncStatus(rawValue: syncStatus ?? "local") ?? .local 
        }
        set { 
            syncStatus = newValue.rawValue 
        }
    }
}

extension ContentSection {
    var typeEnum: ContentSectionType {
        get { 
            ContentSectionType(rawValue: type ?? "paragraph") ?? .paragraph 
        }
        set { 
            type = newValue.rawValue
            // Auto-set isSkippable based on content type if not manually set
            if isSkippable == newValue.isSkippableByDefault {
                isSkippable = newValue.isSkippableByDefault
            }
        }
    }
}