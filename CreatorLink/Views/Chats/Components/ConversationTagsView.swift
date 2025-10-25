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
            // Show category badge first (if exists) - larger
            if let categoryBadge = categoryBadge {
                ZStack(alignment: .topTrailing) {
                    TagBadgeView(
                        emoji: categoryBadge.emoji,
                        backgroundColor: categoryBadge.backgroundColor,
                        accessibilityLabel: categoryBadge.accessibilityLabel,
                        size: 28
                    )

                    // Show AI/USER badge on category badge
                    if let indicator = tagIndicator {
                        Text(indicator.text)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(2)
                            .frame(width: 12, height: 12)
                            .background(indicator.color)
                            .clipShape(Circle())
                            .offset(x: 5, y: -5)
                    }
                }
            }

            // Show status badges second - smaller
            ForEach(statusBadges.indices, id: \.self) { index in
                let badge = statusBadges[index]
                TagBadgeView(
                    emoji: badge.emoji,
                    backgroundColor: badge.backgroundColor,
                    accessibilityLabel: badge.accessibilityLabel,
                    size: 20
                )
            }
        }
    }

    // MARK: - Badge Display Logic

    private struct BadgeInfo: Hashable {
        let emoji: String
        let backgroundColor: Color
        let priority: Int
        let accessibilityLabel: String
    }

    private struct IndicatorInfo {
        let text: String
        let color: Color
    }

    /// Determines which indicator badge to show (AI or USER)
    private var tagIndicator: IndicatorInfo? {
        // Check if user has overridden status tags
        let hasUserOverrideStatus = conversation.tagMetadata?.userOverrideStatus ?? false

        if hasUserOverrideStatus {
            return IndicatorInfo(text: "U", color: .blue)
        }

        // Check if AI suggested tags exist and user hasn't overridden
        let hasAISuggestion = conversation.tagMetadata?.aiSuggestedCategory != nil
        let hasAIConfidence = conversation.tagMetadata?.aiConfidenceScore != nil
        let hasUserOverrideCategory = conversation.tagMetadata?.userOverrideCategory ?? false

        if hasAISuggestion && hasAIConfidence && !hasUserOverrideCategory {
            return IndicatorInfo(text: "AI", color: Color.purple)
        }

        return nil
    }

    /// Category badge - shown first and larger
    private var categoryBadge: BadgeInfo? {
        let userTags = taggingService.getEffectiveTags(conversation: conversation, userId: userId)

        guard !userTags.categories.isEmpty else { return nil }

        let firstCategory = userTags.categories[0]
        return BadgeInfo(
            emoji: firstCategory.emoji,
            backgroundColor: .clear,
            priority: 1,
            accessibilityLabel: "\(firstCategory.displayName) category"
        )
    }

    /// Status badges - shown after category, smaller
    private var statusBadges: [BadgeInfo] {
        var badges: [BadgeInfo] = []
        let userTags = taggingService.getEffectiveTags(conversation: conversation, userId: userId)

        // Priority 1: Urgent (highest priority)
        if userTags.statuses.contains(.urgent) {
            badges.append(BadgeInfo(
                emoji: StatusTag.urgent.emoji,
                backgroundColor: Color.red.opacity(0.1),
                priority: 1,
                accessibilityLabel: "Urgent status"
            ))
        }

        // Priority 2: Needs Response
        if userTags.statuses.contains(.needsResponse) {
            badges.append(BadgeInfo(
                emoji: StatusTag.needsResponse.emoji,
                backgroundColor: .clear,
                priority: 2,
                accessibilityLabel: "Needs response status"
            ))
        }

        // Priority 3: Awaiting Reply
        if userTags.statuses.contains(.awaitingReply) {
            badges.append(BadgeInfo(
                emoji: StatusTag.awaitingReply.emoji,
                backgroundColor: .clear,
                priority: 3,
                accessibilityLabel: "Awaiting reply status"
            ))
        }

        // Priority 4: Resolved
        if userTags.statuses.contains(.resolved) {
            badges.append(BadgeInfo(
                emoji: StatusTag.resolved.emoji,
                backgroundColor: .clear,
                priority: 4,
                accessibilityLabel: "Resolved status"
            ))
        }

        // Limit to max 2 status badges (to keep display clean)
        return Array(badges.prefix(2))
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
