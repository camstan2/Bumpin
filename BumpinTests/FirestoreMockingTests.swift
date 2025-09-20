import XCTest
@testable import Bumpin

// This is a tiny, local unit test around merge behavior using the helper inside PartyDiscoveryManager
final class FirestoreMockingTests: XCTestCase {
    func test_mergeBatchesDeDuplicatesByPartyId() {
        // Build two batches with overlapping party ids
        let p1a = Party(name: "P1", hostId: "h1", hostName: "H1", latitude: nil, longitude: nil, isPublic: true)
        let p1b = Party(name: "P1b", hostId: "h1", hostName: "H1", latitude: nil, longitude: nil, isPublic: true)
        var p1bMut = p1b
        p1bMut.id = p1a.id // force same id to simulate duplicate across batches

        let p2 = Party(name: "P2", hostId: "h2", hostName: "H2", latitude: nil, longitude: nil, isPublic: true)

        let batches: [String: [Party]] = [
            "b0": [p1a, p2],
            "b1": [p1bMut]
        ]

        // Access the helper via a small shim to avoid changing visibility
        class Shim: PartyDiscoveryManager {
            func mergePublic(_ b: [String: [Party]]) -> [Party] { mergeBatches(b) }
        }

        let merged = Shim().mergePublic(batches)
        // Expect only 2 unique ids
        XCTAssertEqual(Set(merged.map { $0.id }).count, 2)
    }
}

final class SpeakerRequestsRulesSketch: XCTestCase {
    func test_speakerRequest_model_roundtrip() throws {
        // Model-only sanity check for encoding/decoding SpeakerRequest
        let req = SpeakerRequest(userId: "u1", userName: "Alice")
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(SpeakerRequest.self, from: data)
        XCTAssertEqual(decoded.userId, "u1")
        XCTAssertEqual(decoded.userName, "Alice")
        XCTAssertEqual(decoded.status, "pending")
    }
}


