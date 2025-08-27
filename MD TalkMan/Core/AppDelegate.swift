//
//  AppDelegate.swift
//  MD TalkMan
//
//  Created by Claude on 8/24/25.
//

import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    var apnsManager: APNsManager?
    
    func application(_ application: UIApplication, 
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        print("🚀 AppDelegate: didFinishLaunchingWithOptions")
        
        // Check if app was launched from a notification
        if let notificationInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            print("📱 App launched from push notification")
            // Process the notification that launched the app
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.apnsManager?.processRepositoryUpdateNotification(notificationInfo)
            }
        }
        
        return true
    }
    
    // MARK: - Push Notification Callbacks
    
    func application(_ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        
        print("📱 AppDelegate: Successfully registered for remote notifications")
        apnsManager?.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
    }
    
    func application(_ application: UIApplication,
                    didFailToRegisterForRemoteNotificationsWithError error: Error) {
        
        print("❌ AppDelegate: Failed to register for remote notifications: \(error.localizedDescription)")
        apnsManager?.didFailToRegisterForRemoteNotifications(with: error)
    }
    
    // Handle notification when app is in background
    func application(_ application: UIApplication,
                    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        print("📱 AppDelegate: Received remote notification in background")
        apnsManager?.processRepositoryUpdateNotification(userInfo)
        
        // Indicate that we successfully processed the notification
        completionHandler(.newData)
    }
}