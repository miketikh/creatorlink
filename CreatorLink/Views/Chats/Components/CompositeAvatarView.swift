//
//  CompositeAvatarView.swift
//  CreatorLink
//
//  2x2 grid layout showing 2-4 participant profile photos
//  Used for group avatars when no custom image is set
//

import SwiftUI

struct CompositeAvatarView: View {
    let photoUrls: [String]
    let size: CGFloat

    // Calculate size for each individual photo cell
    private var cellSize: CGFloat {
        size / 2
    }

    var body: some View {
        ZStack {
            // Background circle for border
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: size, height: size)

            // Grid layout based on number of photos
            if photoUrls.count == 2 {
                twoPhotoLayout
            } else if photoUrls.count == 3 {
                threePhotoLayout
            } else if photoUrls.count >= 4 {
                fourPhotoLayout
            } else {
                // Fallback for 0 or 1 photo
                singlePhotoLayout
            }
        }
        .clipShape(Circle())
    }

    // MARK: - Layout Views

    private var singlePhotoLayout: some View {
        photoView(url: photoUrls.first, index: 0)
            .frame(width: size, height: size)
    }

    private var twoPhotoLayout: some View {
        VStack(spacing: 0) {
            photoView(url: photoUrls[0], index: 0)
                .frame(width: size, height: cellSize)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: size / 2,
                    topTrailingRadius: size / 2
                ))

            photoView(url: photoUrls[1], index: 1)
                .frame(width: size, height: cellSize)
                .clipShape(UnevenRoundedRectangle(
                    bottomLeadingRadius: size / 2,
                    bottomTrailingRadius: size / 2
                ))
        }
    }

    private var threePhotoLayout: some View {
        VStack(spacing: 0) {
            // Top row with 2 photos
            HStack(spacing: 0) {
                photoView(url: photoUrls[0], index: 0)
                    .frame(width: cellSize, height: cellSize)
                    .clipShape(UnevenRoundedRectangle(
                        topLeadingRadius: size / 2
                    ))

                photoView(url: photoUrls[1], index: 1)
                    .frame(width: cellSize, height: cellSize)
                    .clipShape(UnevenRoundedRectangle(
                        topTrailingRadius: size / 2
                    ))
            }

            // Bottom row with 1 centered photo
            photoView(url: photoUrls[2], index: 2)
                .frame(width: size, height: cellSize)
                .clipShape(UnevenRoundedRectangle(
                    bottomLeadingRadius: size / 2,
                    bottomTrailingRadius: size / 2
                ))
        }
    }

    private var fourPhotoLayout: some View {
        VStack(spacing: 0) {
            // Top row
            HStack(spacing: 0) {
                photoView(url: photoUrls[0], index: 0)
                    .frame(width: cellSize, height: cellSize)
                    .clipShape(UnevenRoundedRectangle(
                        topLeadingRadius: size / 2
                    ))

                photoView(url: photoUrls[1], index: 1)
                    .frame(width: cellSize, height: cellSize)
                    .clipShape(UnevenRoundedRectangle(
                        topTrailingRadius: size / 2
                    ))
            }

            // Bottom row
            HStack(spacing: 0) {
                photoView(url: photoUrls[2], index: 2)
                    .frame(width: cellSize, height: cellSize)
                    .clipShape(UnevenRoundedRectangle(
                        bottomLeadingRadius: size / 2
                    ))

                photoView(url: photoUrls[3], index: 3)
                    .frame(width: cellSize, height: cellSize)
                    .clipShape(UnevenRoundedRectangle(
                        bottomTrailingRadius: size / 2
                    ))
            }
        }
    }

    // MARK: - Photo View

    private func photoView(url: String?, index: Int) -> some View {
        Group {
            if let url = url, let imageUrl = URL(string: url) {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .empty:
                        Color.gray.opacity(0.3)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholderView(index: index)
                    @unknown default:
                        placeholderView(index: index)
                    }
                }
            } else {
                placeholderView(index: index)
            }
        }
    }

    private func placeholderView(index: Int) -> some View {
        ZStack {
            Color.blue.opacity(0.3)

            Image(systemName: "person.fill")
                .font(.system(size: cellSize * 0.4))
                .foregroundColor(.blue)
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        Text("2 Photos")
        CompositeAvatarView(
            photoUrls: [
                "https://ui-avatars.com/api/?name=A&background=ff6b6b",
                "https://ui-avatars.com/api/?name=B&background=4ecdc4"
            ],
            size: 100
        )

        Text("3 Photos")
        CompositeAvatarView(
            photoUrls: [
                "https://ui-avatars.com/api/?name=A&background=ff6b6b",
                "https://ui-avatars.com/api/?name=B&background=4ecdc4",
                "https://ui-avatars.com/api/?name=C&background=ffe66d"
            ],
            size: 100
        )

        Text("4 Photos")
        CompositeAvatarView(
            photoUrls: [
                "https://ui-avatars.com/api/?name=A&background=ff6b6b",
                "https://ui-avatars.com/api/?name=B&background=4ecdc4",
                "https://ui-avatars.com/api/?name=C&background=ffe66d",
                "https://ui-avatars.com/api/?name=D&background=a8e6cf"
            ],
            size: 100
        )
    }
    .padding()
}
