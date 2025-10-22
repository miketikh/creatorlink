//
//  GroupAvatarView.swift
//  CreatorLink
//
//  Reusable component for displaying group avatars with priority logic:
//  1. Custom groupImageUrl (if provided)
//  2. Composite avatar for 3-4 participants (grid of profile photos)
//  3. Placeholder for 5+ participants (UI Avatars API)
//

import SwiftUI

struct GroupAvatarView: View {
    let groupImageUrl: String?
    let participantIds: [String]
    let size: CGFloat

    @State private var participantPhotos: [String] = []
    @State private var groupName: String?

    var body: some View {
        Group {
            if let groupImageUrl = groupImageUrl, !groupImageUrl.isEmpty {
                // Priority 1: Custom group image
                customImageView(url: groupImageUrl)
            } else if participantIds.count >= 3 && participantIds.count <= 4 && !participantPhotos.isEmpty {
                // Priority 2: Composite avatar for 3-4 participants
                CompositeAvatarView(photoUrls: participantPhotos, size: size)
            } else {
                // Priority 3: Placeholder
                placeholderView
            }
        }
        .task {
            await fetchParticipantPhotos()
        }
    }

    // MARK: - Subviews

    private func customImageView(url: String) -> some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: size, height: size)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            case .failure:
                // Fallback to composite or placeholder if custom image fails
                Group {
                    if participantIds.count >= 3 && participantIds.count <= 4 && !participantPhotos.isEmpty {
                        CompositeAvatarView(photoUrls: participantPhotos, size: size)
                    } else {
                        placeholderView
                    }
                }
            @unknown default:
                placeholderView
            }
        }
    }

    private var placeholderView: some View {
        let letter = groupName?.prefix(1).uppercased() ?? "G"
        let placeholderUrl = "https://ui-avatars.com/api/?name=\(letter)&background=random&size=\(Int(size * 2))"

        return AsyncImage(url: URL(string: placeholderUrl)) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: size, height: size)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            case .failure:
                // Final fallback: simple circle with letter
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: size, height: size)

                    Text(letter)
                        .font(.system(size: size * 0.4))
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            @unknown default:
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: size, height: size)

                    Text(letter)
                        .font(.system(size: size * 0.4))
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
        }
    }

    // MARK: - Methods

    private func fetchParticipantPhotos() async {
        // Fetch up to 4 participant profiles
        let idsToFetch = Array(participantIds.prefix(4))

        var photos: [String] = []
        for userId in idsToFetch {
            if let profile = try? await UserService.shared.fetchUser(userId: userId) {
                if let photoURL = profile.photoURL, !photoURL.isEmpty {
                    photos.append(photoURL)
                }
            }
        }

        // Update state on main thread
        await MainActor.run {
            self.participantPhotos = photos
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Test custom image URL
        GroupAvatarView(
            groupImageUrl: "https://ui-avatars.com/api/?name=Team&background=random",
            participantIds: ["user1", "user2", "user3"],
            size: 50
        )

        // Test composite (will show placeholder until photos load)
        GroupAvatarView(
            groupImageUrl: nil,
            participantIds: ["user1", "user2", "user3"],
            size: 50
        )

        // Test placeholder for 5+ members
        GroupAvatarView(
            groupImageUrl: nil,
            participantIds: ["user1", "user2", "user3", "user4", "user5"],
            size: 50
        )
    }
    .padding()
}
