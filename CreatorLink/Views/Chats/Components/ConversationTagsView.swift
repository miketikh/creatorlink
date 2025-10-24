//
//  ConversationTagsView.swift
//  CreatorLink
//
//  Multi-badge layout for displaying conversation tags in rows
//  Shows max 2-3 badges with priority: Urgent > NeedsResponse > primaryCategory
//

import SwiftUI

struct ConversationTagsView: View {
    let conversation: Conversation
    let userId: String

    private var taggingService = TaggingService.shared

    init(conversation: Conversation, userId: String) {
        self.conversation = conversation
        self.userId = userId
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(displayedBadges, id: \.self) { badge in
                TagBadgeView(
                    emoji: badge.emoji,
                    backgroundColor: badge.backgroundColor
                )
            }
        }
    }

    // MARK: - Badge Display Logic

    private struct BadgeInfo: Hashable {
        let emoji: String
        let backgroundColor: Color
        let priority: Int
    }

    private var displayedBadges: [BadgeInfo] {
        var badges: [BadgeInfo] = []

        // Get effective tags for this user
        let userTags = taggingService.getEffectiveTags(conversation: conversation, userId: userId)

        // Priority 1: Urgent (highest priority)
        if userTags.statuses.contains(.urgent) {
            badges.append(BadgeInfo(
                emoji: StatusTag.urgent.emoji,
                backgroundColor: Color.red.opacity(0.1),
                priority: 1
            ))
        }

        // Priority 2: Needs Response
        if userTags.statuses.contains(.needsResponse) {
            badges.append(BadgeInfo(
                emoji: StatusTag.needsResponse.emoji,
                backgroundColor: .clear,
                priority: 2
            ))
        }

        // Priority 3: Awaiting Reply
        if userTags.statuses.contains(.awaitingReply) {
            badges.append(BadgeInfo(
                emoji: StatusTag.awaitingReply.emoji,
                backgroundColor: .clear,
                priority: 3
            ))
        }

        // Priority 4: Resolved
        if userTags.statuses.contains(.resolved) {
            badges.append(BadgeInfo(
                emoji: StatusTag.resolved.emoji,
                backgroundColor: .clear,
                priority: 4
            ))
        }

        // Priority 5: Primary category (if space allows and not already at max)
        if badges.count < 3, let primaryCategory = conversation.primaryCategory {
            badges.append(BadgeInfo(
                emoji: primaryCategory.emoji,
                backgroundColor: .clear,
                priority: 5
            ))
        } else if badges.count < 3, !userTags.categories.isEmpty {
            // If no primaryCategory, use first category tag
            let firstCategory = userTags.categories[0]
            badges.append(BadgeInfo(
                emoji: firstCategory.emoji,
                backgroundColor: .clear,
                priority: 5
            ))
        }

        // Limit to max 3 badges (already sorted by priority)
        return Array(badges.prefix(3))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        // Urgent + NeedsResponse + Business
        ConversationTagsView(
            conversation: Conversation(
                id: "1",
                participantIds: ["user1", "user2"],
                lastMessage: "Test message",
                lastMessageTime: Date(),
                isGroupChat: false,
                groupName: nil,
                primaryCategory: .business,
                tagsByUser: [
                    "user1": Conversation.UserTagData(
                        categoryTags: [.business],
                        statusTags: [.urgent, .needsResponse]
                    )
                ]
            ),
            userId: "user1"
        )

        // Just category tags
        ConversationTagsView(
            conversation: Conversation(
                id: "2",
                participantIds: ["user1", "user2"],
                lastMessage: "Test message",
                lastMessageTime: Date(),
                isGroupChat: false,
                groupName: nil,
                categoryTags: [.collaboration, .social],
                primaryCategory: .collaboration,
                tagsByUser: [
                    "user1": Conversation.UserTagData(
                        categoryTags: [.collaboration, .social],
                        statusTags: nil
                    )
                ]
            ),
            userId: "user1"
        )

        // Resolved only
        ConversationTagsView(
            conversation: Conversation(
                id: "3",
                participantIds: ["user1", "user2"],
                lastMessage: "Test message",
                lastMessageTime: Date(),
                isGroupChat: false,
                groupName: nil,
                tagsByUser: [
                    "user1": Conversation.UserTagData(
                        categoryTags: nil,
                        statusTags: [.resolved]
                    )
                ]
            ),
            userId: "user1"
        )
    }
    .padding()
}
