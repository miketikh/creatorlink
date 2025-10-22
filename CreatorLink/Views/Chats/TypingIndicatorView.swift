//
//  TypingIndicatorView.swift
//  CreatorLink
//
//  Displays typing indicator when users are typing
//

import SwiftUI

struct TypingIndicatorView: View {
    let typingUserNames: [String]
    let typingUserAvatars: [String]?
    let isGroupChat: Bool
    let formattedText: String?

    @State private var animationPhase = 0
    @State private var animationTimer: Timer?

    // Convenience initializer for backward compatibility
    init(typingUserNames: [String]) {
        self.typingUserNames = typingUserNames
        self.typingUserAvatars = nil
        self.isGroupChat = false
        self.formattedText = nil
    }

    // Full initializer with enhanced parameters
    init(
        typingUserNames: [String],
        typingUserAvatars: [String]? = nil,
        isGroupChat: Bool = false,
        formattedText: String? = nil
    ) {
        self.typingUserNames = typingUserNames
        self.typingUserAvatars = typingUserAvatars
        self.isGroupChat = isGroupChat
        self.formattedText = formattedText
    }

    var body: some View {
        if !typingUserNames.isEmpty {
            HStack(spacing: 8) {
                // Show avatars for group chats if available
                if isGroupChat, let avatars = typingUserAvatars, !avatars.isEmpty {
                    avatarsView(avatars: avatars)
                }

                // Typing text
                Text(displayText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()

                // Animated dots
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 4, height: 4)
                            .opacity(animationPhase == index ? 1.0 : 0.3)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Color(.systemBackground)
                    .opacity(0.95)
                    .blur(radius: 0.5)
            )
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .onAppear {
                startAnimation()
            }
            .onDisappear {
                stopAnimation()
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func avatarsView(avatars: [String]) -> some View {
        HStack(spacing: -8) {
            ForEach(Array(avatars.prefix(3).enumerated()), id: \.offset) { index, avatarUrl in
                if let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 22, height: 22)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 1.5)
                    )
                    .zIndex(Double(avatars.count - index))
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var displayText: String {
        // Use formatted text if provided, otherwise fall back to default formatting
        if let formatted = formattedText, !formatted.isEmpty {
            return formatted
        }

        // Default formatting for backward compatibility
        switch typingUserNames.count {
        case 0:
            return ""
        case 1:
            return "\(typingUserNames[0]) is typing"
        case 2:
            return "\(typingUserNames[0]) and \(typingUserNames[1]) are typing"
        default:
            let othersCount = typingUserNames.count - 2
            return "\(typingUserNames[0]), \(typingUserNames[1]), and \(othersCount) \(othersCount == 1 ? "other" : "others") are typing"
        }
    }

    // MARK: - Animation

    private func startAnimation() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        animationPhase = 0
    }
}

#Preview {
    VStack {
        TypingIndicatorView(typingUserNames: ["John"])
        TypingIndicatorView(typingUserNames: ["John", "Jane"])
        TypingIndicatorView(typingUserNames: ["John", "Jane", "Bob"])
        TypingIndicatorView(typingUserNames: ["John", "Jane", "Bob", "Alice"])
    }
}
