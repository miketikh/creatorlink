//
//  DraftService.swift
//  CreatorLink
//
//  Service layer for AI draft message management
//  Handles reading, listening to, and managing drafts from Firestore
//

import Foundation
import FirebaseFirestore

@Observable
class DraftService {
    static let shared = DraftService()

    private let db = FirestoreService.shared.db

    private init() {}

    // MARK: - Fetch Draft

    /// Fetches a draft for a specific conversation and user
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the user (who the draft is for)
    /// - Returns: MessageDraft if found, nil otherwise
    func fetchDraft(conversationId: String, userId: String) async throws -> MessageDraft? {
        do {
            let draftDoc = try await db.collection("conversations")
                .document(conversationId)
                .collection("drafts")
                .document(userId)
                .getDocument()

            guard draftDoc.exists else {
                print("📝 No draft found for conversation \(conversationId), user \(userId)")
                return nil
            }

            let draft = try draftDoc.data(as: MessageDraft.self)
            print("✅ Draft fetched successfully for conversation \(conversationId)")
            return draft
        } catch {
            print("❌ Failed to fetch draft: \(error.localizedDescription)")
            throw DraftError.fetchFailed(error)
        }
    }

    // MARK: - Real-time Listener

    /// Sets up a real-time listener for a draft
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the user (who the draft is for)
    ///   - onUpdate: Closure called when draft changes (nil if deleted)
    /// - Returns: ListenerRegistration for cleanup
    func listenToDraft(conversationId: String, userId: String, onUpdate: @escaping (MessageDraft?) -> Void) -> ListenerRegistration {
        let draftRef = db.collection("conversations")
            .document(conversationId)
            .collection("drafts")
            .document(userId)

        return draftRef.addSnapshotListener { snapshot, error in
            if let error = error {
                print("❌ Draft listener error: \(error.localizedDescription)")
                onUpdate(nil)
                return
            }

            guard let snapshot = snapshot else {
                print("❌ Draft snapshot is nil")
                onUpdate(nil)
                return
            }

            if snapshot.exists {
                do {
                    let draft = try snapshot.data(as: MessageDraft.self)
                    print("📝 Draft updated for conversation \(conversationId)")
                    onUpdate(draft)
                } catch {
                    print("❌ Failed to decode draft: \(error.localizedDescription)")
                    onUpdate(nil)
                }
            } else {
                print("📝 Draft deleted for conversation \(conversationId)")
                onUpdate(nil)
            }
        }
    }

    // MARK: - Mark Draft Touched

    /// Marks a draft as touched by the user (prevents auto-updates from Cloud Functions)
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the user
    func markDraftTouched(conversationId: String, userId: String) async throws {
        do {
            try await db.collection("conversations")
                .document(conversationId)
                .collection("drafts")
                .document(userId)
                .updateData([
                    "userTouched": true
                ])
            print("✅ Draft marked as touched for conversation \(conversationId)")
        } catch {
            print("❌ Failed to mark draft as touched: \(error.localizedDescription)")
            throw DraftError.updateFailed(error)
        }
    }

    // MARK: - Delete Draft

    /// Deletes a draft from Firestore
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the user
    func deleteDraft(conversationId: String, userId: String) async throws {
        do {
            try await db.collection("conversations")
                .document(conversationId)
                .collection("drafts")
                .document(userId)
                .delete()
            print("✅ Draft deleted for conversation \(conversationId)")
        } catch {
            print("❌ Failed to delete draft: \(error.localizedDescription)")
            throw DraftError.deleteFailed(error)
        }
    }
}

// MARK: - Error Types

enum DraftError: LocalizedError {
    case fetchFailed(Error)
    case updateFailed(Error)
    case deleteFailed(Error)

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let error):
            return "Failed to fetch draft: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Failed to update draft: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete draft: \(error.localizedDescription)"
        }
    }
}
