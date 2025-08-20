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
    @StateObject private var githubApp = GitHubAppManager()
    
    init() {
        print("🚀 App: MD_TalkManApp init called")
        // Load sample data on app startup if needed
        SettingsManager.shared.loadSampleDataIfNeeded(in: persistenceController.container.viewContext)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(githubApp)
                .onOpenURL { url in
                    // Handle GitHub App callbacks
                    if url.scheme == "mdtalkman" {
                        if url.host == "install" {
                            // Handle installation callback: mdtalkman://install?installation_id=12345
                            if let installationId = extractInstallationId(from: url) {
                                Task {
                                    await githubApp.handleInstallationCallback(installationId: installationId)
                                }
                            }
                        } else if url.host == "auth" {
                            // Handle authorization callback: mdtalkman://auth?code=abc123
                            if let code = extractAuthCode(from: url) {
                                Task {
                                    await githubApp.handleAuthorizationCallback(code: code)
                                }
                            }
                        }
                    }
                }
        }
    }
    
    func extractAuthCode(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false), let queryItems = components.queryItems else {
            return nil
        }
        
        return queryItems.first(where: { $0.name == "code" })?.value
    }
    
    func extractInstallationId(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false), let queryItems = components.queryItems else {
            return nil
        }
        
        return queryItems.first(where: { $0.name == "installation_id" })?.value
    }
}
