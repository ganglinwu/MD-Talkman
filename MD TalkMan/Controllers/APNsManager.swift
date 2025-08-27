//
//  APNsManager.swift
//  MD TalkMan
//
//  Created by Claude on 8/24/25.
//

import Foundation
import UserNotifications
import UIKit
import CoreData

class APNsManager: NSObject, ObservableObject {
    static let shared = APNsManager()
    
    @Published var isRegistered = false
    @Published var deviceToken: String?
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var lastNotificationReceived: [AnyHashable: Any]?
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let githubManager = GitHubAppManager()
    private let persistenceController: PersistenceController
    
    override init() {
        self.persistenceController = PersistenceController.shared
        super.init()
        notificationCenter.delegate = self
        checkAuthorizationStatus()
    }
    
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
        super.init()
        notificationCenter.delegate = self
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                authorizationStatus = granted ? .authorized : .denied
            }
            
            if granted {
                await registerForPushNotifications()
            }
            
            return granted
        } catch {
            print("❌ Failed to request notification permission: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                
                if settings.authorizationStatus == .authorized {
                    Task {
                        await self.registerForPushNotifications()
                    }
                }
            }
        }
    }
    
    // MARK: - Device Token Registration
    
    @MainActor
    func registerForPushNotifications() async {
        guard authorizationStatus == .authorized else {
            print("⚠️ Not authorized for push notifications")
            return
        }
        
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        
        DispatchQueue.main.async {
            self.deviceToken = token
            self.isRegistered = true
        }
        
        print("📱 Device token received: \(String(token.prefix(8)))...")
        
        // Send device token to webhook server
        Task {
            await sendDeviceTokenToServer(token)
        }
    }
    
    func didFailToRegisterForRemoteNotifications(with error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
        DispatchQueue.main.async {
            self.isRegistered = false
        }
    }
    
    // MARK: - Server Communication
    
    private func sendDeviceTokenToServer(_ token: String) async {
        guard let webhookServerURL = getWebhookServerURL() else {
            print("⚠️ No webhook server URL configured")
            return
        }
        
        let url = URL(string: "\(webhookServerURL)/webhook/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = [
            "device_token": token,
            "bundle_id": Bundle.main.bundleIdentifier ?? "com.yourcompany.mdtalkman",
            "platform": "ios"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("✅ Device token successfully registered with webhook server")
            } else {
                print("⚠️ Failed to register device token with webhook server")
            }
        } catch {
            print("❌ Error sending device token to server: \(error)")
        }
    }
    
    private func getWebhookServerURL() -> String? {
        // Check for webhook server URL in UserDefaults or use default
        if let savedURL = UserDefaults.standard.string(forKey: "webhookServerURL"), !savedURL.isEmpty {
            return savedURL
        }
        
        // Default webhook server URL from existing production configuration
        return "http://18.140.54.239" // Production webhook server on EC2
    }
    
    // MARK: - Configuration
    
    func setWebhookServerURL(_ url: String) {
        UserDefaults.standard.set(url, forKey: "webhookServerURL")
        print("🔧 Webhook server URL updated to: \(url)")
    }
    
    func getConfiguredWebhookServerURL() -> String? {
        return getWebhookServerURL()
    }
    
    // MARK: - Notification Processing
    
    func processRepositoryUpdateNotification(_ userInfo: [AnyHashable: Any]) {
        guard let repositoryName = userInfo["repository"] as? String,
              let eventType = userInfo["event_type"] as? String,
              let hasMarkdown = userInfo["has_markdown"] as? Bool else {
            print("⚠️ Invalid notification payload")
            return
        }
        
        print("📱 Processing repository update notification:")
        print("   Repository: \(repositoryName)")
        print("   Event: \(eventType)")
        print("   Has Markdown: \(hasMarkdown)")
        
        DispatchQueue.main.async {
            self.lastNotificationReceived = userInfo
        }
        
        // If the notification indicates markdown changes, trigger a repository sync
        if hasMarkdown {
            Task {
                await handleMarkdownUpdateNotification(repositoryName: repositoryName)
            }
        }
    }
    
    private func handleMarkdownUpdateNotification(repositoryName: String) async {
        print("📝 Handling markdown update for repository: \(repositoryName)")
        
        // Find the repository in Core Data and trigger sync
        let context = persistenceController.container.newBackgroundContext()
        
        await context.perform {
            let fetchRequest: NSFetchRequest<GitRepository> = GitRepository.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "name == %@", repositoryName)
            fetchRequest.fetchLimit = 1
            
            do {
                let repositories = try context.fetch(fetchRequest)
                
                if let repository = repositories.first {
                    print("🔍 Found repository: \(repository.name ?? "Unknown")")
                    
                    // Mark repository as needing sync
                    repository.lastSyncDate = Date.distantPast // Force sync
                    
                    // Update all markdown files in this repository to need sync
                    if let markdownFiles = repository.markdownFiles?.allObjects as? [MarkdownFile] {
                        for file in markdownFiles {
                            file.syncStatus = SyncStatus.needsSync.rawValue
                        }
                        print("📄 Marked \(markdownFiles.count) files as needing sync")
                    }
                    
                    // Save changes
                    do {
                        try context.save()
                        print("✅ Repository sync flags updated successfully")
                    } catch {
                        print("❌ Failed to save repository sync flags: \(error)")
                    }
                } else {
                    print("⚠️ Repository not found in Core Data: \(repositoryName)")
                }
            } catch {
                print("❌ Failed to fetch repository: \(error)")
            }
        }
        
        // Trigger sync on main thread after Core Data operations complete
        await MainActor.run {
            self.triggerRepositorySync(repositoryName: repositoryName)
        }
    }
    
    private func triggerRepositorySync(repositoryName: String) {
        // Post notification that repository needs sync
        // This can be observed by UI components to show sync status
        NotificationCenter.default.post(
            name: .repositoryNeedsSync,
            object: nil,
            userInfo: ["repositoryName": repositoryName]
        )
        
        print("🔄 Triggered sync for repository: \(repositoryName)")
        
        // TODO: If GitHubManager has an active sync method, call it here
        // Example: GitHubAppManager.shared.syncRepository(named: repositoryName)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension APNsManager: UNUserNotificationCenterDelegate {
    
    // Called when app is in foreground and notification arrives
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        let userInfo = notification.request.content.userInfo
        print("📱 Notification received while app is in foreground")
        
        processRepositoryUpdateNotification(userInfo)
        
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Called when user taps on notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        print("📱 User tapped notification")
        
        processRepositoryUpdateNotification(userInfo)
        
        // TODO: Navigate to the specific repository or file mentioned in notification
        
        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let repositoryNeedsSync = Notification.Name("repositoryNeedsSync")
}
