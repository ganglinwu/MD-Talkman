//
//  GitHubManagementView.swift
//  MD TalkMan
//
//  Created by Claude on 8/24/25.
//

import SwiftUI
import CoreData

struct GitHubManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var githubApp: GitHubAppManager
    @State private var showingDisconnectAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("GitHub Connected")
                                .font(.headline)
                            if let user = githubApp.currentUser {
                                Text("Signed in as \(user.login)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                } header: {
                    Text("Connection Status")
                }
                
                Section {
                    HStack {
                        Text("Accessible Repositories")
                        Spacer()
                        Text("\(githubApp.accessibleRepositories.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    ForEach(githubApp.accessibleRepositories) { repo in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(repo.name)
                                .font(.headline)
                            Text(repo.fullName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Image(systemName: repo.isPrivate ? "lock.fill" : "globe")
                                    .font(.caption2)
                                    .foregroundColor(repo.isPrivate ? .orange : .blue)
                                Text(repo.isPrivate ? "Private" : "Public")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    
                    if githubApp.accessibleRepositories.isEmpty {
                        Text("No repositories accessible")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                } header: {
                    Text("Repositories")
                } footer: {
                    Text("These are the repositories you can access through the MD TalkMan GitHub App.")
                }
                
                Section {
                    Button("Refresh Repositories") {
                        // TODO: Implement refresh functionality
                        Task {
                            await githubApp.refreshRepositories()
                        }
                    }
                    .disabled(githubApp.isProcessing)
                    
                    Button("Sync All Repositories") {
                        Task {
                            await githubApp.syncAllRepositories(context: viewContext)
                        }
                    }
                    .disabled(githubApp.isProcessing)
                } header: {
                    Text("Actions")
                }
                
                Section {
                    Button("Disconnect GitHub", role: .destructive) {
                        showingDisconnectAlert = true
                    }
                } footer: {
                    Text("Disconnecting will remove access to your GitHub repositories. You can reconnect at any time.")
                }
            }
            .navigationTitle("GitHub Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Disconnect GitHub?", isPresented: $showingDisconnectAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Disconnect", role: .destructive) {
                    githubApp.disconnect()
                    dismiss()
                }
            } message: {
                Text("This will disconnect your GitHub account and remove access to repositories. You can reconnect at any time.")
            }
        }
    }
}

#Preview {
    GitHubManagementView()
        .environmentObject(GitHubAppManager())
}