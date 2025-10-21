//
//  ConversationRowView.swift
//  CreatorLink
//
//  Reusable row component for displaying conversation previews
//

import SwiftUI

struct ConversationRowView: View {
    let conversation: Conversation
    let viewModel: ConversationsViewModel

    @State private var otherUser: UserProfile?

    var body: some View {
        HStack(spacing: 12) {
            // Profile photo
            profilePhoto

            // Conversation info
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(conversation.lastMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Timestamp
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .task {
            await loadOtherUser()
        }
    }

    // MARK: - Subviews

    private var profilePhoto: some View {
        Group {
            if let photoURL = otherUser?.photoURL, let url = URL(string: photoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 50, height: 50)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    case .failure:
                        placeholderImage
                    @unknown default:
                        placeholderImage
                    }
                }
            } else {
                placeholderImage
            }
        }
    }

    private var placeholderImage: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 50, height: 50)

            Text(initials)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
        }
    }

    // MARK: - Computed Properties

    private var displayName: String {
        if conversation.isGroupChat {
            return conversation.groupName ?? "Group Chat"
        } else {
            return otherUser?.displayName ?? "User"
        }
    }

    private var initials: String {
        if conversation.isGroupChat {
            return "G"
        } else {
            let name = otherUser?.displayName ?? "U"
            let components = name.split(separator: " ")
            if components.count >= 2 {
                return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
            } else {
                return String(name.prefix(1)).uppercased()
            }
        }
    }

    private var formattedTimestamp: String {
        let calendar = Calendar.current
        let now = Date()
        let messageDate = conversation.lastMessageTime

        // Check if it's today
        if calendar.isDateInToday(messageDate) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: messageDate)
        }

        // Check if it's yesterday
        if calendar.isDateInYesterday(messageDate) {
            return "Yesterday"
        }

        // Check if it's within the last week
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
           messageDate > weekAgo {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Day name (e.g., "Saturday")
            return formatter.string(from: messageDate)
        }

        // Older than a week - show date
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: messageDate)
    }

    // MARK: - Methods

    private func loadOtherUser() async {
        if !conversation.isGroupChat {
            otherUser = await viewModel.getOtherParticipant(in: conversation)
        }
    }
}

#Preview {
    List {
        ConversationRowView(
            conversation: Conversation(
                id: "1",
                participantIds: ["user1", "user2"],
                lastMessage: "Hey, how are you doing today?",
                lastMessageTime: Date().addingTimeInterval(-3600),
                isGroupChat: false,
                groupName: nil
            ),
            viewModel: ConversationsViewModel()
        )
    }
}
