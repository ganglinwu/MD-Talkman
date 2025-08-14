//
//  ContentView.swift
//  MD TalkMan
//
//  Created by Ganglin Wu on 6/8/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \GitRepository.name, ascending: true)],
        animation: .default)
    private var repositories: FetchedResults<GitRepository>
    
    var body: some View {
        NavigationView {
            VStack {
                if repositories.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "folder.badge.plus")
                            .imageScale(.large)
                            .foregroundStyle(.tint)
                            .font(.system(size: 48))
                        
                        Text("Welcome to MD TalkMan")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Add a GitHub repository to get started")
                            .foregroundStyle(.secondary)
                        
                        Button("Add Repository") {
                            // TODO: Add repository functionality
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(repositories, id: \.id) { repository in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(repository.name ?? "Unknown Repository")
                                .font(.headline)
                            
                            Text(repository.remoteURL ?? "No URL")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            if let lastSync = repository.lastSyncDate {
                                Text("Last synced: \(lastSync, formatter: dateFormatter)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Repositories")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        // TODO: Add repository functionality
                    }
                }
            }
        }
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
