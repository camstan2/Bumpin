//
//  BumpinTests.swift
//  BumpinTests
//
//  Created by Cam Stanley on 6/28/25.
//

import Foundation
import XCTest
@testable import Bumpin

final class BumpinTests: XCTestCase {

    func testQueuePermission_hostOnly_blocksNonHost() {
        var party = Party(name: "Test", hostId: "host", hostName: "Host")
        party.whoCanAddSongs = "host"
        // Non-host cannot add
        XCTAssertFalse(PartyManager.canUserAddSongs(userId: "user", in: party))
        // Host can add
        XCTAssertTrue(PartyManager.canUserAddSongs(userId: "host", in: party))
        // Co-host can add
        party.coHostIds = ["co"]
        XCTAssertTrue(PartyManager.canUserAddSongs(userId: "co", in: party))
    }

    func testAdmission_default_open() {
        let party = Party(name: "Test", hostId: "host", hostName: "Host")
        XCTAssertEqual(party.admissionMode, "open")
    }
    
    func testMuteAllExceptHost_pureHelper() {
        var party = Party(name: "T", hostId: "host", hostName: "Host")
        party.participants = [
            PartyParticipant(id: "host", name: "Host", isHost: true),
            PartyParticipant(id: "u1", name: "A"),
            PartyParticipant(id: "u2", name: "B")
        ]
        let result = PartyManager.mutedIdsAfterMuteAllExceptHost(party: party)
        XCTAssertTrue(result.contains("u1"))
        XCTAssertTrue(result.contains("u2"))
        XCTAssertFalse(result.contains("host"))
        let cleared = PartyManager.mutedIdsAfterUnmuteAll(party: party)
        XCTAssertTrue(cleared.isEmpty)
    }

    func testFilterParticipants_all_speaking_muted_and_query() {
        let participants = [
            PartyParticipant(id: "host", name: "Host", isHost: true),
            PartyParticipant(id: "a1", name: "Alice"),
            PartyParticipant(id: "b1", name: "Bob"),
            PartyParticipant(id: "c1", name: "Carol")
        ]
        let muted = ["b1"]
        let speaking = ["a1", "host"]
        // All
        XCTAssertEqual(PartyManager.filterParticipants(participants: participants, mutedIds: muted, voiceSpeakingIds: speaking, filter: "all", query: "").count, 4)
        // Speaking
        let spk = PartyManager.filterParticipants(participants: participants, mutedIds: muted, voiceSpeakingIds: speaking, filter: "speaking", query: "")
        XCTAssertEqual(spk.map{ $0.id }.sorted(), ["a1","host"].sorted())
        // Muted
        let m = PartyManager.filterParticipants(participants: participants, mutedIds: muted, voiceSpeakingIds: speaking, filter: "muted", query: "")
        XCTAssertEqual(m.map{ $0.id }, ["b1"])
        // Query
        let q = PartyManager.filterParticipants(participants: participants, mutedIds: muted, voiceSpeakingIds: speaking, filter: "all", query: "al")
        XCTAssertEqual(q.map{ $0.id }, ["a1"])
    }

    func testDeepLinkParser_extracts_code() {
        let url = URL(string: "bumpin://join?code=ABC123")!
        XCTAssertEqual(DeepLinkParser.parseJoinCode(from: url), "ABC123")
        let bad = URL(string: "bumpin://home")!
        XCTAssertNil(DeepLinkParser.parseJoinCode(from: bad))
    }

    @MainActor
    func testUniversalLink_parser_and_builder_roundtrip() {
        let invite = DeepLinkParser.buildInviteURL(forCode: " zzz999 ")
        XCTAssertEqual(invite?.absoluteString, "https://example.com/join/ZZZ999")
        if let invite {
            XCTAssertEqual(DeepLinkParser.parseUniversalJoinCode(from: invite), "ZZZ999")
        }
        let unrelated = URL(string: "https://example.com/other/ABC123")!
        XCTAssertNil(DeepLinkParser.parseUniversalJoinCode(from: unrelated))
    }
}
