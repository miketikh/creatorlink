//
//  FirestoreService.swift
//  CreatorLink
//
//  Service layer for common Firestore operations
//

import Foundation
import FirebaseFirestore

@Observable
class FirestoreService {
    static let shared = FirestoreService()

    let db = Firestore.firestore()

    private init() {
        // Firestore settings are configured in AppDelegate
        // Do not override settings here to ensure emulator configuration works
    }

    // Collection references for easy access
    var usersCollection: CollectionReference {
        db.collection("users")
    }

    var conversationsCollection: CollectionReference {
        db.collection("conversations")
    }

    var messagesCollection: CollectionReference {
        db.collection("messages")
    }
}
