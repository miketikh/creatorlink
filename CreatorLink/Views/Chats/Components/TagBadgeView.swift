//
//  TagBadgeView.swift
//  CreatorLink
//
//  Reusable badge component for displaying single emoji tag indicators
//

import SwiftUI

struct TagBadgeView: View {
    let emoji: String
    let backgroundColor: Color
    let accessibilityLabel: String?
    var size: CGFloat = 24

    init(emoji: String, backgroundColor: Color = .clear, accessibilityLabel: String? = nil, size: CGFloat = 24) {
        self.emoji = emoji
        self.backgroundColor = backgroundColor
        self.accessibilityLabel = accessibilityLabel
        self.size = size
    }

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.6))
            .frame(width: size, height: size)
            .background(backgroundColor)
            .clipShape(Circle())
            .accessibilityLabel(accessibilityLabel ?? emoji)
    }
}

#Preview {
    VStack(spacing: 12) {
        // Regular badges
        HStack(spacing: 8) {
            TagBadgeView(emoji: "💼")
            TagBadgeView(emoji: "🤝")
            TagBadgeView(emoji: "💬")
            TagBadgeView(emoji: "⭐")
        }

        // Status badges
        HStack(spacing: 8) {
            TagBadgeView(emoji: "🔥", backgroundColor: Color.red.opacity(0.1))
            TagBadgeView(emoji: "❓")
            TagBadgeView(emoji: "⏰")
            TagBadgeView(emoji: "✅")
        }
    }
    .padding()
}
