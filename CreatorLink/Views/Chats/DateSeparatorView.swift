//
//  DateSeparatorView.swift
//  CreatorLink
//
//  Date separator component for grouping messages by day
//

import SwiftUI

struct DateSeparatorView: View {
    let date: Date

    var body: some View {
        HStack {
            Spacer()
            Text(formattedDate)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray5))
                .cornerRadius(12)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var formattedDate: String {
        let calendar = Calendar.current
        let now = Date()

        // Check if it's today
        if calendar.isDateInToday(date) {
            return "Today"
        }

        // Check if it's yesterday
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        // Check if it's within the last week
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
           date > weekAgo {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Day name (e.g., "Saturday")
            return formatter.string(from: date)
        }

        // Older than a week - show formatted date
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    VStack(spacing: 20) {
        DateSeparatorView(date: Date())
        DateSeparatorView(date: Date().addingTimeInterval(-86400)) // Yesterday
        DateSeparatorView(date: Date().addingTimeInterval(-86400 * 3)) // 3 days ago
        DateSeparatorView(date: Date().addingTimeInterval(-86400 * 10)) // 10 days ago
    }
    .padding()
}
