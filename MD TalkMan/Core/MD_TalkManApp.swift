//
//  MD_TalkManApp.swift
//  MD TalkMan
//
//  Created by Ganglin Wu on 6/8/25.
//

import SwiftUI

@main
struct MD_TalkManApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        print("🚀 App: MD_TalkManApp init called")
        // Load sample data on app startup if needed
        SettingsManager.shared.loadSampleDataIfNeeded(in: persistenceController.container.viewContext)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
