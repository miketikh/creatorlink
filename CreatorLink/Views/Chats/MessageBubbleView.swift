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

    var body: some View {
        HStack {
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

                // Timestamp and status
                HStack(spacing: 4) {
                    Text(formattedTimestamp)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if isFromCurrentUser {
                        statusIcon
                    }
                }
            }

            if !isFromCurrentUser {
                Spacer(minLength: 60)
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

    private var statusIcon: some View {
        Group {
            switch message.status {
            case .sending:
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            case .sent:
                Image(systemName: "checkmark")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            case .delivered:
                Image(systemName: "checkmark.circle")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            case .read:
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.blue)
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
