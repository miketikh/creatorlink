//
//  FilterBarView.swift
//  CreatorLink
//
//  Horizontal scrollable filter bar with category and status chips
//

import SwiftUI

struct FilterBarView: View {
    @Bindable var viewModel: ConversationsViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" filter - clears all filters
                FilterChipView(
                    emoji: nil,
                    label: "All",
                    count: nil,
                    isSelected: viewModel.selectedCategoryFilters.isEmpty && viewModel.selectedStatusFilters.isEmpty,
                    onTap: {
                        viewModel.clearAllFilters()
                    }
                )

                // Category filters
                ForEach([ConversationTag.business, .collaboration, .social, .fan], id: \.self) { tag in
                    FilterChipView(
                        emoji: tag.emoji,
                        label: tag.displayName,
                        count: nil,
                        isSelected: viewModel.selectedCategoryFilters.contains(tag),
                        onTap: {
                            viewModel.toggleCategoryFilter(tag)
                        }
                    )
                }

                // Divider
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 30)
                    .padding(.horizontal, 4)

                // Status filters
                FilterChipView(
                    emoji: StatusTag.urgent.emoji,
                    label: StatusTag.urgent.displayName,
                    count: viewModel.urgentCount,
                    isSelected: viewModel.selectedStatusFilters.contains(.urgent),
                    onTap: {
                        viewModel.toggleStatusFilter(.urgent)
                    }
                )

                FilterChipView(
                    emoji: StatusTag.needsResponse.emoji,
                    label: StatusTag.needsResponse.displayName,
                    count: viewModel.needsResponseCount,
                    isSelected: viewModel.selectedStatusFilters.contains(.needsResponse),
                    onTap: {
                        viewModel.toggleStatusFilter(.needsResponse)
                    }
                )

                FilterChipView(
                    emoji: StatusTag.awaitingReply.emoji,
                    label: StatusTag.awaitingReply.displayName,
                    count: nil,
                    isSelected: viewModel.selectedStatusFilters.contains(.awaitingReply),
                    onTap: {
                        viewModel.toggleStatusFilter(.awaitingReply)
                    }
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(height: 60)
    }
}

#Preview {
    FilterBarView(viewModel: ConversationsViewModel())
        .padding()
}
