//
//  RepositoryDetailView.swift
//  MD TalkMan
//
//  Created by Claude on 8/14/25.
//

import SwiftUI
import CoreData

struct RepositoryDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var githubApp: GitHubAppManager
    
    let repository: GitRepository
    
    @FetchRequest var markdownFiles: FetchedResults<MarkdownFile>
    
    init(repository: GitRepository) {
        self.repository = repository
        self._markdownFiles = FetchRequest(
            entity: MarkdownFile.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \MarkdownFile.title, ascending: true)],
            predicate: NSPredicate(format: "repository == %@", repository)
        )
    }
    
    var body: some View {
        VStack {
            if markdownFiles.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    
                    Text("No Markdown Files")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("Files from this repository will appear here")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Sync Repository") {
                        Task {
                            await syncSingleRepository()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(githubApp.isProcessing)
                }
                .padding()
            } else {
                List(markdownFiles, id: \.id) { file in
                    NavigationLink(destination: ReaderView(markdownFile: file)) {
                        MarkdownFileRow(file: file, isParsingInProgress: githubApp.isParsingFiles)
                    }
                    .disabled(githubApp.isParsingFiles && file.parsedContent == nil)
                    .opacity((githubApp.isParsingFiles && file.parsedContent == nil) ? 0.6 : 1.0)
                }
            }
        }
        .navigationTitle(repository.name ?? "Repository")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Sync Repository") {
                        Task {
                            await syncSingleRepository()
                        }
                    }
                    
                    Button("Repository Settings") {
                        // TODO: Implement settings
                    }
                    
                    Button("View on GitHub") {
                        if let url = URL(string: repository.remoteURL ?? "") {
                            UIApplication.shared.open(url)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    
    private func syncSingleRepository() async {
        // Find the GitHub repository that matches this Core Data repository
        let repoURL = repository.remoteURL ?? ""
        let hasMatchingRepo = githubApp.accessibleRepositories.contains { repo in
            repoURL.contains(repo.fullName)
        }
        
        if hasMatchingRepo {
            await githubApp.syncAllRepositories(context: viewContext)
        }
    }
}

struct MarkdownFileRow: View {
    let file: MarkdownFile
    let isParsingInProgress: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(file.title ?? "Untitled")
                    .font(.headline)
                
                Text(file.gitFilePath ?? file.filePath ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    // Sync Status
                    Label(file.syncStatusEnum.displayName, 
                          systemImage: file.syncStatusEnum.iconName)
                        .font(.caption2)
                        .foregroundColor(syncStatusColor)
                    
                    // File Size
                    if file.fileSize > 0 {
                        Text(ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .file))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    
                    // Last Modified
                    if let lastModified = file.lastModified {
                        Text(lastModified, formatter: relativeDateFormatter)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                // Parsing Status
                if isParsingInProgress && file.parsedContent == nil {
                    VStack(alignment: .trailing, spacing: 2) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Parsing...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // Reading Progress Indicator
                    if let progress = file.readingProgress {
                        VStack(alignment: .trailing, spacing: 2) {
                            if progress.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else if progress.currentPosition > 0 {
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.blue)
                                
                                Text("\(Int(progress.currentPosition)) chars")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    
                    // Parsed Content Indicator
                    if file.parsedContent != nil {
                        Image(systemName: "waveform")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var syncStatusColor: Color {
        switch file.syncStatusEnum {
        case .synced:
            return .green
        case .needsSync:
            return .orange
        case .conflicted:
            return .red
        case .local:
            return .blue
        }
    }
}

private let relativeDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    formatter.doesRelativeDateFormatting = true
    return formatter
}()

#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    // Get a sample repository
    let request: NSFetchRequest<GitRepository> = GitRepository.fetchRequest()
    request.fetchLimit = 1
    
    if let sampleRepo = try? context.fetch(request).first {
        return NavigationView {
            RepositoryDetailView(repository: sampleRepo)
        }
        .environment(\.managedObjectContext, context)
        .environmentObject(GitHubAppManager())
    } else {
        return Text("No sample data available")
    }
}