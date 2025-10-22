//
//  MessageBubbleView.swift
//  CreatorLink
//
//  Reusable message bubble component with styling for sent/received messages
//

import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    var showTimestamp: Bool = true
    var isGroupChat: Bool = false
    var showSenderInfo: Bool = false
    var showSenderAvatar: Bool = false
    var senderName: String? = nil
    var senderPhotoUrl: String? = nil
    var readCount: Int? = nil
    var deliveredCount: Int? = nil
    var totalParticipants: Int? = nil
    var onTapStatusIndicator: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            // Sender name header (only for group chats, not current user)
            if showSenderInfo && isGroupChat && !isFromCurrentUser, let name = senderName {
                MessageSenderHeaderView(senderName: name, alignment: .leading)
                    .padding(.leading, 42) // Align with message text (avatar width + spacing)
            }

            HStack(alignment: .bottom, spacing: 8) {
                // Sender avatar (only for group chats, others' messages)
                if isGroupChat && !isFromCurrentUser {
                    if showSenderAvatar {
                        // Show avatar on the last message in a group (WhatsApp style)
                        if let photoUrl = senderPhotoUrl, let url = URL(string: photoUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Circle()
                                    .fill(Color.blue.opacity(0.3))
                            }
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                        } else {
                            // Placeholder avatar
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 30, height: 30)
                        }
                    } else {
                        // Empty space to maintain alignment for consecutive messages
                        Color.clear
                            .frame(width: 30, height: 30)
                    }
                }

                if isFromCurrentUser {
                    Spacer(minLength: 60)
                }

                VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                    // Message bubble
                    Text(message.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(backgroundColor)
                        .foregroundColor(textColor)
                        .cornerRadius(18)
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: bubbleAlignment)

                    // Timestamp and status (only show if showTimestamp is true)
                    if showTimestamp {
                        HStack(spacing: 4) {
                            Text(formattedTimestamp)
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            if isFromCurrentUser {
                                statusIcon
                            }
                        }
                    }
                }

                if !isFromCurrentUser {
                    Spacer(minLength: 60)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var backgroundColor: Color {
        isFromCurrentUser ? .blue : Color(.systemGray5)
    }

    private var textColor: Color {
        isFromCurrentUser ? .white : .primary
    }

    private var bubbleAlignment: Alignment {
        isFromCurrentUser ? .trailing : .leading
    }

    private var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }

    private var groupReadStatusLabel: String {
        guard let readCount = readCount,
              let totalParticipants = totalParticipants else {
            return "Message status"
        }

        if readCount == 0 {
            return "Read by 0 of \(totalParticipants) people"
        } else if readCount == totalParticipants {
            return "Read by all \(totalParticipants) people"
        } else {
            return "Read by \(readCount) of \(totalParticipants) people"
        }
    }

    private var statusIcon: some View {
        Group {
            // For group chats, show read count
            if isGroupChat, let readCount = readCount {
                HStack(spacing: 2) {
                    // Double checkmark
                    ZStack {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundColor(readCount > 0 ? .blue : .secondary)
                            .offset(x: -2)
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundColor(readCount > 0 ? .blue : .secondary)
                            .offset(x: 2)
                    }

                    // Read count
                    Text("\(readCount)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onTapStatusIndicator?()
                }
                .accessibilityLabel(groupReadStatusLabel)
                .accessibilityHint("Double tap to view read details")
            } else {
                // For one-on-one chats, keep existing behavior
                switch message.status {
                case .sending:
                    // Clock icon for messages being sent
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                case .sent:
                    // Single checkmark (gray) for sent messages
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                case .delivered:
                    // Double checkmark (gray) - two overlapping single checkmarks
                    ZStack {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .offset(x: -2)
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .offset(x: 2)
                    }

                case .read:
                    // Double checkmark (blue) - two overlapping single checkmarks
                    ZStack {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .offset(x: -2)
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .offset(x: 2)
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        MessageBubbleView(
            message: Message(
                id: "1",
                conversationId: "conv1",
                senderId: "user1",
                participantIds: ["user1", "user2"],
                text: "Hey, how are you?",
                timestamp: Date(),
                status: .sent,
                readBy: [:],
                imageUrl: nil,
                metadata: nil
            ),
            isFromCurrentUser: false
        )

        MessageBubbleView(
            message: Message(
                id: "2",
                conversationId: "conv1",
                senderId: "user2",
                participantIds: ["user1", "user2"],
                text: "I'm doing great! Thanks for asking. How about you?",
                timestamp: Date(),
                status: .read,
                readBy: [:],
                imageUrl: nil,
                metadata: nil
            ),
            isFromCurrentUser: true
        )

        MessageBubbleView(
            message: Message(
                id: "3",
                conversationId: "conv1",
                senderId: "user2",
                participantIds: ["user1", "user2"],
                text: "Sending...",
                timestamp: Date(),
                status: .sending,
                readBy: [:],
                imageUrl: nil,
                metadata: nil
            ),
            isFromCurrentUser: true
        )
    }
    .padding()
}
