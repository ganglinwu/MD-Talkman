//
//  APNsManagerTests.swift
//  MD TalkManTests
//
//  Created by Claude on 8/25/25.
//  Tests for APNs push notification system
//

import XCTest
import CoreData
import UserNotifications
@testable import MD_TalkMan

final class APNsManagerTests: XCTestCase {
    
    var apnsManager: APNsManager!
    var mockContext: NSManagedObjectContext!
    var testContainer: NSPersistentContainer!
    
    override func setUpWithError() throws {
        // Create test persistence controller with in-memory store
        let testPersistenceController = PersistenceController(inMemory: true)
        testContainer = testPersistenceController.container
        mockContext = testContainer.viewContext
        
        // Create APNsManager with test persistence controller
        apnsManager = APNsManager(persistenceController: testPersistenceController)
        
        // Reset the instance state for clean testing
        resetAPNsManagerState()
    }
    
    private func resetAPNsManagerState() {
        // Reset published properties to initial state
        apnsManager.isRegistered = false
        apnsManager.deviceToken = nil
        apnsManager.authorizationStatus = .notDetermined
        apnsManager.lastNotificationReceived = nil
        
        // Clear UserDefaults for webhook URL
        UserDefaults.standard.removeObject(forKey: "webhookServerURL")
    }
    
    override func tearDownWithError() throws {
        apnsManager = nil
        mockContext = nil
        testContainer = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() throws {
        XCTAssertFalse(apnsManager.isRegistered)
        XCTAssertNil(apnsManager.deviceToken)
        // authorizationStatus will be checked by the system
        XCTAssertNil(apnsManager.lastNotificationReceived)
    }
    
    // MARK: - Device Token Processing Tests
    
    func testDeviceTokenConversion() throws {
        // Create mock device token data
        let mockTokenData = Data([0x12, 0x34, 0x56, 0x78, 0xAB, 0xCD, 0xEF, 0x00])
        
        // Create expectation for async operation
        let expectation = expectation(description: "Device token should be set")
        
        // Process the token
        apnsManager.didRegisterForRemoteNotifications(withDeviceToken: mockTokenData)
        
        // Wait for the async dispatch to main queue to complete
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        
        // Wait for expectation
        waitForExpectations(timeout: 1.0)
        
        // Verify token conversion - each byte formatted as 2-digit lowercase hex
        XCTAssertNotNil(apnsManager.deviceToken)
        XCTAssertEqual(apnsManager.deviceToken, "12345678abcdef00")
        XCTAssertTrue(apnsManager.isRegistered)
    }
    
    func testDeviceTokenRegistrationFailure() throws {
        let mockError = NSError(domain: "TestError", code: 100, userInfo: [NSLocalizedDescriptionKey: "Mock registration failure"])
        
        // Process the error
        apnsManager.didFailToRegisterForRemoteNotifications(with: mockError)
        
        // Verify error handling
        XCTAssertFalse(apnsManager.isRegistered)
        XCTAssertNil(apnsManager.deviceToken)
    }
    
    // MARK: - Webhook Server Configuration Tests
    
    func testWebhookServerURLConfiguration() throws {
        let testURL = "https://test.example.com"
        
        // Set webhook URL
        apnsManager.setWebhookServerURL(testURL)
        
        // Verify URL is stored and retrieved
        let retrievedURL = apnsManager.getConfiguredWebhookServerURL()
        XCTAssertEqual(retrievedURL, testURL)
    }
    
    func testDefaultWebhookServerURL() throws {
        // Clear any stored URL
        UserDefaults.standard.removeObject(forKey: "webhookServerURL")
        
        // Get default URL
        let defaultURL = apnsManager.getConfiguredWebhookServerURL()
        
        // Should return the production server URL
        XCTAssertNotNil(defaultURL)
        XCTAssertTrue(defaultURL!.contains("18.140.54.239"))
    }
    
    // MARK: - Basic Notification Processing Tests
    
    func testValidRepositoryUpdateNotification() throws {
        // Create test repository in Core Data
        let repository = createTestRepository()
        try mockContext.save()
        
        // Create valid notification payload
        let notificationPayload: [AnyHashable: Any] = [
            "repository": repository.name!,
            "event_type": "push",
            "has_markdown": true,
            "branch": "main"
        ]
        
        // Process the notification
        apnsManager.processRepositoryUpdateNotification(notificationPayload)
        
        // Wait a moment for async processing
        let expectation = XCTestExpectation(description: "Notification processing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify notification was stored
        XCTAssertNotNil(apnsManager.lastNotificationReceived)
        XCTAssertEqual(apnsManager.lastNotificationReceived?["repository"] as? String, repository.name)
    }
    
    func testInvalidNotificationPayload() throws {
        // Create invalid notification payload (missing required fields)
        let invalidPayload: [AnyHashable: Any] = [
            "repository": "test-repo",
            "event_type": "push"
            // Missing "has_markdown" field
        ]
        
        // Process the invalid notification
        apnsManager.processRepositoryUpdateNotification(invalidPayload)
        
        // Should not crash
        XCTAssertTrue(true)
    }
    
    // MARK: - Configuration Tests
    
    func testConfigurationPersistence() throws {
        let testURL = "https://test-server.com"
        
        // Set and verify URL persistence
        apnsManager.setWebhookServerURL(testURL)
        XCTAssertEqual(apnsManager.getConfiguredWebhookServerURL(), testURL)
        
        // Clear and verify default
        UserDefaults.standard.removeObject(forKey: "webhookServerURL")
        let defaultURL = apnsManager.getConfiguredWebhookServerURL()
        XCTAssertNotNil(defaultURL)
    }
    
    // MARK: - Helper Methods
    
    private func createTestRepository() -> GitRepository {
        let repository = GitRepository(context: mockContext)
        // Core Data automatically generates UUID for ID
        repository.name = "Test Repository"
        repository.remoteURL = "https://github.com/test/repo"
        repository.localPath = "/test/repo"
        repository.defaultBranch = "main"
        repository.syncEnabled = true
        repository.lastSyncDate = Date()
        
        return repository
    }
}