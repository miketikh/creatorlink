//
//  ChatsView.swift
//  CreatorLink
//
//  Main view for displaying conversation list
//

import SwiftUI

struct ChatsView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Chats")
                    .font(.largeTitle)
                    .padding()

                Text("Your conversations will appear here")
                    .foregroundColor(.secondary)

                Spacer()
            }
            .navigationTitle("Chats")
        }
    }
}

#Preview {
    ChatsView()
}
