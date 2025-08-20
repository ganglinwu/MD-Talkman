//
//  GitHubAuthManager.swift
//  MD TalkMan
//
//  Created by Ganglin Wu on 19/8/25.
//

import Foundation
import UIKit
import OAuthSwift

class GitHubAuthManager :ObservableObject{
    @Published var isAuthenticated: Bool = false
    @Published var isAuthenticating: Bool = false
    @Published var errorMessage: String?
    @Published var currentUser: GitHubUser?
    
    private var oAuthSwift: OAuthSwift?
    private var clientID = "Ov23liLcFThDeBbquqIk"
    private var clientSecret = ""
    
    init() {
        self.clientSecret = GitHubAuthManager.loadClientSecret()
        setupOAuth()
        checkExistingAuth()
    }
    
    private func setupOAuth() {
        guard !clientSecret.isEmpty else {
            errorMessage = "Client Secret is missing from environment variables"
            return
        }
        oAuthSwift = OAuth2Swift(
            consumerKey: clientID,
            consumerSecret: clientSecret,
            authorizeUrl: "https://github.com/login/oauth/authorize",
            accessTokenUrl: "https://github.com/login/oauth/access_token",
            responseType: "code"
        )
    }
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
            if parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces) == "GITHUB_CLIENT_SECRET" {
                let secret = parts[1].trimmingCharacters(in: .whitespaces)
                return secret
            }
        }
        print("github client secret not found in .env file")
        return ""
        
    }

    private func checkExistingAuth() {
        // implement check for stored token
    }
    
    func authenticate() {
        guard let oAuthSwift = oAuthSwift else {
            errorMessage = "OAuth Not configured"
            return
        }
        
        isAuthenticating = true
        errorMessage = nil
        
        let callbackURLString = "mdtalkman://oauth/callback"
        
        let scope = "repo user"
        
        let state = generateState()
        
        
        guard var urlComponents = URLComponents(string: "https://github.com/login/oauth/authorize") else {
            errorMessage = "Invalid OAuth Endpoint URL"
            isAuthenticating = false
            return
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: callbackURLString),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: state),
        ]
        
        guard let authURL = urlComponents.url else {
            errorMessage = "Failed to create authorization URL"
            isAuthenticating = false
            return
        }
        
        // Open Safari for OAuth
        UIApplication.shared.open(authURL)
        
        // Note: isAuthenticating will be set to false in handleAuthSuccess or handleAuthError
    }
    
    private func generateState() -> String {
        return UUID().uuidString
    }
    
    private func handleAuthSuccess(accessToken: String) {
       // store access token
        print("🎉 Authentication successful! Token: \(String(accessToken.prefix(10)))...")
        
        isAuthenticated = true
        isAuthenticating = false
        
    // TODO: store token securely and fetch user info
    }
    
    private func handleAuthError(error: Error) {
        isAuthenticated = false
        isAuthenticating = false
        
        print("❌ Authentication Error: \(error)")
        
        errorMessage = "Authentication failed: \(error.localizedDescription)"
    }
    
    func logout() {
        isAuthenticated = false
        currentUser = nil
        errorMessage = nil
        
        // TODO: clear stored token
    }
    
    func exchangeCodeForToken(code: String) async {
        print("🔄 Starting token exchange for code: \(String(code.prefix(10)))...")
        
        guard let url = URL(string: "https://github.com/login/oauth/access_token") else {
            await MainActor.run {
                self.errorMessage = "Invalid token URL"
                self.isAuthenticating = false
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let bodyParams = [
            "client_id": clientID,
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
                print("📡 Token exchange response status: \(httpResponse.statusCode)")
            }
               
            if let responseString = String(data: data, encoding: .utf8) {
                print("📦 Token response: \(responseString)")
                
                if let accessToken = parseAccessToken(from: responseString) {
                    await MainActor.run {
                        self.handleAuthSuccess(accessToken: accessToken)
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = "Failed to parse access token from response"
                        self.isAuthenticating = false
                    }
                }
            }
        } catch {
            print("❌ Token exchange failed: \(error)")
            await MainActor.run {
                self.errorMessage = "Token exchange failed: \(error.localizedDescription)"
                self.isAuthenticating = false
            }
        }
    }
    
    private func parseAccessToken(from response: String) -> String? {
        // Try JSON parsing first (GitHub's default response format)
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
}
