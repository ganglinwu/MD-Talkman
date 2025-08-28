//
//  AudioFeedbackSettingsView.swift
//  MD TalkMan
//
//  Created by Claude on 8/15/25.
//

import SwiftUI

struct AudioFeedbackSettingsView: View {
    let audioFeedback: AudioFeedbackManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Enable Audio Feedback", isOn: Binding(
                        get: { audioFeedback.isEnabled },
                        set: { audioFeedback.setEnabled($0) }
                    ))
                    
                    if audioFeedback.isEnabled {
                        VStack {
                            HStack {
                                Text("Volume")
                                Spacer()
                                Text("\(Int(audioFeedback.volume * 100))%")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: Binding(
                                get: { audioFeedback.volume },
                                set: { audioFeedback.setVolume($0) }
                            ), in: 0...1, step: 0.1)
                        }
                    }
                } header: {
                    Text("Audio Feedback Settings")
                } footer: {
                    Text("Audio feedback provides sound cues for playback state changes, section transitions, and button interactions.")
                }
                
                if audioFeedback.isEnabled {
                    Section {
                        Button("Test Play Sound") {
                            audioFeedback.playFeedback(for: .playStarted)
                        }
                        
                        Button("Test Pause Sound") {
                            audioFeedback.playFeedback(for: .playPaused)
                        }
                        
                        Button("Test Section Change") {
                            audioFeedback.playFeedback(for: .sectionChanged)
                        }
                        
                        Button("Test Completion Sound") {
                            audioFeedback.playFeedback(for: .playCompleted)
                        }
                        
                        Button("Test Error Sound") {
                            audioFeedback.playFeedback(for: .error)
                        }
                        
                        Button("Test Code Block Start") {
                            audioFeedback.playFeedback(for: .codeBlockStart)
                        }
                        
                    } header: {
                        Text("Test Audio Feedback")
                    } footer: {
                        Text("Tap these buttons to preview different audio feedback sounds.")
                    }
                    
                    Section {
                        Button("Driving Mode (Loud & Clear)") {
                            audioFeedback.applyDrivingPreset()
                        }
                        .foregroundColor(.blue)
                        
                        Button("Quiet Mode (Subtle)") {
                            audioFeedback.applyQuietPreset()
                        }
                        .foregroundColor(.green)
                        
                        Button("Silent Mode (Off)") {
                            audioFeedback.applyOffPreset()
                        }
                        .foregroundColor(.red)
                        
                    } header: {
                        Text("Quick Presets")
                    } footer: {
                        Text("Choose a preset that matches your listening environment.")
                    }
                }
            }
            .navigationTitle("Audio Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let audioFeedback = AudioFeedbackManager()
    return AudioFeedbackSettingsView(audioFeedback: audioFeedback)
}