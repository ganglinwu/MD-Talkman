//
//  GitHubAppManagerTests.swift
//  MD TalkManTests
//
//  Created by Claude on 8/25/25.
//  Tests for GitHub App integration system
//

import XCTest
import CoreData
@testable import MD_TalkMan

final class GitHubAppManagerTests: XCTestCase {
    
    var githubManager: GitHubAppManager!
    var mockContext: NSManagedObjectContext!
    var testContainer: NSPersistentContainer!
    
    override func setUpWithError() throws {
        // Create in-memory Core Data stack for testing
        testContainer = NSPersistentContainer(name: "DataModel")
        let description = testContainer.persistentStoreDescriptions.first!
        description.url = URL(fileURLWithPath: "/dev/null")
        
        testContainer.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        
        mockContext = testContainer.viewContext
        
        // Clear UserDefaults to ensure clean test state
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "github_installation_id")
        defaults.removeObject(forKey: "github_user_token")
        defaults.removeObject(forKey: "github_installation_token")
        
        githubManager = GitHubAppManager()
    }
    
    override func tearDownWithError() throws {
        githubManager = nil
        mockContext = nil
        testContainer = nil
        
        // Clean up UserDefaults after tests
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "github_installation_id")
        defaults.removeObject(forKey: "github_user_token")
        defaults.removeObject(forKey: "github_installation_token")
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() throws {
        XCTAssertFalse(githubManager.isInstalled)
        XCTAssertFalse(githubManager.isAuthenticated)
        XCTAssertFalse(githubManager.isProcessing)
        XCTAssertNil(githubManager.errorMessage)
        XCTAssertNil(githubManager.currentUser)
        XCTAssertTrue(githubManager.accessibleRepositories.isEmpty)
        XCTAssertFalse(githubManager.isParsingFiles)
        XCTAssertEqual(githubManager.parsingProgress, "")
    }
    
    func testConfigurationLoading() throws {
        // Test that the manager initializes without crashing
        // Even if configuration files are missing in test environment
        XCTAssertNotNil(githubManager)
        
        // In test environment, configuration might not be loaded
        // but the manager should still initialize properly
        XCTAssertFalse(githubManager.isInstalled)
    }
    
    // MARK: - State Management Tests
    
    func testStateTransitions() throws {
        // Test initial state
        XCTAssertFalse(githubManager.isInstalled)
        XCTAssertFalse(githubManager.isAuthenticated)
        
        // Test processing state
        githubManager.isProcessing = true
        XCTAssertTrue(githubManager.isProcessing)
        
        githubManager.isProcessing = false
        XCTAssertFalse(githubManager.isProcessing)
        
        // Test error state
        githubManager.errorMessage = "Test error"
        XCTAssertEqual(githubManager.errorMessage, "Test error")
        
        githubManager.errorMessage = nil
        XCTAssertNil(githubManager.errorMessage)
    }
    
    func testParsingProgressTracking() throws {
        XCTAssertFalse(githubManager.isParsingFiles)
        XCTAssertEqual(githubManager.parsingProgress, "")
        
        githubManager.isParsingFiles = true
        githubManager.parsingProgress = "Parsing file 1 of 10"
        
        XCTAssertTrue(githubManager.isParsingFiles)
        XCTAssertEqual(githubManager.parsingProgress, "Parsing file 1 of 10")
        
        githubManager.isParsingFiles = false
        githubManager.parsingProgress = ""
        
        XCTAssertFalse(githubManager.isParsingFiles)
        XCTAssertEqual(githubManager.parsingProgress, "")
    }
    
    // MARK: - Installation State Persistence Tests
    
    func testInstallationStatePersistence() throws {
        let testInstallationId = "12345"
        let testUserToken = "user_token_123"
        let testInstallationToken = "installation_token_123"
        
        // Store installation data in UserDefaults
        let defaults = UserDefaults.standard
        defaults.set(testInstallationId, forKey: "github_installation_id")
        defaults.set(testUserToken, forKey: "github_user_token")
        defaults.set(testInstallationToken, forKey: "github_installation_token")
        
        // Create new manager instance to test restoration
        let newManager = GitHubAppManager()
        
        // Should restore installed state
        XCTAssertTrue(newManager.isInstalled)
        
        // Note: isAuthenticated will be verified through repository fetching
        // which we can't test without actual network calls
    }
    
    func testCleanInstallationState() throws {
        // Ensure UserDefaults are clean
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "github_installation_id")
        defaults.removeObject(forKey: "github_user_token")
        defaults.removeObject(forKey: "github_installation_token")
        
        let cleanManager = GitHubAppManager()
        
        XCTAssertFalse(cleanManager.isInstalled)
        XCTAssertFalse(cleanManager.isAuthenticated)
    }
    
    // MARK: - User Data Management Tests
    
    func testUserDataHandling() throws {
        // Test basic user data state
        XCTAssertNil(githubManager.currentUser)
        
        // Test that currentUser can be set to nil (basic state management)
        githubManager.currentUser = nil
        XCTAssertNil(githubManager.currentUser)
    }
    
    // MARK: - Repository Data Management Tests
    
    func testRepositoryDataHandling() throws {
        // Test empty repository list
        XCTAssertTrue(githubManager.accessibleRepositories.isEmpty)
        
        // Test adding repositories
        let testRepo1 = GitHubRepository(
            id: 1,
            name: "test-repo-1",
            fullName: "testuser/test-repo-1",
            isPrivate: true
        )
        
        let testRepo2 = GitHubRepository(
            id: 2,
            name: "test-repo-2",
            fullName: "testuser/test-repo-2",
            isPrivate: false
        )
        
        githubManager.accessibleRepositories = [testRepo1, testRepo2]
        
        XCTAssertEqual(githubManager.accessibleRepositories.count, 2)
        XCTAssertEqual(githubManager.accessibleRepositories[0].name, "test-repo-1")
        XCTAssertEqual(githubManager.accessibleRepositories[1].name, "test-repo-2")
        
        // Test clearing repositories
        githubManager.accessibleRepositories = []
        XCTAssertTrue(githubManager.accessibleRepositories.isEmpty)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorStateManagement() throws {
        // Test setting and clearing error messages
        XCTAssertNil(githubManager.errorMessage)
        
        githubManager.errorMessage = "Network error"
        XCTAssertEqual(githubManager.errorMessage, "Network error")
        
        githubManager.errorMessage = "Authentication failed"
        XCTAssertEqual(githubManager.errorMessage, "Authentication failed")
        
        githubManager.errorMessage = nil
        XCTAssertNil(githubManager.errorMessage)
    }
    
    func testErrorStateDuringProcessing() throws {
        // Test error handling during processing
        githubManager.isProcessing = true
        githubManager.errorMessage = "Processing failed"
        
        XCTAssertTrue(githubManager.isProcessing)
        XCTAssertEqual(githubManager.errorMessage, "Processing failed")
        
        // Simulate recovery
        githubManager.isProcessing = false
        githubManager.errorMessage = nil
        
        XCTAssertFalse(githubManager.isProcessing)
        XCTAssertNil(githubManager.errorMessage)
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentStateUpdates() throws {
        let expectation = XCTestExpectation(description: "Concurrent updates")
        expectation.expectedFulfillmentCount = 10
        
        // Perform concurrent state updates
        for i in 0..<10 {
            DispatchQueue.global().async {
                self.githubManager.isProcessing = (i % 2 == 0)
                self.githubManager.errorMessage = "Error \(i)"
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Should handle concurrent updates without crashing
        XCTAssertTrue(true) // Test passes if we reach this point
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryManagementWithLargeRepositoryList() throws {
        // Create many repositories to test memory handling
        var repositories: [GitHubRepository] = []
        
        for i in 0..<1000 {
            let repo = GitHubRepository(
                id: i,
                name: "repo-\(i)",
                fullName: "user/repo-\(i)",
                isPrivate: false
            )
            repositories.append(repo)
        }
        
        githubManager.accessibleRepositories = repositories
        
        XCTAssertEqual(githubManager.accessibleRepositories.count, 1000)
        
        // Clear repositories
        githubManager.accessibleRepositories = []
        
        // Should handle large datasets without memory issues
        XCTAssertTrue(githubManager.accessibleRepositories.isEmpty)
    }
    
    // MARK: - State Consistency Tests
    
    func testStateConsistencyAfterOperations() throws {
        // Test that state remains consistent after various operations
        
        // Simulate installation process
        githubManager.isProcessing = true
        githubManager.isInstalled = false
        githubManager.isAuthenticated = false
        
        // Complete installation
        githubManager.isProcessing = false
        githubManager.isInstalled = true
        
        XCTAssertFalse(githubManager.isProcessing)
        XCTAssertTrue(githubManager.isInstalled)
        XCTAssertFalse(githubManager.isAuthenticated) // Not authenticated until verified
        
        // Simulate authentication
        githubManager.isAuthenticated = true
        // Note: currentUser would be set with actual GitHub user data in real usage
        
        XCTAssertTrue(githubManager.isAuthenticated)
        
        // Simulate logout/disconnection
        githubManager.isInstalled = false
        githubManager.isAuthenticated = false
        githubManager.currentUser = nil
        githubManager.accessibleRepositories = []
        
        XCTAssertFalse(githubManager.isInstalled)
        XCTAssertFalse(githubManager.isAuthenticated)
        XCTAssertTrue(githubManager.accessibleRepositories.isEmpty)
    }
    
    // MARK: - Configuration Validation Tests
    
    func testConfigurationValidation() throws {
        // Test that manager handles missing configuration gracefully
        let manager = GitHubAppManager()
        
        // Should initialize without crashing even if config files are missing
        XCTAssertNotNil(manager)
        XCTAssertFalse(manager.isInstalled)
        XCTAssertFalse(manager.isAuthenticated)
    }
    
    // MARK: - Performance Tests
    
    func testRepositoryListPerformance() throws {
        // Test performance of repository list operations
        measure {
            var repositories: [GitHubRepository] = []
            
            for i in 0..<100 {
                let repo = GitHubRepository(
                    id: i,
                    name: "repo-\(i)",
                    fullName: "user/repo-\(i)",
                    isPrivate: false
                )
                repositories.append(repo)
            }
            
            githubManager.accessibleRepositories = repositories
        }
        
        XCTAssertEqual(githubManager.accessibleRepositories.count, 100)
    }
}