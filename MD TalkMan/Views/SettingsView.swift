//
//  SettingsView.swift
//  MD TalkMan
//
//  Created by Claude on 8/15/25.
//

import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var showingClearDataAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Developer Mode", isOn: Binding(
                        get: { settingsManager.isDeveloperModeEnabled },
                        set: { newValue in
                            print("🔄 Developer mode toggled to: \(newValue)")
                            settingsManager.isDeveloperModeEnabled = newValue
                            handleDeveloperModeChange(enabled: newValue)
                        }
                    ))
                    
                    if settingsManager.isDeveloperModeEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Developer Mode Enabled")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            Text("Sample repositories and markdown files are available for testing TTS functionality.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Development")
                } footer: {
                    if settingsManager.isDeveloperModeEnabled {
                        Text("Sample data includes 4 markdown articles with pre-converted TTS content for testing audio playback, section navigation, and skippable content features.")
                    } else {
                        Text("Enable developer mode to access sample data for testing TTS functionality.")
                    }
                }
                
                if settingsManager.isDeveloperModeEnabled {
                    Section {
                        Button("Reload Sample Data") {
                            reloadSampleData()
                        }
                        
                        Button("Clear All Data", role: .destructive) {
                            showingClearDataAlert = true
                        }
                    } header: {
                        Text("Developer Actions")
                    } footer: {
                        Text("Use these actions to reset your development environment.")
                    }
                }
                
                Section {
                    LabeledContent("App Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                    LabeledContent("Build Number", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                    
                    #if DEBUG
                    LabeledContent("Build Configuration", value: "Debug")
                    #else
                    LabeledContent("Build Configuration", value: "Release")
                    #endif
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Clear All Data", isPresented: $showingClearDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("This will remove all repositories, files, and reading progress. This action cannot be undone.")
            }
        }
    }
    
    private func handleDeveloperModeChange(enabled: Bool) {
        print("🔄 Handling developer mode change: enabled = \(enabled)")
        
        // Add a small delay to ensure UI updates properly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if enabled {
                // Load sample data when enabling developer mode
                print("📱 Loading sample data...")
                self.settingsManager.loadSampleDataIfNeeded(in: self.viewContext)
            } else {
                // Clear sample data when disabling developer mode
                print("🗑️ Clearing sample data...")
                self.settingsManager.clearSampleData(in: self.viewContext)
            }
        }
    }
    
    private func reloadSampleData() {
        // forceLoadSampleData already clears data first
        settingsManager.forceLoadSampleData(in: viewContext)
    }
    
    private func clearAllData() {
        settingsManager.clearSampleData(in: viewContext)
    }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}