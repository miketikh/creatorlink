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

    init(emoji: String, backgroundColor: Color = .clear) {
        self.emoji = emoji
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        Text(emoji)
            .font(.system(size: 14))
            .frame(width: 24, height: 24)
            .background(backgroundColor)
            .clipShape(Circle())
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
