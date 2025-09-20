import XCTest
import FirebaseFirestore
@testable import Bumpin

final class DailyPromptTests: XCTestCase {
    
    var coordinator: DailyPromptCoordinator!
    var mockPrompt: DailyPrompt!
    var mockResponse: PromptResponse!
    
    override func setUpWithError() throws {
        coordinator = DailyPromptCoordinator()
        
        // Create mock prompt
        mockPrompt = DailyPrompt(
            title: "Test Prompt",
            description: "A test prompt for unit testing",
            category: .mood,
            createdBy: "test_admin",
            expiresAt: Date().addingTimeInterval(3600)
        )
        mockPrompt.isActive = true
        mockPrompt.totalResponses = 5
        
        // Create mock response
        mockResponse = PromptResponse(
            promptId: mockPrompt.id,
            userId: "test_user",
            username: "TestUser",
            userProfilePictureUrl: nil,
            songId: "test_song_123",
            songTitle: "Test Song",
            artistName: "Test Artist",
            albumName: "Test Album",
            explanation: "This is a test explanation"
        )
    }
    
    override func tearDownWithError() throws {
        coordinator = nil
        mockPrompt = nil
        mockResponse = nil
    }
    
    // MARK: - Data Model Tests
    
    func testDailyPromptCreation() throws {
        XCTAssertEqual(mockPrompt.title, "Test Prompt")
        XCTAssertEqual(mockPrompt.category, .mood)
        XCTAssertTrue(mockPrompt.isActive)
        XCTAssertFalse(mockPrompt.isArchived)
        XCTAssertEqual(mockPrompt.totalResponses, 5)
    }
    
    func testPromptResponseCreation() throws {
        XCTAssertEqual(mockResponse.songTitle, "Test Song")
        XCTAssertEqual(mockResponse.artistName, "Test Artist")
        XCTAssertEqual(mockResponse.explanation, "This is a test explanation")
        XCTAssertTrue(mockResponse.isPublic)
        XCTAssertFalse(mockResponse.isHidden)
    }
    
    func testPromptCategoryProperties() throws {
        XCTAssertEqual(PromptCategory.mood.displayName, "Mood")
        XCTAssertEqual(PromptCategory.mood.icon, "face.smiling")
        XCTAssertNotNil(PromptCategory.mood.color)
        
        XCTAssertEqual(PromptCategory.activity.displayName, "Activity")
        XCTAssertEqual(PromptCategory.nostalgia.displayName, "Nostalgia")
    }
    
    // MARK: - Coordinator Tests
    
    func testCoordinatorInitialization() throws {
        XCTAssertNotNil(coordinator.promptService)
        XCTAssertNotNil(coordinator.interactionService)
        XCTAssertNotNil(coordinator.adminService)
        XCTAssertFalse(coordinator.isInitializing)
    }
    
    func testCanRespondToPromptLogic() throws {
        // Mock current prompt
        coordinator.promptService.currentPrompt = mockPrompt
        coordinator.promptService.userResponse = nil
        
        XCTAssertTrue(coordinator.canRespondToCurrentPrompt)
        
        // Test with existing response
        coordinator.promptService.userResponse = mockResponse
        XCTAssertFalse(coordinator.canRespondToCurrentPrompt)
        
        // Test with expired prompt
        coordinator.promptService.userResponse = nil
        mockPrompt.expiresAt = Date().addingTimeInterval(-3600) // 1 hour ago
        coordinator.promptService.currentPrompt = mockPrompt
        XCTAssertFalse(coordinator.canRespondToCurrentPrompt)
    }
    
    func testUserStreakCalculation() throws {
        let stats = UserPromptStats(userId: "test_user")
        var updatedStats = stats
        updatedStats.currentStreak = 5
        updatedStats.longestStreak = 10
        updatedStats.totalResponses = 15
        
        coordinator.promptService.userPromptStats = updatedStats
        
        XCTAssertEqual(coordinator.userStreak, 5)
        XCTAssertEqual(coordinator.userLongestStreak, 10)
        XCTAssertEqual(coordinator.userTotalResponses, 15)
    }
    
    func testTimeRemainingFormatting() throws {
        // Test with 2 hours remaining
        mockPrompt.expiresAt = Date().addingTimeInterval(7200) // 2 hours
        coordinator.promptService.currentPrompt = mockPrompt
        
        let timeRemaining = coordinator.formatTimeRemaining()
        XCTAssertNotNil(timeRemaining)
        XCTAssertTrue(timeRemaining!.contains("h"))
        
        // Test with expired prompt
        mockPrompt.expiresAt = Date().addingTimeInterval(-3600) // 1 hour ago
        coordinator.promptService.currentPrompt = mockPrompt
        
        let expiredTime = coordinator.formatTimeRemaining()
        XCTAssertNil(expiredTime)
    }
    
    // MARK: - Leaderboard Tests
    
    func testLeaderboardCalculation() throws {
        let responses = [
            PromptResponse(promptId: "test", userId: "user1", username: "User1", userProfilePictureUrl: nil, songId: "song1", songTitle: "Song 1", artistName: "Artist 1"),
            PromptResponse(promptId: "test", userId: "user2", username: "User2", userProfilePictureUrl: nil, songId: "song1", songTitle: "Song 1", artistName: "Artist 1"),
            PromptResponse(promptId: "test", userId: "user3", username: "User3", userProfilePictureUrl: nil, songId: "song2", songTitle: "Song 2", artistName: "Artist 2"),
        ]
        
        // Test that Song 1 should rank higher (2 votes vs 1 vote)
        let groupedBySong = Dictionary(grouping: responses) { $0.songId }
        XCTAssertEqual(groupedBySong["song1"]?.count, 2)
        XCTAssertEqual(groupedBySong["song2"]?.count, 1)
    }
    
    // MARK: - Template Tests
    
    func testPromptTemplateLibrary() throws {
        let templates = PromptTemplateLibrary.sampleTemplates
        XCTAssertFalse(templates.isEmpty)
        
        // Test category filtering
        let moodTemplates = PromptTemplateLibrary.templatesForCategory(.mood)
        XCTAssertFalse(moodTemplates.isEmpty)
        XCTAssertTrue(moodTemplates.allSatisfy { $0.category == .mood })
        
        // Test random template
        let randomTemplate = PromptTemplateLibrary.randomTemplate()
        XCTAssertNotNil(randomTemplate)
        
        // Test search functionality
        let vacationTemplates = PromptTemplateLibrary.searchTemplates("vacation")
        XCTAssertFalse(vacationTemplates.isEmpty)
        XCTAssertTrue(vacationTemplates.contains { $0.title.lowercased().contains("vacation") })
    }
    
    func testPromptGenerator() throws {
        // Test seasonal prompt generation
        let seasonalPrompt = PromptGenerator.generateSeasonalPrompt()
        XCTAssertNotNil(seasonalPrompt)
        
        // Test weekday prompt generation
        let weekdayPrompt = PromptGenerator.generateWeekdayPrompt()
        XCTAssertNotNil(weekdayPrompt)
    }
    
    // MARK: - Interaction Tests
    
    func testPromptResponseLike() throws {
        let like = PromptResponseLike(
            responseId: mockResponse.id,
            promptId: mockPrompt.id,
            userId: "test_user",
            username: "TestUser"
        )
        
        XCTAssertEqual(like.responseId, mockResponse.id)
        XCTAssertEqual(like.promptId, mockPrompt.id)
        XCTAssertEqual(like.username, "TestUser")
        XCTAssertNotNil(like.createdAt)
    }
    
    func testPromptResponseComment() throws {
        let comment = PromptResponseComment(
            responseId: mockResponse.id,
            promptId: mockPrompt.id,
            userId: "test_user",
            username: "TestUser",
            userProfilePictureUrl: nil,
            text: "Great song choice!"
        )
        
        XCTAssertEqual(comment.text, "Great song choice!")
        XCTAssertFalse(comment.isHidden)
        XCTAssertFalse(comment.isReported)
        XCTAssertEqual(comment.likeCount, 0)
    }
    
    // MARK: - Performance Tests
    
    func testCoordinatorPerformance() throws {
        measure {
            let coordinator = DailyPromptCoordinator()
            XCTAssertNotNil(coordinator)
        }
    }
    
    func testTemplateSearchPerformance() throws {
        measure {
            _ = PromptTemplateLibrary.searchTemplates("song")
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyPromptTitle() throws {
        // Test that empty titles are handled gracefully
        let emptyPrompt = DailyPrompt(
            title: "",
            description: nil,
            category: .random,
            createdBy: "test",
            expiresAt: Date().addingTimeInterval(3600)
        )
        
        XCTAssertEqual(emptyPrompt.title, "")
        XCTAssertNil(emptyPrompt.description)
    }
    
    func testResponseWithoutExplanation() throws {
        let response = PromptResponse(
            promptId: "test",
            userId: "user",
            username: "User",
            userProfilePictureUrl: nil,
            songId: "song",
            songTitle: "Song",
            artistName: "Artist"
        )
        
        XCTAssertNil(response.explanation)
        XCTAssertTrue(response.isPublic)
    }
    
    func testExpiredPromptHandling() throws {
        let expiredPrompt = DailyPrompt(
            title: "Expired Prompt",
            description: "This prompt has expired",
            category: .mood,
            createdBy: "admin",
            expiresAt: Date().addingTimeInterval(-3600) // 1 hour ago
        )
        
        coordinator.promptService.currentPrompt = expiredPrompt
        XCTAssertFalse(coordinator.canRespondToCurrentPrompt)
    }
    
    // MARK: - Analytics Tests
    
    func testAnalyticsIntegration() throws {
        // Test that analytics methods don't crash
        coordinator.trackPromptEngagement("test_action")
        coordinator.trackPromptEngagement("test_action", promptId: "test_id")
        
        // This is mainly to ensure no crashes occur
        XCTAssertTrue(true)
    }
}

// MARK: - Mock Extensions for Testing

extension DailyPromptCoordinator {
    static func mockForTesting() -> DailyPromptCoordinator {
        let coordinator = DailyPromptCoordinator()
        
        // Set up mock data
        let mockPrompt = DailyPrompt(
            title: "Test Prompt",
            description: "A test prompt",
            category: .mood,
            createdBy: "admin",
            expiresAt: Date().addingTimeInterval(3600)
        )
        mockPrompt.isActive = true
        mockPrompt.totalResponses = 10
        
        coordinator.promptService.currentPrompt = mockPrompt
        
        let mockStats = UserPromptStats(userId: "test_user")
        var updatedStats = mockStats
        updatedStats.currentStreak = 7
        updatedStats.longestStreak = 15
        updatedStats.totalResponses = 25
        
        coordinator.promptService.userPromptStats = updatedStats
        
        return coordinator
    }
}
