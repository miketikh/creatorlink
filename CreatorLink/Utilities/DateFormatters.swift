//
//  DateFormatters.swift
//  CreatorLink
//
//  Reusable date formatting utilities
//

import Foundation

enum DateFormatters {
    /// Formats a timestamp for display in message lists
    /// - Today: "2:30 PM"
    /// - Yesterday: "Yesterday"
    /// - This week: "Monday"
    /// - Older: "3/15/25"
    static func formatMessageTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        // Check if it's today
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
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

        // Older than a week - show date
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    /// Formats a "last online" timestamp with "Last online" prefix
    /// - Today: "Last online 2:30 PM"
    /// - Yesterday: "Last online Yesterday"
    /// - This week: "Last online Monday"
    /// - Older: "Last online 3/15/25"
    static func formatLastOnline(_ date: Date) -> String {
        return "Last online \(formatMessageTimestamp(date))"
    }
}
