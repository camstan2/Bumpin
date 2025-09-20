import XCTest
@testable import Bumpin

final class ScoringConfigTests: XCTestCase {
    func testDefaults() {
        let cfg = ScoringConfig.shared
        XCTAssertGreaterThan(cfg.helpfulWeight, 0)
        XCTAssertGreaterThan(cfg.commentsWeight, 0)
        XCTAssertGreaterThan(cfg.ratingWeight, 0)
        XCTAssertGreaterThan(cfg.decayHours, 0)
    }

    func testOverridesViaUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(5.0, forKey: "scoring.helpfulWeight")
        XCTAssertEqual(ScoringConfig.shared.helpfulWeight, 5.0, accuracy: 0.0001)
    }
}


