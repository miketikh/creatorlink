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
        VStack(spacing: 0) {
            // Categories row
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
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            // Statuses row (smaller) - with extra top padding to prevent clipping
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    FilterChipView(
                        emoji: StatusTag.urgent.emoji,
                        label: StatusTag.urgent.displayName,
                        count: viewModel.urgentCount,
                        isSelected: viewModel.selectedStatusFilters.contains(.urgent),
                        onTap: {
                            viewModel.toggleStatusFilter(.urgent)
                        },
                        isCompact: true
                    )

                    FilterChipView(
                        emoji: StatusTag.needsResponse.emoji,
                        label: StatusTag.needsResponse.displayName,
                        count: viewModel.needsResponseCount,
                        isSelected: viewModel.selectedStatusFilters.contains(.needsResponse),
                        onTap: {
                            viewModel.toggleStatusFilter(.needsResponse)
                        },
                        isCompact: true
                    )

                    FilterChipView(
                        emoji: StatusTag.awaitingReply.emoji,
                        label: StatusTag.awaitingReply.displayName,
                        count: viewModel.awaitingReplyCount,
                        isSelected: viewModel.selectedStatusFilters.contains(.awaitingReply),
                        onTap: {
                            viewModel.toggleStatusFilter(.awaitingReply)
                        },
                        isCompact: true
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
        }
    }
}

#Preview {
    FilterBarView(viewModel: ConversationsViewModel())
        .padding()
}
