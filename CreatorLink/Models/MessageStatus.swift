//
//  MessageStatus.swift
//  CreatorLink
//
//  Enum representing message delivery status
//

import Foundation

enum MessageStatus: String, Codable {
    case sending    // Message is being sent
    case sent       // Message sent to server
    case delivered  // Message delivered to recipient
    case read       // Message read by recipient
}
