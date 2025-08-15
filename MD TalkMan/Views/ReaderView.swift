//
//  ReaderView.swift
//  MD TalkMan
//
//  Created by Claude on 8/14/25.
//

import SwiftUI
import CoreData

struct ReaderView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var ttsManager = TTSManager()
    @State private var showingVoiceSettings = false
    
    let markdownFile: MarkdownFile
    
    // Sample markdown content for testing
    private let sampleMarkdown = """
# Getting Started with SwiftUI

SwiftUI is Apple's modern framework for building user interfaces across all Apple platforms.

## Key Features

SwiftUI provides several **important benefits**:

- Declarative syntax
- Live previews in Xcode  
- Automatic dark mode support
- Cross-platform compatibility

Here's a simple example:

```swift
struct ContentView: View {
    var body: some View {
        Text("Hello, SwiftUI!")
            .font(.title)
    }
}
```

> SwiftUI makes it easy to create beautiful, responsive user interfaces with minimal code.

## Getting Started

To start using SwiftUI, simply create a new iOS project in Xcode and select the SwiftUI interface option.

### Installation

1. Open Xcode
2. Create new project
3. Select SwiftUI template
4. Start coding!

This framework will revolutionize how you build iOS apps.
"""
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text(markdownFile.title ?? "Unknown File")
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack {
                    Image(systemName: markdownFile.syncStatusEnum.iconName)
                        .foregroundColor(markdownFile.syncStatusEnum == .synced ? .green : .orange)
                    
                    Text(markdownFile.syncStatusEnum.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            
            // Current Section Info
            if let sectionInfo = ttsManager.getCurrentSectionInfo() {
                HStack {
                    Image(systemName: sectionInfo.isSkippable ? "forward.fill" : "text.alignleft")
                    Text("\(sectionInfo.type.displayName)")
                    
                    if sectionInfo.type == .header {
                        Text("Level \(sectionInfo.level)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    if sectionInfo.isSkippable {
                        Text("Skippable")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                .font(.subheadline)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            // Playback Status
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: playbackStateIcon)
                        .foregroundColor(playbackStateColor)
                        .font(.title3)
                    
                    Text(playbackStateText)
                        .font(.headline)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Position: \(ttsManager.currentPosition)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if let voice = ttsManager.selectedVoice {
                            HStack(spacing: 4) {
                                if ttsManager.isVoiceLoading {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }
                                Text(voice.name)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                
                // Error Message Display
                if let errorMessage = ttsManager.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        Button("Dismiss") {
                            ttsManager.errorMessage = nil
                        }
                        .font(.caption2)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }
                
                // Voice Loading Indicator
                if ttsManager.isVoiceLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        
                        Text("Loading voice...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                // Speed Control
                HStack {
                    Text("Speed:")
                        .font(.subheadline)
                    
                    Text("\(String(format: "%.1fx", ttsManager.playbackSpeed))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Slider(value: Binding(
                        get: { ttsManager.playbackSpeed },
                        set: { ttsManager.setPlaybackSpeed($0) }
                    ), in: 0.5...2.0, step: 0.1)
                }
            }
            .padding()
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Controls
            VStack(spacing: 16) {
                // Primary Controls
                HStack(spacing: 30) {
                    Button(action: { ttsManager.rewind() }) {
                        Image(systemName: "gobackward.5")
                            .font(.title2)
                    }
                    .disabled(ttsManager.playbackState == .preparing || ttsManager.playbackState == .loading)
                    
                    Button(action: togglePlayback) {
                        Image(systemName: playPauseIcon)
                            .font(.title)
                            .frame(width: 60, height: 60)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    .disabled(ttsManager.playbackState == .preparing || ttsManager.playbackState == .loading)
                    
                    Button(action: { ttsManager.stop() }) {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                    }
                    .disabled(ttsManager.playbackState == .idle)
                }
                
                // Navigation Controls
                HStack(spacing: 20) {
                    Button("Previous Section") {
                        ttsManager.skipToPreviousSection()
                    }
                    .disabled(ttsManager.currentSectionIndex <= 0)
                    
                    Button("Next Section") {
                        ttsManager.skipToNextSection()
                    }
                    .disabled(ttsManager.currentSectionIndex >= (markdownFile.parsedContent?.contentSection?.count ?? 1) - 1)
                }
                .font(.subheadline)
                
                // Skip Controls
                if ttsManager.canSkipCurrentSection() {
                    Button("Skip Technical Section") {
                        ttsManager.skipToNextSection()
                    }
                    .foregroundColor(.orange)
                    .font(.subheadline)
                }
            }
            .padding()
            
            Spacer()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingVoiceSettings = true
                } label: {
                    Image(systemName: "speaker.wave.3")
                }
            }
        }
        .sheet(isPresented: $showingVoiceSettings) {
            VoiceSettingsView(ttsManager: ttsManager)
        }
        .onAppear {
            setupContent()
        }
    }
    
    // MARK: - Private Methods
    private func setupContent() {
        // Parse the sample markdown content
        let parser = MarkdownParser()
        parser.processAndSaveMarkdownFile(markdownFile, content: sampleMarkdown, in: viewContext)
        
        // Load the content into TTS manager
        ttsManager.loadMarkdownFile(markdownFile, context: viewContext)
    }
    
    private func togglePlayback() {
        switch ttsManager.playbackState {
        case .idle, .paused:
            ttsManager.play()
        case .playing:
            ttsManager.pause()
        case .preparing:
            break // Do nothing
        }
    }
    
    // MARK: - Computed Properties
    private var playPauseIcon: String {
        switch ttsManager.playbackState {
        case .idle, .paused:
            return "play.fill"
        case .playing:
            return "pause.fill"
        case .preparing, .loading:
            return "hourglass"
        case .error(_):
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var playbackStateIcon: String {
        switch ttsManager.playbackState {
        case .idle:
            return "speaker.slash"
        case .playing:
            return "speaker.wave.3"
        case .paused:
            return "speaker.wave.1"
        case .preparing, .loading:
            return "hourglass"
        case .error(_):
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var playbackStateColor: Color {
        switch ttsManager.playbackState {
        case .idle:
            return .gray
        case .playing:
            return .green
        case .paused:
            return .orange
        case .preparing, .loading:
            return .blue
        case .error(_):
            return .red
        }
    }
    
    private var playbackStateText: String {
        switch ttsManager.playbackState {
        case .idle:
            return "Ready to Play"
        case .playing:
            return "Playing"
        case .paused:
            return "Paused"
        case .preparing:
            return "Preparing..."
        case .loading:
            return "Loading..."
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    // Get a sample markdown file from the preview data
    let request: NSFetchRequest<MarkdownFile> = MarkdownFile.fetchRequest()
    request.fetchLimit = 1
    
    if let sampleFile = try? context.fetch(request).first {
        return NavigationView {
            ReaderView(markdownFile: sampleFile)
        }
        .environment(\.managedObjectContext, context)
    } else {
        return Text("No sample data available")
    }
}