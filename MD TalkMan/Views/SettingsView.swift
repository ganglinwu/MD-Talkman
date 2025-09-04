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
    @EnvironmentObject var apnsManager: APNsManager
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var showingClearDataAlert = false
    @State private var isRequestingPermission = false
    
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
                
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Push Notifications")
                                .font(.body)
                            
                            Text(notificationStatusText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if apnsManager.authorizationStatus == .notDetermined {
                            Button("Enable") {
                                requestNotificationPermission()
                            }
                            .disabled(isRequestingPermission)
                        } else {
                            Image(systemName: notificationStatusIcon)
                                .foregroundColor(notificationStatusColor)
                        }
                    }
                    
                    if settingsManager.isDeveloperModeEnabled && apnsManager.deviceToken != nil {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Device Token (Debug)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(apnsManager.deviceToken?.prefix(16) ?? "None")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if apnsManager.lastNotificationReceived != nil {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last Notification")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let repo = apnsManager.lastNotificationReceived?["repository"] as? String {
                                Text("Repository: \(repo)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Get notified when your GitHub repositories are updated with new markdown content.")
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
                    Picker("Code Block Notifications", selection: Binding(
                        get: { settingsManager.codeBlockNotificationStyle },
                        set: { settingsManager.codeBlockNotificationStyle = $0 }
                    )) {
                        ForEach(SettingsManager.CodeBlockNotificationStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    
                    Toggle("Language Announcements", isOn: Binding(
                        get: { settingsManager.isCodeBlockLanguageNotificationEnabled },
                        set: { settingsManager.isCodeBlockLanguageNotificationEnabled = $0 }
                    ))
                    
                    HStack {
                        Text("Tone Volume")
                        Spacer()
                        Slider(
                            value: Binding(
                                get: { settingsManager.codeBlockToneVolume },
                                set: { settingsManager.codeBlockToneVolume = $0 }
                            ),
                            in: 0.0...1.0,
                            step: 0.1
                        )
                        .frame(width: 100)
                        Text(String(format: "%.0f%%", settingsManager.codeBlockToneVolume * 100))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 35, alignment: .trailing)
                    }
                } header: {
                    Text("Code Block Audio")
                } footer: {
                    Text("Configure audio notifications when entering and exiting code blocks during TTS playback.")
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
    
    // MARK: - Notification Status Helpers
    
    private var notificationStatusText: String {
        switch apnsManager.authorizationStatus {
        case .authorized:
            return apnsManager.isRegistered ? "Enabled" : "Registering..."
        case .denied:
            return "Disabled - Check Settings"
        case .notDetermined:
            return "Not configured"
        case .provisional:
            return "Provisional access"
        case .ephemeral:
            return "Ephemeral access"
        @unknown default:
            return "Unknown status"
        }
    }
    
    private var notificationStatusIcon: String {
        switch apnsManager.authorizationStatus {
        case .authorized:
            return apnsManager.isRegistered ? "checkmark.circle.fill" : "clock.circle"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle"
        case .provisional, .ephemeral:
            return "checkmark.circle"
        @unknown default:
            return "questionmark.circle"
        }
    }
    
    private var notificationStatusColor: Color {
        switch apnsManager.authorizationStatus {
        case .authorized:
            return apnsManager.isRegistered ? .green : .orange
        case .denied:
            return .red
        case .notDetermined:
            return .secondary
        case .provisional, .ephemeral:
            return .blue
        @unknown default:
            return .secondary
        }
    }
    
    private func requestNotificationPermission() {
        isRequestingPermission = true
        
        Task {
            let granted = await apnsManager.requestPermission()
            await MainActor.run {
                isRequestingPermission = false
                if !granted {
                    // Could show an alert explaining why notifications are useful
                    print("📱 Notification permission denied by user")
                }
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