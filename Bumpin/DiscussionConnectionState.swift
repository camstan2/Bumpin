//
//  DiscussionConnectionState.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import Foundation

// MARK: - Discussion Connection State
enum DiscussionConnectionState: String, Codable, CaseIterable {
    case active = "active"           // Fully engaged in discussion
    case minimized = "minimized"     // Discussion running in background
    case disconnected = "disconnected" // Left discussion entirely
}
