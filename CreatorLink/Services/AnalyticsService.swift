//
//  AnalyticsService.swift
//  CreatorLink
//
//  Service for tracking analytics events for group messaging features
//

import Foundation
import FirebaseAnalytics

/// Service for tracking user interactions and events throughout the app
/// Specifically enhanced for group messaging analytics
class AnalyticsService {
    static let shared = AnalyticsService()

    private init() {}

    // MARK: - Group Analytics Events

    /// Tracks when a user creates a new group
    /// - Parameters:
    ///   - groupSize: Number of participants in the group
    ///   - hasCustomImage: Whether a custom image was set
    ///   - hasCustomName: Whether a custom name was set
    func trackGroupCreated(groupSize: Int, hasCustomImage: Bool, hasCustomName: Bool) {
        Analytics.logEvent("group_created", parameters: [
            "group_size": groupSize,
            "has_custom_image": hasCustomImage,
            "has_custom_name": hasCustomName
        ])
    }

    /// Tracks when a user is added to a group
    /// - Parameter groupSize: Number of participants in the group after addition
    func trackGroupJoined(groupSize: Int) {
        Analytics.logEvent("group_joined", parameters: [
            "group_size": groupSize
        ])
    }

    /// Tracks when a user leaves a group
    /// - Parameter groupSize: Number of participants remaining in the group
    func trackGroupLeft(groupSize: Int) {
        Analytics.logEvent("group_left", parameters: [
            "group_size": groupSize
        ])
    }

    /// Tracks when a participant is added to a group
    /// - Parameter groupSize: Number of participants in the group after addition
    func trackParticipantAdded(groupSize: Int) {
        Analytics.logEvent("participant_added", parameters: [
            "group_size": groupSize
        ])
    }

    /// Tracks when a participant is removed from a group
    /// - Parameter groupSize: Number of participants in the group after removal
    func trackParticipantRemoved(groupSize: Int) {
        Analytics.logEvent("participant_removed", parameters: [
            "group_size": groupSize
        ])
    }

    /// Tracks when a message is sent in a group
    /// - Parameter groupSize: Number of participants in the group
    func trackGroupMessageSent(groupSize: Int) {
        Analytics.logEvent("group_message_sent", parameters: [
            "group_size": groupSize
        ])
    }

    /// Tracks when a user views group info screen
    /// - Parameter groupSize: Number of participants in the group
    func trackGroupInfoViewed(groupSize: Int) {
        Analytics.logEvent("group_info_viewed", parameters: [
            "group_size": groupSize
        ])
    }

    /// Tracks when a user updates the group name
    func trackGroupNameUpdated() {
        Analytics.logEvent("group_name_updated", parameters: nil)
    }

    /// Tracks when a user updates the group image
    func trackGroupImageUpdated() {
        Analytics.logEvent("group_image_updated", parameters: nil)
    }

    /// Tracks when a user mutes group notifications
    /// - Parameter isMuted: Whether the group was muted or unmuted
    func trackGroupNotificationsMuted(isMuted: Bool) {
        Analytics.logEvent("group_notifications_muted", parameters: [
            "is_muted": isMuted
        ])
    }

    /// Tracks when a user views read receipt details
    /// - Parameter groupSize: Number of participants in the group
    func trackReadDetailsViewed(groupSize: Int) {
        Analytics.logEvent("read_details_viewed", parameters: [
            "group_size": groupSize
        ])
    }

    // MARK: - Error Tracking

    /// Tracks when an error occurs during group operations
    /// - Parameters:
    ///   - operation: The operation that failed (e.g., "create_group", "add_participant")
    ///   - errorDescription: Description of the error
    func trackGroupError(operation: String, errorDescription: String) {
        Analytics.logEvent("group_error", parameters: [
            "operation": operation,
            "error_description": errorDescription
        ])
    }

    // MARK: - General Analytics Events

    /// Tracks a custom event with optional parameters
    /// - Parameters:
    ///   - eventName: Name of the event
    ///   - parameters: Optional parameters dictionary
    func trackEvent(_ eventName: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(eventName, parameters: parameters)
    }

    /// Sets a user property for analytics
    /// - Parameters:
    ///   - value: The property value
    ///   - name: The property name
    func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    /// Tracks when a screen is viewed
    /// - Parameters:
    ///   - screenName: Name of the screen
    ///   - screenClass: Optional screen class
    func trackScreenView(screenName: String, screenClass: String? = nil) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass ?? screenName
        ])
    }
}

// MARK: - Analytics Event Names

extension AnalyticsService {
    // Group messaging events
    static let groupCreatedEvent = "group_created"
    static let groupJoinedEvent = "group_joined"
    static let groupLeftEvent = "group_left"
    static let participantAddedEvent = "participant_added"
    static let participantRemovedEvent = "participant_removed"
    static let groupMessageSentEvent = "group_message_sent"
    static let groupInfoViewedEvent = "group_info_viewed"
    static let groupNameUpdatedEvent = "group_name_updated"
    static let groupImageUpdatedEvent = "group_image_updated"
    static let groupNotificationsMutedEvent = "group_notifications_muted"
    static let readDetailsViewedEvent = "read_details_viewed"
    static let groupErrorEvent = "group_error"
}
