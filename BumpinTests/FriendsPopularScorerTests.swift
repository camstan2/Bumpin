import XCTest
@testable import Bumpin

final class FriendsPopularScorerTests: XCTestCase {
    func testFriendsPopularScoringOrdersByCountAndRecency() {
        let now = Date()
        let recent = MusicLog(id: "1", userId: "u1", itemId: "song1", itemType: "song", title: "A", artistName: "X", artworkUrl: nil, dateLogged: now, rating: 5, review: nil, notes: nil, commentCount: nil, helpfulCount: nil, unhelpfulCount: nil, reviewPhotos: nil, isLiked: nil, thumbsUp: nil, thumbsDown: nil, isPublic: true)
        let older = MusicLog(id: "2", userId: "u2", itemId: "song1", itemType: "song", title: "A", artistName: "X", artworkUrl: nil, dateLogged: now.addingTimeInterval(-6*3600), rating: 4, review: nil, notes: nil, commentCount: nil, helpfulCount: nil, unhelpfulCount: nil, reviewPhotos: nil, isLiked: nil, thumbsUp: nil, thumbsDown: nil, isPublic: true)
        let farOld = MusicLog(id: "3", userId: "u3", itemId: "song2", itemType: "song", title: "B", artistName: "Y", artworkUrl: nil, dateLogged: now.addingTimeInterval(-48*3600), rating: 5, review: nil, notes: nil, commentCount: nil, helpfulCount: nil, unhelpfulCount: nil, reviewPhotos: nil, isLiked: nil, thumbsUp: nil, thumbsDown: nil, isPublic: true)

        let score1 = PopularityService.scoreFriendsPopular(logs: [recent, older]) // 2 logs, recent
        let score2 = PopularityService.scoreFriendsPopular(logs: [farOld])        // 1 log, old
        XCTAssertGreaterThan(score1, score2)
    }
}


