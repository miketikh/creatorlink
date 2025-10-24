//
//  AITagIndicatorView.swift
//  CreatorLink
//
//  Small info popover explaining AI vs manual tags
//

import SwiftUI

struct AITagIndicatorView: View {
    @State private var showInfo = false

    var body: some View {
        Button {
            showInfo = true
        } label: {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .buttonStyle(.borderless)
        .alert("About Tag Sources", isPresented: $showInfo) {
            Button("OK") { }
        } message: {
            Text("AI automatically tags conversations based on message content. You can override tags at any time, and your changes will be preserved.")
        }
    }
}

#Preview {
    AITagIndicatorView()
}
