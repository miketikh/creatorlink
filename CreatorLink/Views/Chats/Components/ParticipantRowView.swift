//
//  ParticipantRowView.swift
//  CreatorLink
//
//  Reusable list row component for displaying group participants
//

import SwiftUI

struct ParticipantRowView: View {
    let participant: UserProfile
    var showOnlineStatus: Bool = true
    var isCurrentUser: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // User avatar
            if let photoURL = participant.photoURL, let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                // Placeholder avatar
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(participant.displayName.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                    )
            }

            // User info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(participant.displayName)
                        .font(isCurrentUser ? .headline : .body)
                        .foregroundColor(.primary)

                    if isCurrentUser {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if showOnlineStatus {
                    HStack(spacing: 4) {
                        if participant.isOnline {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)

                            Text("Online")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Text(formattedLastSeen(participant.lastSeen))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Chevron icon for navigation
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: - Helper Methods

    private func formattedLastSeen(_ date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: now)

        if let days = components.day, days > 0 {
            if days == 1 {
                return "Last seen yesterday"
            } else if days < 7 {
                return "Last seen \(days) days ago"
            } else {
                return "Last seen a while ago"
            }
        } else if let hours = components.hour, hours > 0 {
            if hours == 1 {
                return "Last seen 1 hour ago"
            } else {
                return "Last seen \(hours) hours ago"
            }
        } else if let minutes = components.minute, minutes > 0 {
            if minutes == 1 {
                return "Last seen 1 minute ago"
            } else {
                return "Last seen \(minutes) minutes ago"
            }
        } else {
            return "Last seen just now"
        }
    }
}

#Preview {
    List {
        ParticipantRowView(
            participant: UserProfile(
                id: "1",
                displayName: "Alice Johnson",
                email: "alice@example.com",
                photoURL: nil,
                isOnline: true,
                lastSeen: Date()
            ),
            showOnlineStatus: true,
            isCurrentUser: false
        )

        ParticipantRowView(
            participant: UserProfile(
                id: "2",
                displayName: "Bob Smith",
                email: "bob@example.com",
                photoURL: nil,
                isOnline: false,
                lastSeen: Date().addingTimeInterval(-3600)
            ),
            showOnlineStatus: true,
            isCurrentUser: false
        )

        ParticipantRowView(
            participant: UserProfile(
                id: "3",
                displayName: "Charlie Brown",
                email: "charlie@example.com",
                photoURL: nil,
                isOnline: false,
                lastSeen: Date()
            ),
            showOnlineStatus: true,
            isCurrentUser: true
        )
    }
}
