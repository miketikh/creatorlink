//
//  FilterChipView.swift
//  CreatorLink
//
//  Small tappable chip for filter selection with emoji and optional count badge
//

import SwiftUI

struct FilterChipView: View {
    let emoji: String?
    let label: String
    let count: Int?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if let emoji = emoji {
                    Text(emoji)
                        .font(.system(size: 16))
                }
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
            .overlay(
                // Count badge overlay (top-right corner)
                Group {
                    if let count = count, count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(4)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 8, y: -8)
                    }
                },
                alignment: .topTrailing
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        // Unselected chips
        HStack(spacing: 8) {
            FilterChipView(emoji: nil, label: "All", count: nil, isSelected: false, onTap: {})
            FilterChipView(emoji: "💼", label: "Business", count: nil, isSelected: false, onTap: {})
            FilterChipView(emoji: "🔥", label: "Urgent", count: 3, isSelected: false, onTap: {})
        }

        // Selected chips
        HStack(spacing: 8) {
            FilterChipView(emoji: nil, label: "All", count: nil, isSelected: true, onTap: {})
            FilterChipView(emoji: "💼", label: "Business", count: nil, isSelected: true, onTap: {})
            FilterChipView(emoji: "🔥", label: "Urgent", count: 3, isSelected: true, onTap: {})
        }
    }
    .padding()
}
