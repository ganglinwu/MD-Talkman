//
//  VoiceSettingsView.swift
//  MD TalkMan
//
//  Created by Claude on 8/15/25.
//

import SwiftUI
import AVFoundation

struct VoiceSettingsView: View {
    @ObservedObject var ttsManager: TTSManager
    @ObservedObject private var settingsManager = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var testText = "Hello! This is a sample of how this voice sounds when reading your markdown content."
    @State private var interjectionTestText = "swift code"
    @State private var selectedInterjectionVoice: AVSpeechSynthesisVoice?
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Voice", selection: Binding(
                        get: { 
                            ttsManager.selectedVoice ?? AVSpeechSynthesisVoice(language: "en-US")!
                        },
                        set: { newVoice in
                            ttsManager.setVoice(newVoice)
                        }
                    )) {
                        ForEach(ttsManager.getAvailableVoices(), id: \.identifier) { voice in
                            VStack(alignment: .leading) {
                                Text(voice.name)
                                    .font(.headline)
                                Text("\(voice.language) • \(voice.quality.displayName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(voice)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .disabled(ttsManager.isVoiceLoading)
                    
                    Button("Test Voice") {
                        testCurrentVoice()
                    }
                    .foregroundColor(.blue)
                    .disabled(ttsManager.isVoiceLoading)
                    
                } header: {
                    Text("Main Reading Voice")
                } footer: {
                    Text("Enhanced and Premium voices provide more natural speech quality.")
                }
                
                Section {
                    Picker("Interjection Voice", selection: Binding(
                        get: { 
                            selectedInterjectionVoice ?? settingsManager.getAvailableFemaleVoices().first ?? AVSpeechSynthesisVoice(language: "en-US")!
                        },
                        set: { newVoice in
                            print("🔄 VoiceSettingsView: Voice picker changed to: \(newVoice.name)")
                            selectedInterjectionVoice = newVoice
                            // Save to settings without triggering @Published update immediately
                            DispatchQueue.main.async {
                                settingsManager.setInterjectionVoice(newVoice)
                            }
                        }
                    )) {
                        ForEach(settingsManager.getAvailableFemaleVoices(), id: \.identifier) { voice in
                            VStack(alignment: .leading) {
                                Text(voice.name)
                                    .font(.headline)
                                Text("\(voice.language) • \(voice.gender.displayName) • \(voice.quality.displayName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(voice)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                    TextField("Interjection Test Text", text: $interjectionTestText)
                    
                    Button("Test Interjection Voice") {
                        testInterjectionVoice()
                    }
                    .foregroundColor(.blue)
                    
                } header: {
                    Text("Interjection Voice")
                } footer: {
                    Text("Voice used for code block announcements and other interjections. Should contrast with main reading voice.")
                }
                
                Section {
                    VStack {
                        HStack {
                            Text("Speed")
                            Spacer()
                            Text("\(String(format: "%.1f", ttsManager.playbackSpeed))x")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { ttsManager.playbackSpeed },
                            set: { ttsManager.setPlaybackSpeed($0) }
                        ), in: 0.5...2.0, step: 0.1)
                    }
                    
                    VStack {
                        HStack {
                            Text("Pitch")
                            Spacer()
                            Text(String(format: "%.1f", ttsManager.pitchMultiplier))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { ttsManager.pitchMultiplier },
                            set: { ttsManager.setPitchMultiplier($0) }
                        ), in: 0.5...2.0, step: 0.1)
                    }
                    
                    VStack {
                        HStack {
                            Text("Volume")
                            Spacer()
                            Text("\(Int(ttsManager.volumeMultiplier * 100))%")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { ttsManager.volumeMultiplier },
                            set: { ttsManager.setVolumeMultiplier($0) }
                        ), in: 0.1...1.0, step: 0.1)
                    }
                    
                } header: {
                    Text("Voice Parameters")
                } footer: {
                    Text("Adjust speed for driving comfort. Lower pitch can sound more natural for some voices.")
                }
                
                Section {
                    TextField("Test Text", text: $testText, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Button("Test with Current Settings") {
                        testCurrentVoice()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(ttsManager.isVoiceLoading)
                    
                } header: {
                    Text("Voice Test")
                } footer: {
                    Text("Use this to test how different voices and settings sound with your content.")
                }
                
                Section {
                    if ttsManager.isVoiceLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading voice...")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else if let currentVoice = ttsManager.selectedVoice {
                        LabeledContent("Current Voice", value: currentVoice.name)
                        LabeledContent("Language", value: currentVoice.language)
                        LabeledContent("Quality", value: currentVoice.quality.displayName)
                        LabeledContent("Gender", value: currentVoice.gender.displayName)
                    }
                } header: {
                    Text("Current Settings")
                }
                
                Section {
                    NavigationLink("Audio Feedback Settings") {
                        AudioFeedbackSettingsView(audioFeedback: ttsManager.getAudioFeedbackManager())
                    }
                } header: {
                    Text("Audio Feedback")
                } footer: {
                    Text("Configure sound notifications for playback state changes and interactions.")
                }
            }
            .navigationTitle("Voice Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Initialize selectedInterjectionVoice from settings
                selectedInterjectionVoice = settingsManager.getSelectedInterjectionVoice() ?? settingsManager.getAvailableFemaleVoices().first
                print("🚀 VoiceSettingsView: Initialized with interjection voice: \(selectedInterjectionVoice?.name ?? "none")")
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        resetToDefaults()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func testCurrentVoice() {
        print("🔊 VoiceSettingsView: Testing main TTS voice using shared synthesizer...")
        
        // Pause main TTS if it's playing
        let wasPlaying = ttsManager.playbackState == .playing
        if wasPlaying {
            ttsManager.pause()
        }
        
        // Get the shared synthesizer from TTSManager
        guard let sharedSynthesizer = ttsManager.getSynthesizer() else {
            print("❌ VoiceSettingsView: No shared synthesizer available")
            return
        }
        
        // Create test utterance with current settings
        let testUtterance = AVSpeechUtterance(string: testText)
        testUtterance.voice = ttsManager.selectedVoice ?? AVSpeechSynthesisVoice(language: "en-US")
        testUtterance.rate = AVSpeechUtteranceDefaultSpeechRate * ttsManager.playbackSpeed
        testUtterance.pitchMultiplier = ttsManager.pitchMultiplier
        testUtterance.volume = ttsManager.volumeMultiplier
        
        print("🔊 VoiceSettingsView: Testing voice: \(testUtterance.voice?.name ?? "default")")
        
        // Use the shared synthesizer
        sharedSynthesizer.speak(testUtterance)
        
        print("✅ VoiceSettingsView: Test utterance queued with shared synthesizer")
    }
    
    private func testInterjectionVoice() {
        print("🔊 VoiceSettingsView: Testing interjection voice using production speech synthesis...")
        
        // Get the InterjectionManager from TTSManager
        let interjectionManager = ttsManager.getInterjectionManager()
        
        // Test direct language notification (this is what the production system uses)
        print("🔊 VoiceSettingsView: Testing language notification for: '\(interjectionTestText)'")
        
        // Use the production method directly - this will use the shared synthesizer
        // and proper voice selection just like real interjections
        interjectionManager.testLanguageNotification(interjectionTestText, ttsManager: ttsManager) {
            print("✅ VoiceSettingsView: Interjection voice test completed successfully")
        }
    }
    
    private func resetToDefaults() {
        ttsManager.setPlaybackSpeed(0.5)
        ttsManager.setPitchMultiplier(1.0)
        ttsManager.setVolumeMultiplier(1.0)
        // Voice will reset to best available automatically
        if let defaultVoice = ttsManager.getAvailableVoices().first {
            ttsManager.setVoice(defaultVoice)
        }
    }
}

// MARK: - Extensions for Display Names
extension AVSpeechSynthesisVoiceQuality {
    var displayName: String {
        switch self {
        case .default:
            return "Standard"
        case .enhanced:
            return "Enhanced"
        case .premium:
            return "Premium"
        @unknown default:
            return "Unknown"
        }
    }
}

extension AVSpeechSynthesisVoiceGender {
    var displayName: String {
        switch self {
        case .unspecified:
            return "Unspecified"
        case .male:
            return "Male"
        case .female:
            return "Female"
        @unknown default:
            return "Unknown"
        }
    }
}


#Preview {
    VoiceSettingsView(ttsManager: TTSManager())
}