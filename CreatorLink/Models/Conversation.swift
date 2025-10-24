//
//  Conversation.swift
//  CreatorLink
//
//  Data model for conversations
//

import Foundation
import FirebaseFirestore

struct Conversation: Identifiable, Codable, Hashable {
    @DocumentID var id: String?     // Firestore document ID (managed by @DocumentID)
    let participantIds: [String]    // Array of user IDs
    let lastMessage: String
    let lastMessageTime: Date
    let isGroupChat: Bool
    let groupName: String?          // Optional group name for group chats
    let groupImageUrl: String?      // Optional custom image URL for group chats
    let lastMessageSenderId: String? // ID of user who sent the last message
    let lastMessageStatus: MessageStatus? // Status of the last message
    let unreadCounts: [String: Int]? // Denormalized unread count per user (userId: count)
    let mutedBy: [String]?          // Array of user IDs who have muted this conversation
    let aiEnabled: Bool?            // Optional - whether AI assistant is enabled for this conversation
    let aiConfig: AIConfig?         // Optional - AI configuration settings (only present when aiEnabled is true)
    let categoryTags: [ConversationTag]? // Optional - array of category tags (user-selected)
    let primaryCategory: ConversationTag? // Optional - denormalized primary category for filtering
    let tagMetadata: TagMetadata?   // Optional - AI confidence and override tracking
    let tagsByUser: [String: UserTagData]? // Optional - per-user tag data including category and status tags (userId -> UserTagData object)

    /// AI configuration for conversation-level AI features
    struct AIConfig: Codable, Hashable {
        let faqDetectionEnabled: Bool
        let minimumSimilarity: Double

        init(faqDetectionEnabled: Bool = true, minimumSimilarity: Double = 0.85) {
            self.faqDetectionEnabled = faqDetectionEnabled
            self.minimumSimilarity = minimumSimilarity
        }

        enum CodingKeys: String, CodingKey {
            case faqDetectionEnabled
            case minimumSimilarity
        }
    }

    /// Tag metadata for AI suggestions and user overrides
    struct TagMetadata: Codable, Hashable {
        let aiSuggestedCategory: ConversationTag?
        let aiConfidenceScore: Double?
        let userOverrideCategory: Bool
        let userOverrideStatus: Bool
        let lastAIAnalysisTime: Date?

        init(aiSuggestedCategory: ConversationTag? = nil, aiConfidenceScore: Double? = nil, userOverrideCategory: Bool = false, userOverrideStatus: Bool = false, lastAIAnalysisTime: Date? = nil) {
            self.aiSuggestedCategory = aiSuggestedCategory
            self.aiConfidenceScore = aiConfidenceScore
            self.userOverrideCategory = userOverrideCategory
            self.userOverrideStatus = userOverrideStatus
            self.lastAIAnalysisTime = lastAIAnalysisTime
        }

        enum CodingKeys: String, CodingKey {
            case aiSuggestedCategory
            case aiConfidenceScore
            case userOverrideCategory
            case userOverrideStatus
            case lastAIAnalysisTime
        }
    }

    /// Per-user tag data for category and status tags
    /// Enables per-user tag preferences in conversations where different participants
    /// can have different perspectives on the same conversation.
    /// - Category tags can be overridden per-user but default to conversation-level tags
    /// - Status tags are always per-user (no conversation-level default)
    struct UserTagData: Codable, Hashable {
        let categoryTags: [ConversationTag]?
        let statusTags: [StatusTag]?

        init(categoryTags: [ConversationTag]? = nil, statusTags: [StatusTag]? = nil) {
            self.categoryTags = categoryTags
            self.statusTags = statusTags
        }

        enum CodingKeys: String, CodingKey {
            case categoryTags
            case statusTags
        }
    }

    // Custom initializer for manual construction
    init(id: String? = nil, participantIds: [String], lastMessage: String, lastMessageTime: Date, isGroupChat: Bool, groupName: String?, groupImageUrl: String? = nil, lastMessageSenderId: String? = nil, lastMessageStatus: MessageStatus? = nil, unreadCounts: [String: Int]? = nil, mutedBy: [String]? = nil, aiEnabled: Bool? = nil, aiConfig: AIConfig? = nil, categoryTags: [ConversationTag]? = nil, primaryCategory: ConversationTag? = nil, tagMetadata: TagMetadata? = nil, tagsByUser: [String: UserTagData]? = nil) {
        self.id = id
        self.participantIds = participantIds
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
        self.isGroupChat = isGroupChat
        self.groupName = groupName
        self.groupImageUrl = groupImageUrl
        self.lastMessageSenderId = lastMessageSenderId
        self.lastMessageStatus = lastMessageStatus
        self.unreadCounts = unreadCounts
        self.mutedBy = mutedBy
        self.aiEnabled = aiEnabled
        self.aiConfig = aiConfig
        self.categoryTags = categoryTags
        self.primaryCategory = primaryCategory
        self.tagMetadata = tagMetadata
        self.tagsByUser = tagsByUser
    }

    enum CodingKeys: String, CodingKey {
        case id  // Required for @DocumentID to work!
        case participantIds
        case lastMessage
        case lastMessageTime
        case isGroupChat
        case groupName
        case groupImageUrl
        case lastMessageSenderId
        case lastMessageStatus
        case unreadCounts
        case mutedBy
        case aiEnabled
        case aiConfig
        case categoryTags
        case primaryCategory
        case tagMetadata
        case tagsByUser
    }

    // Hashable conformance - include ALL properties that affect UI rendering (per ios_dev_notes.md)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(participantIds)
        hasher.combine(lastMessage)
        hasher.combine(lastMessageTime)
        hasher.combine(isGroupChat)
        hasher.combine(groupName)
        hasher.combine(groupImageUrl)
        hasher.combine(lastMessageSenderId)
        hasher.combine(lastMessageStatus)
        hasher.combine(aiEnabled)
        hasher.combine(aiConfig)
        hasher.combine(categoryTags)
        hasher.combine(primaryCategory)
        hasher.combine(tagMetadata)
        // Note: unreadCounts and tagsByUser are intentionally excluded from hash since they change frequently
        // and we want real-time updates via the listener to trigger UI updates
    }

    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        // Compare unreadCounts to ensure UI updates when counts change
        let unreadCountsEqual: Bool
        if let lhsCounts = lhs.unreadCounts, let rhsCounts = rhs.unreadCounts {
            unreadCountsEqual = lhsCounts == rhsCounts
        } else {
            unreadCountsEqual = lhs.unreadCounts == nil && rhs.unreadCounts == nil
        }

        // Compare mutedBy arrays
        let mutedByEqual: Bool
        if let lhsMuted = lhs.mutedBy, let rhsMuted = rhs.mutedBy {
            mutedByEqual = lhsMuted == rhsMuted
        } else {
            mutedByEqual = lhs.mutedBy == nil && rhs.mutedBy == nil
        }

        // Compare categoryTags arrays
        let categoryTagsEqual: Bool
        if let lhsTags = lhs.categoryTags, let rhsTags = rhs.categoryTags {
            categoryTagsEqual = lhsTags == rhsTags
        } else {
            categoryTagsEqual = lhs.categoryTags == nil && rhs.categoryTags == nil
        }

        // Compare tagsByUser maps
        let tagsByUserEqual: Bool
        if let lhsTagsByUser = lhs.tagsByUser, let rhsTagsByUser = rhs.tagsByUser {
            tagsByUserEqual = lhsTagsByUser == rhsTagsByUser
        } else {
            tagsByUserEqual = lhs.tagsByUser == nil && rhs.tagsByUser == nil
        }

        return lhs.id == rhs.id &&
               lhs.participantIds == rhs.participantIds &&
               lhs.lastMessage == rhs.lastMessage &&
               lhs.lastMessageTime == rhs.lastMessageTime &&
               lhs.isGroupChat == rhs.isGroupChat &&
               lhs.groupName == rhs.groupName &&
               lhs.groupImageUrl == rhs.groupImageUrl &&
               lhs.lastMessageSenderId == rhs.lastMessageSenderId &&
               lhs.lastMessageStatus == rhs.lastMessageStatus &&
               unreadCountsEqual &&
               mutedByEqual &&
               lhs.aiEnabled == rhs.aiEnabled &&
               lhs.aiConfig == rhs.aiConfig &&
               categoryTagsEqual &&
               lhs.primaryCategory == rhs.primaryCategory &&
               lhs.tagMetadata == rhs.tagMetadata &&
               tagsByUserEqual
    }
}
