import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class RandomChatMatchingService {
    static let shared = RandomChatMatchingService()
    private let db = Firestore.firestore()
    private var matchingTimer: Timer?
    private let matchingInterval: TimeInterval = 5 // Check for matches every 5 seconds
    
    private init() {
        startMatchingProcess()
    }
    
    deinit {
        stopMatchingProcess()
    }
    
    // MARK: - Matching Process
    
    private func startMatchingProcess() {
        matchingTimer = Timer.scheduledTimer(withTimeInterval: matchingInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.processQueue()
            }
        }
    }
    
    private func stopMatchingProcess() {
        matchingTimer?.invalidate()
        matchingTimer = nil
    }
    
    private func processQueue() async {
        do {
            // Get all waiting requests, ordered by timestamp
            let snapshot = try await db.collection("randomChatQueue")
                .whereField("status", isEqualTo: QueueStatus.waiting.rawValue)
                .order(by: "timestamp")
                .getDocuments()
            
            var requests = snapshot.documents.compactMap { doc -> QueueRequest? in
                try? Firestore.Decoder().decode(QueueRequest.self, from: doc.data())
            }
            
            print("🔍 RandomChatMatchingService: Found \(requests.count) waiting requests")
            
            // For testing: if there's only 1 person, create a mock second person
            if requests.count == 1 {
                print("🤖 RandomChatMatchingService: Creating mock second user for testing")
                let mockRequest = QueueRequest(
                    userId: "mock_user_\(UUID().uuidString.prefix(8))",
                    userName: "Test User",
                    groupSize: 1,
                    genderPreference: .any
                )
                requests.append(mockRequest)
                
                // Add mock request to Firestore temporarily
                try await db.collection("randomChatQueue").document(mockRequest.id).setData([
                    "id": mockRequest.id,
                    "userId": mockRequest.userId,
                    "userName": mockRequest.userName,
                    "groupSize": mockRequest.groupSize,
                    "genderPreference": mockRequest.genderPreference?.rawValue ?? "any",
                    "timestamp": FieldValue.serverTimestamp(),
                    "groupMembers": mockRequest.groupMembers,
                    "status": QueueStatus.waiting.rawValue
                ])
            }
            
            // Process solo requests first
            await processSoloRequests(&requests)
            
            // Process group requests
            await processGroupRequests(&requests)
            
        } catch {
            print("❌ RandomChatMatchingService: Error processing queue: \(error)")
        }
    }
    
    // MARK: - Solo Matching
    
    private func processSoloRequests(_ requests: inout [QueueRequest]) async {
        // Filter solo requests
        let soloRequests = requests.filter { $0.groupSize == 1 }
        print("👤 RandomChatMatchingService: Processing \(soloRequests.count) solo requests")
        
        guard soloRequests.count >= 2 else { 
            print("⏳ RandomChatMatchingService: Not enough solo requests for matching (need 2, have \(soloRequests.count))")
            return 
        }
        
        var processedIds = Set<String>()
        
        // Try to match pairs with compatible preferences
        for request1 in soloRequests {
            guard !processedIds.contains(request1.id) else { continue }
            
            if let match = findBestMatch(for: request1, in: soloRequests, excluding: processedIds) {
                print("✅ RandomChatMatchingService: Found match! \(request1.userName) + \(match.userName)")
                processedIds.insert(request1.id)
                processedIds.insert(match.id)
                
                // Create the match
                await createMatch(between: [request1, match])
            }
        }
        
        // Remove processed requests from the main list
        requests = requests.filter { !processedIds.contains($0.id) }
    }
    
    // MARK: - Group Matching
    
    private func processGroupRequests(_ requests: inout [QueueRequest]) async {
        // Group requests by size
        let groupedRequests = Dictionary(grouping: requests) { $0.groupSize }
        
        for (size, sizeRequests) in groupedRequests {
            guard sizeRequests.count >= 2 else { continue }
            
            var processedIds = Set<String>()
            
            // Try to match groups of the same size
            for request1 in sizeRequests {
                guard !processedIds.contains(request1.id) else { continue }
                
                if let match = findBestGroupMatch(for: request1, in: sizeRequests, excluding: processedIds) {
                    processedIds.insert(request1.id)
                    processedIds.insert(match.id)
                    
                    // Create the match
                    await createMatch(between: [request1, match])
                }
            }
            
            // Remove processed requests
            requests = requests.filter { !processedIds.contains($0.id) }
        }
    }
    
    // MARK: - Matching Helpers
    
    private func findBestMatch(for request: QueueRequest, in candidates: [QueueRequest], excluding processedIds: Set<String>) -> QueueRequest? {
        // Filter candidates based on basic criteria
        let validCandidates = candidates.filter { candidate in
            // Skip if already processed or same request
            guard !processedIds.contains(candidate.id) && candidate.id != request.id else { return false }
            
            // Check gender preferences compatibility
            let genderMatch = isGenderPreferenceCompatible(request.genderPreference, candidate.genderPreference)
            
            // Check group size compatibility (must be the same)
            let sizeMatch = candidate.groupSize == request.groupSize
            
            return genderMatch && sizeMatch
        }
        
        // Sort candidates by wait time (oldest first)
        let sortedCandidates = validCandidates.sorted { a, b in
            a.timestamp < b.timestamp
        }
        
        // Return the best match (oldest waiting)
        return sortedCandidates.first
    }
    
    private func findBestGroupMatch(for request: QueueRequest, in candidates: [QueueRequest], excluding processedIds: Set<String>) -> QueueRequest? {
        // Filter candidates based on basic criteria
        let validCandidates = candidates.filter { candidate in
            // Skip if already processed or same request
            guard !processedIds.contains(candidate.id) && candidate.id != request.id else { return false }
            
            // Check if groups are complete
            let group1Complete = request.groupMembers.count == request.groupSize
            let group2Complete = candidate.groupMembers.count == candidate.groupSize
            
            // Check group size compatibility (must be the same)
            let sizeMatch = candidate.groupSize == request.groupSize
            
            // Check gender preferences compatibility
            let genderMatch = isGenderPreferenceCompatible(request.genderPreference, candidate.genderPreference)
            
            // Check for no overlapping members
            let noOverlap = Set(request.groupMembers).intersection(Set(candidate.groupMembers)).isEmpty
            
            return group1Complete && group2Complete && sizeMatch && genderMatch && noOverlap
        }
        
        // Sort candidates by:
        // 1. Wait time (oldest first)
        // 2. Group completeness (complete groups first)
        let sortedCandidates = validCandidates.sorted { a, b in
            if a.groupMembers.count == b.groupMembers.count {
                return a.timestamp < b.timestamp
            }
            return a.groupMembers.count > b.groupMembers.count
        }
        
        // Return the best match
        return sortedCandidates.first
    }
    
    private func isGenderPreferenceCompatible(_ pref1: GenderPreference?, _ pref2: GenderPreference?) -> Bool {
        // If either preference is nil or .any, they're compatible
        guard let p1 = pref1, let p2 = pref2,
              p1 != .any, p2 != .any else { return true }
        
        // For specific preferences, they must match
        return p1 == p2
    }
    
    // MARK: - Match Creation
    
    private func createMatch(between requests: [QueueRequest]) async {
        do {
            print("🎉 RandomChatMatchingService: Creating match between \(requests.count) users")
            
            // Create a new chat
            let chatId = UUID().uuidString
            let allParticipants = requests.flatMap { $0.groupMembers }
            
            let chat = TopicChat(
                title: "Random Chat",
                description: "A randomly matched conversation",
                category: TopicCategory.trending,
                hostId: requests[0].userId,
                hostName: requests[0].userName,
                isVerified: false
            )
            
            // Update chat with participants
            var chatData = chat.toFirestore()
            chatData["id"] = chatId
            chatData["participants"] = allParticipants
            chatData["isRandomMatch"] = true
            chatData["matchTimestamp"] = FieldValue.serverTimestamp()
            
            print("💾 RandomChatMatchingService: Creating chat document \(chatId)")
            
            // Start a batch write
            let batch = db.batch()
            
            // Create the chat document
            let chatRef = db.collection("randomChats").document(chatId)
            batch.setData(chatData, forDocument: chatRef)
            
            // Update all queue requests to matched status
            for request in requests {
                let requestRef = db.collection("randomChatQueue").document(request.id)
                batch.updateData([
                    "status": QueueStatus.matched.rawValue,
                    "matchedChatId": chatId
                ], forDocument: requestRef)
                print("📝 RandomChatMatchingService: Updating request \(request.id) to matched status")
            }
            
            // Commit the batch
            try await batch.commit()
            print("✅ RandomChatMatchingService: Match created successfully!")
            
            // Log analytics
            AnalyticsService.shared.logMatchCreated(matchId: chatId, userIds: allParticipants)
            
            // Track social interaction
            await SocialInteractionTracker.shared.trackRandomChatInteraction(
                chatId: chatId,
                participantIds: allParticipants,
                topic: "Random Chat"
            )
            
        } catch {
            print("Error creating match: \(error)")
        }
    }
}
