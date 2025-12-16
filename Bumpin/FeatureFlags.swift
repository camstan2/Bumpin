//
//  FeatureFlags.swift
//  Bumpin
//
//  Feature flags to control visibility of features during development
//  Toggle these flags to show/hide features without deleting code
//

import Foundation

/// Feature flags for controlling which features are visible to users
/// Change `false` to `true` to enable a feature
struct FeatureFlags {
    
    // MARK: - Social Feed Features
    
    /// Controls visibility of the "Explore" tab in the social feed
    /// When false: Shows only All, Feed, Prompt, Genres
    /// When true: Shows All, Feed, Prompt, Explore, Genres
    static let showExploreTab = false
    
    // MARK: - Main Tab Features
    
    /// Controls visibility of the Home tab (Parties feature)
    /// When false: Home tab is hidden from bottom navigation
    /// When true: Home tab appears in bottom navigation
    static let showHomeTab = false  // 🔴 HIDDEN AGAIN
    
    /// Controls visibility of the Discussion tab
    /// When false: Discussion tab is hidden from bottom navigation
    /// When true: Discussion tab appears in bottom navigation
    static let showDiscussionTab = false
    
    // MARK: - Admin Override
    
    /// If true, admins can see all features regardless of flags above
    /// Useful for testing hidden features in production
    static let adminCanSeeAllFeatures = false
}

