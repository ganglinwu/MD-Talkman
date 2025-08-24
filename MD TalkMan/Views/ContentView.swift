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
    @StateObject private var settingsManager = SettingsManager.shared
    @EnvironmentObject private var githubApp: GitHubAppManager
    @State private var showingSettings = false
    @State private var showingGitHubManagement = false
    @State private var debugInfo = "App starting..."
    
    var body: some View {
        NavigationView {
            VStack {
                // GitHub Integration Status
                if githubApp.isAuthenticated {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("GitHub Connected")
                                .font(.headline)
                            Spacer()
                        }
                        
                        HStack {
                            if githubApp.isProcessing {
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                    Text("Syncing...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else if githubApp.isParsingFiles {
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                    Text("Parsing files...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text("\(githubApp.accessibleRepositories.count) repositories")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            Button("Manage") {
                                showingGitHubManagement = true
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                } else if githubApp.isInstalled {
                    VStack(spacing: 8) {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Completing Setup...")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                }
                if repositories.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: settingsManager.isDeveloperModeEnabled ? "flask" : "folder.badge.plus")
                            .imageScale(.large)
                            .foregroundStyle(.tint)
                            .font(.system(size: 48))
                        
                        Text("Welcome to MD TalkMan")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if settingsManager.isDeveloperModeEnabled {
                            VStack(spacing: 8) {
                                Text("Developer mode is enabled, but no sample data is loaded")
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Text(debugInfo)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Button("Load Sample Data") {
                                debugInfo = "Loading sample data..."
                                settingsManager.forceLoadSampleData(in: viewContext)
                                debugInfo = "Sample data loaded!"
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(githubApp.isAuthenticated && !githubApp.accessibleRepositories.isEmpty)
                        } else {
                            if githubApp.isAuthenticated && !githubApp.accessibleRepositories.isEmpty {
                                VStack(spacing: 8) {
                                    Text("GitHub Connected - Tap 'Sync Repositories' to load your markdown files")
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                    
                                    Text(debugInfo)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .multilineTextAlignment(.center)
                                }
                            } else {
                                Text("Connect your GitHub repositories to start reading")
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            VStack(spacing: 12) {
                                if githubApp.isAuthenticated {
                                    Button(githubApp.isProcessing ? "Syncing..." : githubApp.isParsingFiles ? "Parsing..." : "Sync Repositories") {
                                        Task {
                                            await githubApp.syncAllRepositories(context: viewContext)
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(githubApp.isProcessing || githubApp.isParsingFiles)
                                } else {
                                    Button(githubApp.isProcessing ? "Connecting..." : "Connect GitHub") {
                                        githubApp.connectGitHub()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(githubApp.isProcessing)
                                
                                if let error = githubApp.errorMessage {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.center)
                                        .padding(.top, 8)
                                }
                                }
                                
                                Button("Try Developer Mode") {
                                    showingSettings = true
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                } else {
                    List(repositories, id: \.id) { repository in
                        NavigationLink(destination: RepositoryDetailView(repository: repository)) {
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
                                
                                // Show file count
                                if let fileCount = repository.markdownFiles?.count {
                                    Text("\(fileCount) files")
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Repositories")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if githubApp.isAuthenticated {
                        Button("Refresh") {
                            Task {
                                await githubApp.syncAllRepositories(context: viewContext)
                            }
                        }
                        .disabled(githubApp.isProcessing)
                    } else {
                        Button("Connect") {
                            githubApp.connectGitHub()
                        }
                        .disabled(githubApp.isProcessing)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingGitHubManagement) {
                GitHubManagementView()
            }
            .onAppear {
                debugInfo = "Developer mode: \(settingsManager.isDeveloperModeEnabled), Repos: \(repositories.count), GitHub: \(githubApp.accessibleRepositories.count)"
            }
            .onChange(of: githubApp.isAuthenticated) {
                debugInfo = "GitHub auth changed - Repos: \(repositories.count), GitHub: \(githubApp.accessibleRepositories.count)"
            }
            .onChange(of: repositories.count) {
                debugInfo = "Core Data repos changed - Repos: \(repositories.count), GitHub: \(githubApp.accessibleRepositories.count)"
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
