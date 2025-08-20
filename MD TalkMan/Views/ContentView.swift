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
    @EnvironmentObject private var githubAuth: GitHubAuthManager
    @EnvironmentObject private var githubApp: GitHubAppManager
    @State private var showingSettings = false
    @State private var debugInfo = "App starting..."
    
    var body: some View {
        NavigationView {
            VStack {
                VStack(spacing: 12){
                    // GitHub Apps Integration
                    if githubApp.isAuthenticated {
                        VStack(spacing: 8) {
                            Text("GitHub App Connected!")
                                .foregroundColor(.green)
                                .font(.headline)
                            
                            Text("\(githubApp.accessibleRepositories.count) repositories accessible")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            
                            ForEach(githubApp.accessibleRepositories) { repo in
                                Text("📁 \(repo.name)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            Button("Disconnect") {
                                githubApp.disconnect()
                            }
                            .buttonStyle(.bordered)
                        }
                    } else if githubApp.isInstalled {
                        VStack(spacing: 8) {
                            Text("App Installed - Completing Authorization...")
                                .foregroundColor(.orange)
                                .font(.headline)
                            
                            if githubApp.isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    } else {
                        Button(githubApp.isProcessing ? "Installing App..." : "Connect GitHub (App)"){
                            githubApp.connectGitHub()
                        }
                        .disabled(githubApp.isProcessing)
                        .buttonStyle(.borderedProminent)
                        
                        if let error = githubApp.errorMessage {
                            Text("Error: \(error)")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        // Manual test - replace with your actual installation ID
                        VStack(spacing: 4) {
                            Text("If redirected to web page, use manual method:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Button("Continue with Installation ID: 81856427") {
                                // Your actual installation ID from GitHub
                                githubApp.testWithInstallationId("81856427")
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                        }
                    }
                    
                    Divider()
                    
                    // Legacy OAuth (for comparison)
                    VStack(spacing: 8) {
                        Text("Legacy OAuth (for testing)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if githubAuth.isAuthenticated {
                            Text("OAuth connected!")
                                .foregroundColor(.green)
                            if let user = githubAuth.currentUser {
                               Text("Hello, \(user.login)")
                            }
                            Button("Logout OAuth") {
                                githubAuth.logout()
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button(githubAuth.isAuthenticating ? "Authenticating..." : "Connect OAuth"){
                                githubAuth.authenticate()
                            }
                            .disabled(githubAuth.isAuthenticating)
                            .buttonStyle(.bordered)
                            
                            if let error = githubAuth.errorMessage {
                                Text("OAuth Error: \(error)")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                    }
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
                        } else {
                            Text("Connect your GitHub repositories to start reading")
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            
                            VStack(spacing: 12) {
                                Button("Add Repository") {
                                    // TODO: Add repository functionality
                                }
                                .buttonStyle(.borderedProminent)
                                
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
                    Button("Add") {
                        // TODO: Add repository functionality
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .onAppear {
                debugInfo = "Developer mode: \(settingsManager.isDeveloperModeEnabled), Repos: \(repositories.count)"
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
