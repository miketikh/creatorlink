//
//  FilterPreferencesService.swift
//  CreatorLink
//
//  Service for managing conversation filter preferences with UserDefaults
//

import Foundation

class FilterPreferencesService {
    static let shared = FilterPreferencesService()

    private let userDefaults = UserDefaults.standard

    // UserDefaults keys
    private let categoryFiltersKey = "conversation.categoryFilters"
    private let statusFiltersKey = "conversation.statusFilters"
    private let showResolvedKey = "conversation.showResolved"

    private init() {}

    // MARK: - Save Filters

    /// Saves the current filter selections to UserDefaults
    func saveFilters(categoryFilters: [String], statusFilters: [String], showResolved: Bool) {
        userDefaults.set(categoryFilters, forKey: categoryFiltersKey)
        userDefaults.set(statusFilters, forKey: statusFiltersKey)
        userDefaults.set(showResolved, forKey: showResolvedKey)
    }

    // MARK: - Load Filters

    /// Loads previously saved filter selections from UserDefaults
    func loadFilters() -> (categoryFilters: [String], statusFilters: [String], showResolved: Bool) {
        let categoryFilters = userDefaults.stringArray(forKey: categoryFiltersKey) ?? []
        let statusFilters = userDefaults.stringArray(forKey: statusFiltersKey) ?? []
        let showResolved = userDefaults.object(forKey: showResolvedKey) as? Bool ?? true

        return (categoryFilters: categoryFilters, statusFilters: statusFilters, showResolved: showResolved)
    }

    // MARK: - Clear Filters

    /// Clears all saved filter preferences
    func clearFilters() {
        userDefaults.removeObject(forKey: categoryFiltersKey)
        userDefaults.removeObject(forKey: statusFiltersKey)
        userDefaults.removeObject(forKey: showResolvedKey)
    }
}
