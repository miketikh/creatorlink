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
        chipButton
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(accessibilityHint)
            .accessibilityValue(accessibilityValue ?? "")
    }

    private var chipButton: some View {
        Button(action: onTap) {
            chipContent
        }
        .buttonStyle(.plain)
    }

    private var chipContent: some View {
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
        .overlay(countBadge, alignment: .topTrailing)
    }

    @ViewBuilder
    private var countBadge: some View {
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
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        if emoji != nil {
            return "Filter by \(label)"
        } else {
            return label
        }
    }

    private var accessibilityHint: String {
        if emoji != nil {
            return "Shows only \(label.lowercased()) conversations"
        } else {
            return "Shows all conversations"
        }
    }

    private var accessibilityValue: String? {
        if let count = count, count > 0 {
            return "\(count) conversations"
        }
        return nil
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
