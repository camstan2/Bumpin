import XCTest
@testable import Bumpin
import FirebaseFirestore

class RandomChatTests: XCTestCase {
    var viewModel: RandomChatViewModel!
    var service: MockRandomChatService!
    
    override func setUp() {
        super.setUp()
        service = MockRandomChatService()
        viewModel = RandomChatViewModel()
        // Inject mock service
        viewModel.service = service
    }
    
    override func tearDown() {
        viewModel = nil
        service = nil
        super.tearDown()
    }
    
    // MARK: - Queue Tests
    
    func testJoinQueue() async {
        // Given
        let expectation = XCTestExpectation(description: "Join queue")
        service.joinQueueResult = .success(())
        
        // When
        viewModel.joinQueue()
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertTrue(viewModel.isInQueue)
        XCTAssertEqual(viewModel.queueTimeString, "0:00")
        XCTAssertEqual(viewModel.groupSize, 1)
    }
    
    func testJoinQueueFailure() async {
        // Given
        let expectation = XCTestExpectation(description: "Join queue failure")
        service.joinQueueResult = .failure(NSError(domain: "test", code: 1))
        
        // When
        viewModel.joinQueue()
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(viewModel.isInQueue)
        XCTAssertNotNil(viewModel.error)
    }
    
    func testLeaveQueue() async {
        // Given
        let expectation = XCTestExpectation(description: "Leave queue")
        service.leaveQueueResult = .success(())
        viewModel.isInQueue = true
        
        // When
        viewModel.leaveQueue()
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(viewModel.isInQueue)
        XCTAssertEqual(viewModel.queueTimeString, "0:00")
    }
    
    // MARK: - Group Tests
    
    func testGroupSizeUpdate() {
        // Given
        let newSize = 2
        
        // When
        viewModel.setGroupSize(newSize)
        
        // Then
        XCTAssertEqual(viewModel.groupSize, newSize)
    }
    
    func testInviteFriend() async {
        // Given
        let expectation = XCTestExpectation(description: "Invite friend")
        let friend = RandomChatFriend(id: "1", name: "Test", status: "Online")
        service.inviteFriendResult = .success(())
        
        // When
        viewModel.inviteFriend(friend)
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertTrue(viewModel.friends.first { $0.id == friend.id }?.isInvited ?? false)
    }
    
    // MARK: - Matching Tests
    
    func testGenderPreferenceMatching() {
        // Given
        let matchingService = RandomChatMatchingService()
        let request1 = QueueRequest(userId: "1", userName: "Test1", groupSize: 1, genderPreference: .male)
        let request2 = QueueRequest(userId: "2", userName: "Test2", groupSize: 1, genderPreference: .male)
        let request3 = QueueRequest(userId: "3", userName: "Test3", groupSize: 1, genderPreference: .female)
        
        // When & Then
        XCTAssertTrue(matchingService.isGenderPreferenceCompatible(request1.genderPreference, request2.genderPreference))
        XCTAssertFalse(matchingService.isGenderPreferenceCompatible(request1.genderPreference, request3.genderPreference))
    }
    
    func testQueueTimeout() async {
        // Given
        let expectation = XCTestExpectation(description: "Queue timeout")
        viewModel.isInQueue = true
        viewModel.queueStartTime = Date().addingTimeInterval(-301) // 5 minutes + 1 second ago
        
        // When
        viewModel.updateQueueTime()
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(viewModel.isInQueue)
        XCTAssertNotNil(viewModel.error)
    }
}

// MARK: - Mock Service
class MockRandomChatService: RandomChatService {
    var joinQueueResult: Result<Void, Error> = .success(())
    var leaveQueueResult: Result<Void, Error> = .success(())
    var inviteFriendResult: Result<Void, Error> = .success(())
    
    override func joinQueue(groupSize: Int, genderPreference: GenderPreference?) async throws {
        switch joinQueueResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
    
    override func leaveQueue() async throws {
        switch leaveQueueResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
    
    override func inviteFriend(_ friendId: String) async throws {
        switch inviteFriendResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
}
