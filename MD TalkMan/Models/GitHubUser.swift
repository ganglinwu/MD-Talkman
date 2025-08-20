//
//  GitHubUser.swift
//  MD TalkMan
//
//  Created by Ganglin Wu on 19/8/25.
//

import Foundation

struct GitHubUser: Codable {
    let login: String
    let name: String?
    let avatarUrl: String
    let publicRepos: Int
    let followers: Int
    let following: Int
    let bio: String?
    let location : String?
    let company: String?
    let email: String?
    
    enum CodingKeys: String, CodingKey {
        case login, name, followers, following, bio, location, company, email
        case avatarUrl = "avatar_url"
        case publicRepos = "public_repos"
    }
    
}
