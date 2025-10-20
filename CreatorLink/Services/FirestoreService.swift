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
        // Configure Firestore settings if needed
        let settings = FirestoreSettings()
        db.settings = settings
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
