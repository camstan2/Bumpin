import XCTest
@testable import Bumpin

final class DeepLinkParserTests: XCTestCase {
    override func setUp() async throws {
        await AppConfig.shared._overrideUniversalLinkDomainsForTests(["example.com", "test.bumpin.app"], primary: "example.com")
    }

    func testParseJoinCode_CustomScheme() {
        let url = URL(string: "bumpin://join?code=ABC123")!
        let code = DeepLinkParser.parseJoinCode(from: url)
        XCTAssertEqual(code, "ABC123")
    }

    func testParseJoinCode_CustomScheme_Invalid() {
        let url = URL(string: "bumpin://open?foo=bar")!
        let code = DeepLinkParser.parseJoinCode(from: url)
        XCTAssertNil(code)
    }

    func testParseUniversalJoinCode_AllowedHost() async {
        await MainActor.run {
            let url = URL(string: "https://example.com/join/ZZZ999")!
            let code = DeepLinkParser.parseUniversalJoinCode(from: url)
            XCTAssertEqual(code, "ZZZ999")
        }
    }

    func testParseUniversalJoinCode_DisallowedHost() async {
        await MainActor.run {
            let url = URL(string: "https://bad.example.org/join/HELLO1")!
            let code = DeepLinkParser.parseUniversalJoinCode(from: url)
            XCTAssertNil(code)
        }
    }

    func testBuildInviteURL_UsesPrimaryDomain() async {
        await MainActor.run {
            let url = DeepLinkParser.buildInviteURL(forCode: "abc123")
            XCTAssertEqual(url?.absoluteString, "https://example.com/join/ABC123")
        }
    }
}

import XCTest
@testable import Bumpin

final class DeepLinkParserTests: XCTestCase {
    override func setUp() async throws {
        await MainActor.run {
            // Make sure test domains are allowed
            // We can't write to Firestore here; set local state by calling ensureDefault if needed
            // For unit tests, override via reflection on AppConfig's published vars
            // Unsafe but fine for unit tests: use KVC to set published properties
            let cfg = AppConfig.shared
            cfg.stopLinksConfigListener()
            // Set directly to avoid async Firestore dependency in tests
            // Note: These properties are private(set); use KeyPath to set via KVC
            cfg.setValue(["example.com", "test.bumpin.app"], forKey: "universalLinkDomains")
            cfg.setValue("example.com", forKey: "primaryUniversalLinkDomain")
        }
    }

    func testParseJoinCode_CustomScheme() {
        let url = URL(string: "bumpin://join?code=ABC123")!
        let code = DeepLinkParser.parseJoinCode(from: url)
        XCTAssertEqual(code, "ABC123")
    }

    func testParseJoinCode_CustomScheme_Invalid() {
        let url = URL(string: "bumpin://open?foo=bar")!
        let code = DeepLinkParser.parseJoinCode(from: url)
        XCTAssertNil(code)
    }

    func testParseUniversalJoinCode_AllowedHost() async {
        await MainActor.run {
            let url = URL(string: "https://example.com/join/ZZZ999")!
            let code = DeepLinkParser.parseUniversalJoinCode(from: url)
            XCTAssertEqual(code, "ZZZ999")
        }
    }

    func testParseUniversalJoinCode_DisallowedHost() async {
        await MainActor.run {
            let url = URL(string: "https://bad.example.org/join/HELLO1")!
            let code = DeepLinkParser.parseUniversalJoinCode(from: url)
            XCTAssertNil(code)
        }
    }

    func testBuildInviteURL_UsesPrimaryDomain() async {
        await MainActor.run {
            let url = DeepLinkParser.buildInviteURL(forCode: "abc123")
            XCTAssertEqual(url?.absoluteString, "https://example.com/join/ABC123")
        }
    }
}

import XCTest
@testable import Bumpin

final class DeepLinkParserTests: XCTestCase {
    func test_parseJoinCode_customScheme() {
        let url = URL(string: "bumpin://join?code=ABC123")!
        XCTAssertEqual(DeepLinkParser.parseJoinCode(from: url), "ABC123")
    }

    func test_parseUniversalJoinCode_allowsConfiguredDomain() {
        // AppConfig defaults to example.com domains
        let url = URL(string: "https://example.com/join/ZZZ999")!
        XCTAssertEqual(DeepLinkParser.parseUniversalJoinCode(from: url), "ZZZ999")
    }

    func test_parseUniversalJoinCode_rejectsUnknownDomain() {
        let url = URL(string: "https://not-allowed.com/join/ABC123")!
        XCTAssertNil(DeepLinkParser.parseUniversalJoinCode(from: url))
    }

    func test_parseUniversalJoinCode_trimsAndUppercases() {
        // lowercase code should be uppercased by parser logic
        let url = URL(string: "https://example.com/join/abc123")!
        XCTAssertEqual(DeepLinkParser.parseUniversalJoinCode(from: url), "ABC123")
    }

    func test_parseUniversalJoinCode_badPathsReturnNil() {
        XCTAssertNil(DeepLinkParser.parseUniversalJoinCode(from: URL(string: "https://example.com/")!))
        XCTAssertNil(DeepLinkParser.parseUniversalJoinCode(from: URL(string: "https://example.com/join")!))
        XCTAssertNil(DeepLinkParser.parseUniversalJoinCode(from: URL(string: "https://example.com/other/ABC123")!))
    }
}


