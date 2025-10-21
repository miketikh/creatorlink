//
//  TypingIndicatorView.swift
//  CreatorLink
//
//  Displays typing indicator when users are typing
//

import SwiftUI

struct TypingIndicatorView: View {
    let typingUserNames: [String]

    @State private var animationPhase = 0

    var body: some View {
        if !typingUserNames.isEmpty {
            HStack(spacing: 8) {
                // Typing text
                Text(typingText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()

                // Animated dots
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 4, height: 4)
                            .opacity(animationPhase == index ? 1.0 : 0.3)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .onAppear {
                startAnimation()
            }
            .onDisappear {
                stopAnimation()
            }
        }
    }

    // MARK: - Computed Properties

    private var typingText: String {
        switch typingUserNames.count {
        case 0:
            return ""
        case 1:
            return "\(typingUserNames[0]) is typing"
        case 2:
            return "\(typingUserNames[0]) and \(typingUserNames[1]) are typing"
        case 3:
            return "\(typingUserNames[0]), \(typingUserNames[1]), and \(typingUserNames[2]) are typing"
        default:
            return "\(typingUserNames[0]), \(typingUserNames[1]), and \(typingUserNames.count - 2) others are typing"
        }
    }

    // MARK: - Animation

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            withAnimation(.easeInOut(duration: 0.3)) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }

    private func stopAnimation() {
        animationPhase = 0
    }
}

#Preview {
    VStack {
        TypingIndicatorView(typingUserNames: ["John"])
        TypingIndicatorView(typingUserNames: ["John", "Jane"])
        TypingIndicatorView(typingUserNames: ["John", "Jane", "Bob"])
        TypingIndicatorView(typingUserNames: ["John", "Jane", "Bob", "Alice"])
    }
}
