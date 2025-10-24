//
//  FAQReferenceLinkView.swift
//  CreatorLink
//
//  Reusable component for displaying FAQ reference links in AI messages
//

import SwiftUI
import UIKit

struct FAQReferenceLinkView: View {
    let faqReferenceId: String
    let matchedQuestion: String?
    let matchConfidence: String?
    let suggestedAnswer: String?
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            // Haptic feedback
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 6) {
                // Main link content
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.forward.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)

                    Text("✨ AI Suggested Answer")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    // Hide confidence badge - for internal use only
                    // if let confidence = matchConfidence,
                    //    let confidenceValue = Double(confidence) {
                    //     let percentage = Int(confidenceValue * 100)
                    //     Text("\(percentage)% match")
                    //         .font(.caption2)
                    //         .fontWeight(.semibold)
                    //         .foregroundColor(.white)
                    //         .padding(.horizontal, 8)
                    //         .padding(.vertical, 4)
                    //         .background(Color.green.opacity(0.8))
                    //         .cornerRadius(8)
                    // }
                }

                // Show AI's suggested answer text instead of matched question
                if let answer = suggestedAnswer {
                    Text(answer)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.75, green: 0.6, blue: 0.9, opacity: 0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(red: 0.75, green: 0.6, blue: 0.9, opacity: 0.4), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .accessibilityLabel("AI suggested answer to similar question")
        .accessibilityHint("Double tap to jump to the previous answer")
    }
}

#Preview {
    VStack(spacing: 20) {
        // With confidence and suggested answer
        FAQReferenceLinkView(
            faqReferenceId: "msg123",
            matchedQuestion: "What are your hourly rates for freelance work?",
            matchConfidence: "0.92",
            suggestedAnswer: "My rates are $500/hour for consulting work.",
            onTap: {
                print("Tapped FAQ reference: msg123")
            }
        )
        .padding()

        // Without confidence, with suggested answer
        FAQReferenceLinkView(
            faqReferenceId: "msg456",
            matchedQuestion: "Do you offer package deals for long-term projects?",
            matchConfidence: nil,
            suggestedAnswer: "Yes, I offer discounted package deals for long-term projects. Contact me to discuss your needs.",
            onTap: {
                print("Tapped FAQ reference: msg456")
            }
        )
        .padding()

        // Without suggested answer
        FAQReferenceLinkView(
            faqReferenceId: "msg789",
            matchedQuestion: nil,
            matchConfidence: "0.85",
            suggestedAnswer: nil,
            onTap: {
                print("Tapped FAQ reference: msg789")
            }
        )
        .padding()

        // Minimal
        FAQReferenceLinkView(
            faqReferenceId: "msg000",
            matchedQuestion: nil,
            matchConfidence: nil,
            suggestedAnswer: nil,
            onTap: {
                print("Tapped FAQ reference: msg000")
            }
        )
        .padding()
    }
}
