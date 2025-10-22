//
//  MessageReadDetailsView.swift
//  CreatorLink
//
//  Sheet view showing detailed read/delivered status for each participant in a group message
//

import SwiftUI

struct MessageReadDetailsView: View {
    let message: Message
    let participants: [UserProfile]

    @State private var readStatuses: [String: ReadStatus] = [:]

    enum ReadStatus: Equatable {
        case read(Date)
        case delivered
        case sent
        case unread

        var sortPriority: Int {
            switch self {
            case .read: return 0
            case .delivered: return 1
            case .sent: return 2
            case .unread: return 3
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Read by section
                if !readByParticipants.isEmpty {
                    Section {
                        ForEach(readByParticipants, id: \.id) { participant in
                            ParticipantStatusRow(
                                participant: participant,
                                status: readStatuses[participant.id] ?? .unread
                            )
                        }
                    } header: {
                        Text("Read by (\(readByParticipants.count))")
                    }
                }

                // Delivered to section
                if !deliveredToParticipants.isEmpty {
                    Section {
                        ForEach(deliveredToParticipants, id: \.id) { participant in
                            ParticipantStatusRow(
                                participant: participant,
                                status: readStatuses[participant.id] ?? .delivered
                            )
                        }
                    } header: {
                        Text("Delivered to (\(deliveredToParticipants.count))")
                    }
                }

                // Not delivered section
                if !notDeliveredParticipants.isEmpty {
                    Section {
                        ForEach(notDeliveredParticipants, id: \.id) { participant in
                            ParticipantStatusRow(
                                participant: participant,
                                status: readStatuses[participant.id] ?? .sent
                            )
                        }
                    } header: {
                        Text("Not delivered (\(notDeliveredParticipants.count))")
                    }
                }
            }
            .navigationTitle("Message Info")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadReadStatuses()
        }
    }

    // MARK: - Computed Properties

    private var readByParticipants: [UserProfile] {
        participants
            .filter { participant in
                let userId = participant.id
                if case .read = readStatuses[userId] {
                    return true
                }
                return false
            }
            .sorted { p1, p2 in
                // Sort by most recent read first
                let id1 = p1.id
                let id2 = p2.id
                guard case .read(let date1) = readStatuses[id1],
                      case .read(let date2) = readStatuses[id2] else {
                    return false
                }
                return date1 > date2
            }
    }

    private var deliveredToParticipants: [UserProfile] {
        participants
            .filter { participant in
                let userId = participant.id
                if case .delivered = readStatuses[userId] {
                    return true
                }
                return false
            }
            .sorted { $0.displayName < $1.displayName }
    }

    private var notDeliveredParticipants: [UserProfile] {
        participants
            .filter { participant in
                let userId = participant.id
                let status = readStatuses[userId]
                return status == .sent || status == .unread
            }
            .sorted { $0.displayName < $1.displayName }
    }

    // MARK: - Methods

    private func loadReadStatuses() async {
        var statuses: [String: ReadStatus] = [:]

        for participant in participants {
            let userId = participant.id

            // Skip the sender (they don't read their own message)
            if userId == message.senderId {
                continue
            }

            // Check if user has read the message
            if let readTimestamp = message.readBy[userId] {
                statuses[userId] = .read(readTimestamp)
            } else {
                // If not read, consider it delivered (simplified for now)
                // Future enhancement: track per-user delivery status
                switch message.status {
                case .sending, .sent:
                    statuses[userId] = .sent
                case .delivered, .read:
                    statuses[userId] = .delivered
                }
            }
        }

        readStatuses = statuses
    }
}

// MARK: - Participant Status Row

struct ParticipantStatusRow: View {
    let participant: UserProfile
    let status: MessageReadDetailsView.ReadStatus

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let photoURL = participant.photoURL, let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 40, height: 40)
            }

            // Name and status
            VStack(alignment: .leading, spacing: 4) {
                Text(participant.displayName)
                    .font(.body)

                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Timestamp for read status
            if case .read(let date) = status {
                Text(formattedTime(date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
        switch status {
        case .read(let date):
            return "Read \(formattedRelativeTime(date))"
        case .delivered:
            return "Delivered"
        case .sent:
            return "Sent"
        case .unread:
            return "Not delivered"
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formattedRelativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

#Preview {
    MessageReadDetailsView(
        message: Message(
            id: "1",
            conversationId: "conv1",
            senderId: "user1",
            participantIds: ["user1", "user2", "user3"],
            text: "Hello everyone!",
            timestamp: Date(),
            status: .read,
            readBy: ["user2": Date().addingTimeInterval(-300)],
            imageUrl: nil,
            metadata: nil
        ),
        participants: [
            UserProfile(
                id: "user2",
                displayName: "Alice Johnson",
                email: "alice@example.com",
                photoURL: nil,
                isOnline: true,
                lastSeen: Date()
            ),
            UserProfile(
                id: "user3",
                displayName: "Bob Smith",
                email: "bob@example.com",
                photoURL: nil,
                isOnline: false,
                lastSeen: Date().addingTimeInterval(-3600)
            )
        ]
    )
}
