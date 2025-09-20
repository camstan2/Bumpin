import XCTest
@testable import Bumpin
import CoreLocation

final class PartyDiscoveryTests: XCTestCase {

    func testChunkedFanOutProducesExpectedBatches() {
        // 23 ids should split into [10, 10, 3]
        let ids = (1...23).map { "id\($0)" }
        let batches = ids.chunked(into: 10)
        XCTAssertEqual(batches.count, 3)
        XCTAssertEqual(batches[0].count, 10)
        XCTAssertEqual(batches[1].count, 10)
        XCTAssertEqual(batches[2].count, 3)
    }

    func testTrendingAlgorithmSortsByHeuristics() {
        let algo = PartyDiscoveryManager.TrendingAlgorithm()

        // Party A: many participants, recent activity, voice chat on, influencer
        var partyA = Party(name: "A", hostId: "h1", hostName: "Host1", latitude: 37.0, longitude: -122.0, isPublic: true, isInfluencerParty: true, influencerId: "inf", followerCount: 1000, isVerified: true)
        partyA.participants = (0..<12).map { _ in PartyParticipant(id: UUID().uuidString, name: "m", isHost: false) }
        partyA.voiceChatActive = true
        partyA.lastActivity = Date().addingTimeInterval(-5 * 60) // 5 minutes ago

        // Party B: few participants, no voice chat, older activity
        var partyB = Party(name: "B", hostId: "h2", hostName: "Host2", latitude: 37.0, longitude: -122.0, isPublic: true)
        partyB.participants = (0..<2).map { _ in PartyParticipant(id: UUID().uuidString, name: "m", isHost: false) }
        partyB.voiceChatActive = false
        partyB.lastActivity = Date().addingTimeInterval(-6 * 60 * 60) // 6 hours ago

        let sorted = algo.processParties([partyB, partyA])
        XCTAssertEqual(sorted.first?.name, "A")
        XCTAssertGreaterThan(sorted.first?.trendingScore ?? 0, sorted.last?.trendingScore ?? 0)
    }

    func testNearbyFilteringByDistance() {
        // User near SF
        let user = CLLocation(latitude: 37.7749, longitude: -122.4194)

        // Party near (within ~0.25 miles)
        var nearParty = Party(name: "Near", hostId: "h1", hostName: "Host1", latitude: 37.7760, longitude: -122.4194, isPublic: true)

        // Party far
        var farParty = Party(name: "Far", hostId: "h2", hostName: "Host2", latitude: 37.8044, longitude: -122.2711, isPublic: true) // Oakland

        XCTAssertTrue(nearParty.isWithinDiscoveryRange(of: user, maxDistance: 500))
        XCTAssertFalse(farParty.isWithinDiscoveryRange(of: user, maxDistance: 500))
    }
}


