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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
