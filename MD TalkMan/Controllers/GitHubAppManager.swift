//
//  GitHubAppManager.swift
//  MD TalkMan
//
//  Created by Ganglin Wu on 19/8/25.
//

import Foundation
import UIKit
import SwiftJWT

class GitHubAppManager: ObservableObject {
    @Published var isInstalled: Bool = false
    @Published var isAuthenticated: Bool = false
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var currentUser: GitHubUser?
    @Published var accessibleRepositories: [GitHubRepository] = []
    
    // GitHub App Configuration
    private let appId = "1811852"
    private let clientId = "Iv23li5V6h4u2iRBkrpo" 
    private let clientSecret: String
    private var privateKey: String?
    
    // Installation state
    private var installationId: String?
    private var installationAccessToken: String?
    private var userAccessToken: String?
    
    init() {
        self.clientSecret = GitHubAppManager.loadClientSecret()
        self.privateKey = GitHubAppManager.loadPrivateKey()
        checkExistingInstallation()
    }
    
    // MARK: - Configuration Loading
    
    private static func loadClientSecret() -> String {
        guard let path = Bundle.main.path(forResource: ".env", ofType: nil) else {
            print(".env not found")
            return ""
        }
        
        guard let contents = try? String(contentsOfFile: path) else {
            print("Failed to read .env file")
            return ""
        }
        
        for line in contents.components(separatedBy: .newlines) {
            let parts = line.components(separatedBy: "=")
            if parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces) == "GITHUB_APP_CLIENT_SECRET" {
                let secret = parts[1].trimmingCharacters(in: .whitespaces)
                return secret
            }
        }
        print("GitHub App client secret not found in .env file")
        return ""
    }
    
    private static func loadPrivateKey() -> String? {
        guard let path = Bundle.main.path(forResource: "github-app-private-key", ofType: "pem") else {
            print("❌ Private key file not found in app bundle")
            print("📝 Make sure you've added the .pem file to your Xcode project")
            return nil
        }
        
        guard let privateKeyContent = try? String(contentsOfFile: path) else {
            print("❌ Failed to read private key file")
            return nil
        }
        
        print("✅ Private key loaded successfully")
        return privateKeyContent
    }
    
    private func checkExistingInstallation() {
        // TODO: Check for stored installation ID and tokens
    }
    
    // MARK: - Installation Flow (Phase 1)
    
    func initiateInstallation() {
        isProcessing = true
        errorMessage = nil
        
        let installURL = "https://github.com/apps/md-talkman/installations/new"
        
        guard let url = URL(string: installURL) else {
            errorMessage = "Invalid installation URL"
            isProcessing = false
            return
        }
        
        print("🚀 Opening GitHub App installation page")
        UIApplication.shared.open(url)
        // Note: isProcessing will be reset in handleInstallationCallback
    }
    
    func handleInstallationCallback(installationId: String) async {
        print("🏗️ Processing installation callback for ID: \(installationId)")
        
        await MainActor.run {
            self.installationId = installationId
            self.isInstalled = true
        }
        
        // After installation, we need user authorization
        await initiateUserAuthorization()
    }
    
    // MARK: - User Authorization Flow (Phase 2)
    
    private func initiateUserAuthorization() async {
        print("🔐 Starting user authorization flow")
        
        let callbackURLString = "mdtalkman://auth"
        let state = generateState()
        
        guard var urlComponents = URLComponents(string: "https://github.com/login/oauth/authorize") else {
            await MainActor.run {
                self.errorMessage = "Invalid OAuth endpoint URL"
                self.isProcessing = false
            }
            return
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: callbackURLString),
            URLQueryItem(name: "state", value: state),
        ]
        
        guard let authURL = urlComponents.url else {
            await MainActor.run {
                self.errorMessage = "Failed to create authorization URL"
                self.isProcessing = false
            }
            return
        }
        
        await MainActor.run {
            UIApplication.shared.open(authURL)
        }
    }
    
    func handleAuthorizationCallback(code: String) async {
        print("🔑 Processing authorization callback with code: \(String(code.prefix(10)))...")
        
        // Exchange code for user access token
        await exchangeCodeForUserToken(code: code)
        
        // Get installation access token using JWT + installation ID
        await getInstallationAccessToken()
        
        // Fetch accessible repositories
        await fetchAccessibleRepositories()
        
        await MainActor.run {
            self.isAuthenticated = true
            self.isProcessing = false
        }
    }
    
    // MARK: - JWT Token Generation
    
    private func generateJWT() -> String? {
        guard let privateKeyString = privateKey else {
            print("❌ No private key available for JWT signing")
            return nil
        }
        
        // Create JWT claims
        let now = Date()
        let expiration = now.addingTimeInterval(600) // 10 minutes from now
        
        let claims = GitHubAppJWTClaims(
            iss: appId,                    // App ID as issuer
            iat: Int(now.timeIntervalSince1970),          // Issued at
            exp: Int(expiration.timeIntervalSince1970)    // Expires at
        )
        
        // Create JWT header
        let header = Header(typ: "JWT")
        
        // Create and sign JWT
        var jwt = JWT(header: header, claims: claims)
        
        do {
            // Convert PEM string to private key data
            let privateKeyData = Data(privateKeyString.utf8)
            let signer = JWTSigner.rs256(privateKey: privateKeyData)
            
            let signedJWT = try jwt.sign(using: signer)
            print("✅ JWT generated successfully")
            return signedJWT
            
        } catch {
            print("❌ Failed to sign JWT: \(error)")
            return nil
        }
    }
    
    // MARK: - Token Management
    
    private func exchangeCodeForUserToken(code: String) async {
        print("🔄 Exchanging code for user access token")
        
        guard let url = URL(string: "https://github.com/login/oauth/access_token") else {
            await MainActor.run {
                self.errorMessage = "Invalid token URL"
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let bodyParams = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code
        ]
        
        let bodyString = bodyParams
            .map { "\($0.key)=\($0.value)"}
            .joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 User token exchange response status: \(httpResponse.statusCode)")
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📦 User token response: \(responseString)")
                
                if let accessToken = parseAccessToken(from: responseString) {
                    userAccessToken = accessToken
                    print("✅ User access token obtained")
                } else {
                    await MainActor.run {
                        self.errorMessage = "Failed to parse user access token"
                    }
                }
            }
        } catch {
            print("❌ User token exchange failed: \(error)")
            await MainActor.run {
                self.errorMessage = "User token exchange failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func getInstallationAccessToken() async {
        guard let installationId = installationId else {
            await MainActor.run {
                self.errorMessage = "No installation ID available"
            }
            return
        }
        
        print("🔐 Generating JWT and exchanging for installation access token")
        
        // Generate JWT token
        guard let jwtToken = generateJWT() else {
            await MainActor.run {
                self.errorMessage = "Failed to generate JWT token"
            }
            return
        }
        
        print("🎫 JWT Token generated: \(String(jwtToken.prefix(20)))...")
        
        // Exchange JWT for installation access token
        guard let url = URL(string: "https://api.github.com/app/installations/\(installationId)/access_tokens") else {
            await MainActor.run {
                self.errorMessage = "Invalid installation token URL"
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Installation token response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 401 {
                    await MainActor.run {
                        self.errorMessage = "JWT authentication failed"
                    }
                    return
                } else if httpResponse.statusCode != 201 {
                    await MainActor.run {
                        self.errorMessage = "Installation token request failed with status \(httpResponse.statusCode)"
                    }
                    return
                }
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📦 Installation token response: \(String(responseString.prefix(200)))...")
            }
            
            // Parse installation access token
            let decoder = JSONDecoder()
            let tokenResponse = try decoder.decode(InstallationTokenResponse.self, from: data)
            
            installationAccessToken = tokenResponse.token
            
            print("✅ Installation access token obtained: \(String(tokenResponse.token.prefix(10)))...")
            print("🔍 Debug - Installation ID: \(installationId)")
            print("🔍 Debug - User token: \(userAccessToken?.prefix(10) ?? "nil")...")
            print("🔍 Debug - Installation token: \(installationAccessToken?.prefix(10) ?? "nil")...")
            
        } catch {
            print("❌ Installation token exchange failed: \(error)")
            await MainActor.run {
                self.errorMessage = "Installation token exchange failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func fetchAccessibleRepositories() async {
        guard let token = installationAccessToken else {
            await MainActor.run {
                self.errorMessage = "No access token available"
            }
            return
        }
        
        print("📁 Fetching accessible repositories with token: \(String(token.prefix(10)))...")
        
        // Fetch repositories accessible to this installation (only selected repos!)
        guard let url = URL(string: "https://api.github.com/installation/repositories") else {
            await MainActor.run {
                self.errorMessage = "Invalid repositories API URL"
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Repositories API response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 401 {
                    await MainActor.run {
                        self.errorMessage = "Authentication failed - token may be invalid"
                    }
                    return
                } else if httpResponse.statusCode != 200 {
                    await MainActor.run {
                        self.errorMessage = "API request failed with status \(httpResponse.statusCode)"
                    }
                    return
                }
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📦 Repositories response: \(String(responseString.prefix(500)))...")
            }
            
            // Parse the repositories response (installation endpoint returns wrapped array)
            let decoder = JSONDecoder()
            let repositoriesResponse = try decoder.decode(RepositoriesResponse.self, from: data)
            
            await MainActor.run {
                self.accessibleRepositories = repositoriesResponse.repositories
                print("✅ Fetched \(self.accessibleRepositories.count) installation-accessible repositories")
            }
            
        } catch {
            print("❌ Failed to fetch repositories: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to fetch repositories: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Utility Functions
    
    private func generateState() -> String {
        return UUID().uuidString
    }
    
    private func parseAccessToken(from response: String) -> String? {
        // Try JSON parsing first
        if let data = response.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let accessToken = json["access_token"] as? String {
                    return accessToken
                }
            } catch {
                print("⚠️ JSON parsing failed, trying URL-encoded format")
            }
        }
        
        // Fallback: URL-encoded format parsing
        let params = response.components(separatedBy: "&")
        for param in params {
            let keyValue = param.components(separatedBy: "=")
            if keyValue.count == 2, keyValue[0] == "access_token" {
                return keyValue[1]
            }
        }
        return nil
    }
    
    // MARK: - Public Actions
    
    func connectGitHub() {
        initiateInstallation()
    }
    
    // Temporary manual method for testing
    func testWithInstallationId(_ installationId: String) {
        Task {
            await handleInstallationCallback(installationId: installationId)
        }
    }
    
    func disconnect() {
        isInstalled = false
        isAuthenticated = false
        installationId = nil
        installationAccessToken = nil
        userAccessToken = nil
        accessibleRepositories.removeAll()
        currentUser = nil
        errorMessage = nil
        
        // TODO: Clear stored tokens
        print("🔄 Disconnected from GitHub")
    }
}

// MARK: - Data Models

struct GitHubAppJWTClaims: Claims {
    let iss: String  // App ID (issuer)
    let iat: Int     // Issued at (timestamp)
    let exp: Int     // Expires at (timestamp)
}

struct InstallationTokenResponse: Codable {
    let token: String
    let expiresAt: String
    
    enum CodingKeys: String, CodingKey {
        case token
        case expiresAt = "expires_at"
    }
}

struct RepositoriesResponse: Codable {
    let repositories: [GitHubRepository]
}

struct GitHubRepository: Codable, Identifiable {
    let id: Int
    let name: String
    let fullName: String
    let isPrivate: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case isPrivate = "private"
    }
}
