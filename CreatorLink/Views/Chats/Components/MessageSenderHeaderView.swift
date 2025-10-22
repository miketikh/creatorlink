//
//  MessageSenderHeaderView.swift
//  CreatorLink
//
//  Component showing sender name above message bubbles in group chats
//

import SwiftUI

struct MessageSenderHeaderView: View {
    let senderName: String
    let alignment: Alignment

    var body: some View {
        HStack {
            if alignment == .trailing {
                Spacer()
            }

            Text(senderName)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)

            if alignment == .leading {
                Spacer()
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        MessageSenderHeaderView(senderName: "Alice", alignment: .leading)
        MessageSenderHeaderView(senderName: "Bob Johnson", alignment: .leading)
        MessageSenderHeaderView(senderName: "Christopher Anderson", alignment: .leading)
    }
    .padding()
}
