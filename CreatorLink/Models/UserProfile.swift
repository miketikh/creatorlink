//
//  UserProfile.swift
//  CreatorLink
//
//  Data model for user profiles
//

import Foundation

struct UserProfile: Identifiable, Codable {
    let id: String              // Firebase Auth UID
    let displayName: String
    let email: String
    let photoURL: String?
    let isOnline: Bool
    let lastSeen: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case email
        case photoURL
        case isOnline
        case lastSeen
    }
}
