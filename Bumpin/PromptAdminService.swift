import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Prompt Admin Service

@MainActor
class PromptAdminService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var allPrompts: [DailyPrompt] = []
    @Published var promptTemplates: [PromptTemplate] = []
    @Published var scheduledPrompts: [DailyPrompt] = []
    @Published var archivedPrompts: [DailyPrompt] = []
    
    // Loading states
    @Published var isLoadingPrompts = false
    @Published var isCreatingPrompt = false
    @Published var isUpdatingPrompt = false
    
    // Error handling
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Admin Authentication
    
    var isAdmin: Bool {
        // Check if current user is admin
        guard Auth.auth().currentUser != nil else { return false }
        // This would typically check user roles in Firestore
        // For now, return true for development
        return true // TODO: Implement proper admin check
    }
    
    // MARK: - Initialization
    
    init() {
        Task {
            await loadAllData()
        }
    }
    
    // MARK: - Data Loading
    
    func loadAllData() async {
        guard isAdmin else { return }
        
        await loadAllPrompts()
        await loadPromptTemplates()
        loadTemplateLibrary()
    }
    
    func loadAllPrompts() async {
        guard isAdmin else { return }
        
        isLoadingPrompts = true
        defer { isLoadingPrompts = false }
        
        do {
            let snapshot = try await db.collection("dailyPrompts")
                .order(by: "date", descending: true)
                .limit(to: 100)
                .getDocuments()
            
            let prompts = snapshot.documents.compactMap { doc in
                try? doc.data(as: DailyPrompt.self)
            }
            
            allPrompts = prompts
            
            // Separate into categories
            scheduledPrompts = prompts.filter { !$0.isActive && !$0.isArchived && $0.date > Date() }
            archivedPrompts = prompts.filter { $0.isArchived }
            
        } catch {
            handleError(error)
        }
    }
    
    func loadPromptTemplates() async {
        guard isAdmin else { return }
        
        do {
            let snapshot = try await db.collection("promptTemplates")
                .whereField("isActive", isEqualTo: true)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            promptTemplates = snapshot.documents.compactMap { doc in
                try? doc.data(as: PromptTemplate.self)
            }
            
        } catch {
            handleError(error)
        }
    }
    
    private func loadTemplateLibrary() {
        // Add sample templates to the list if not already present
        let existingTitles = Set(promptTemplates.map { $0.title })
        let newTemplates = PromptTemplateLibrary.sampleTemplates.filter { template in
            !existingTitles.contains(template.title)
        }
        
        promptTemplates.append(contentsOf: newTemplates)
    }
    
    // MARK: - Prompt Creation
    
    func createPrompt(
        title: String,
        description: String?,
        category: PromptCategory,
        scheduledDate: Date? = nil,
        activateImmediately: Bool = false
    ) async -> Bool {
        
        guard isAdmin else {
            handleError(NSError(domain: "AdminError", code: 403, userInfo: [NSLocalizedDescriptionKey: "Admin access required"]))
            return false
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            handleError(NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return false
        }
        
        isCreatingPrompt = true
        defer { isCreatingPrompt = false }
        
        do {
            // Calculate expiration date (24 hours after activation)
            let activationDate = scheduledDate ?? Date()
            let expirationDate = Calendar.current.date(byAdding: .day, value: 1, to: activationDate) ?? activationDate.addingTimeInterval(86400)
            
            // Create prompt
            var prompt = DailyPrompt(
                title: title,
                description: description,
                category: category,
                createdBy: userId,
                expiresAt: expirationDate
            )
            
            // Set activation status
            if activateImmediately {
                // Deactivate any currently active prompts first
                await deactivateAllPrompts()
                prompt.isActive = true
            } else {
                prompt.date = scheduledDate ?? Date()
            }
            
            // Save to Firestore
            try await db.collection("dailyPrompts").document(prompt.id).setData(from: prompt)
            
            // Update local state
            allPrompts.insert(prompt, at: 0)
            
            if activateImmediately {
                // Remove from scheduled, add to active
                scheduledPrompts.removeAll { $0.isActive }
            } else if scheduledDate != nil {
                scheduledPrompts.insert(prompt, at: 0)
            }
            
            // Track analytics
            AnalyticsService.shared.logEvent("admin_prompt_created", parameters: [
                "prompt_id": prompt.id,
                "category": category.rawValue,
                "activated_immediately": activateImmediately,
                "has_description": description != nil
            ])
            
            return true
            
        } catch {
            handleError(error)
            return false
        }
    }
    
    func createPromptFromTemplate(_ template: PromptTemplate, scheduledDate: Date? = nil) async -> Bool {
        return await createPrompt(
            title: template.title,
            description: template.description,
            category: template.category,
            scheduledDate: scheduledDate,
            activateImmediately: false
        )
    }
    
    // MARK: - Prompt Management
    
    func activatePrompt(_ promptId: String) async -> Bool {
        guard isAdmin else { return false }
        
        isUpdatingPrompt = true
        defer { isUpdatingPrompt = false }
        
        do {
            // First deactivate all currently active prompts
            await deactivateAllPrompts()
            
            // Activate the selected prompt
            try await db.collection("dailyPrompts").document(promptId).updateData([
                "isActive": true,
                "date": FieldValue.serverTimestamp()
            ])
            
            // Update local state
            if let index = allPrompts.firstIndex(where: { $0.id == promptId }) {
                allPrompts[index].isActive = true
                allPrompts[index].date = Date()
            }
            
            // Remove from scheduled
            scheduledPrompts.removeAll { $0.id == promptId }
            
            // Track analytics
            AnalyticsService.shared.logEvent("admin_prompt_activated", parameters: [
                "prompt_id": promptId
            ])
            
            return true
            
        } catch {
            handleError(error)
            return false
        }
    }
    
    func deactivatePrompt(_ promptId: String) async -> Bool {
        guard isAdmin else { return false }
        
        isUpdatingPrompt = true
        defer { isUpdatingPrompt = false }
        
        do {
            try await db.collection("dailyPrompts").document(promptId).updateData([
                "isActive": false
            ])
            
            // Update local state
            if let index = allPrompts.firstIndex(where: { $0.id == promptId }) {
                allPrompts[index].isActive = false
            }
            
            return true
            
        } catch {
            handleError(error)
            return false
        }
    }
    
    private func deactivateAllPrompts() async {
        do {
            let activePrompts = try await db.collection("dailyPrompts")
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            
            let batch = db.batch()
            
            for document in activePrompts.documents {
                batch.updateData(["isActive": false], forDocument: document.reference)
            }
            
            try await batch.commit()
            
            // Update local state
            for i in 0..<allPrompts.count {
                allPrompts[i].isActive = false
            }
            
        } catch {
            handleError(error)
        }
    }
    
    func archivePrompt(_ promptId: String) async -> Bool {
        guard isAdmin else { return false }
        
        do {
            try await db.collection("dailyPrompts").document(promptId).updateData([
                "isActive": false,
                "isArchived": true
            ])
            
            // Update local state
            if let index = allPrompts.firstIndex(where: { $0.id == promptId }) {
                let prompt = allPrompts[index]
                allPrompts[index].isActive = false
                allPrompts[index].isArchived = true
                
                // Move to archived
                archivedPrompts.insert(prompt, at: 0)
                scheduledPrompts.removeAll { $0.id == promptId }
            }
            
            return true
            
        } catch {
            handleError(error)
            return false
        }
    }
    
    func deletePrompt(_ promptId: String) async -> Bool {
        guard isAdmin else { return false }
        
        do {
            // Delete the prompt
            try await db.collection("dailyPrompts").document(promptId).delete()
            
            // Also delete associated responses and leaderboard
            await deletePromptData(promptId)
            
            // Update local state
            allPrompts.removeAll { $0.id == promptId }
            scheduledPrompts.removeAll { $0.id == promptId }
            archivedPrompts.removeAll { $0.id == promptId }
            
            return true
            
        } catch {
            handleError(error)
            return false
        }
    }
    
    private func deletePromptData(_ promptId: String) async {
        do {
            let batch = db.batch()
            
            // Delete responses
            let responses = try await db.collection("promptResponses")
                .whereField("promptId", isEqualTo: promptId)
                .getDocuments()
            
            for document in responses.documents {
                batch.deleteDocument(document.reference)
            }
            
            // Delete leaderboard
            let leaderboardRef = db.collection("promptLeaderboards").document(promptId)
            batch.deleteDocument(leaderboardRef)
            
            try await batch.commit()
            
        } catch {
            print("Error deleting prompt data: \(error)")
        }
    }
    
    // MARK: - Template Management
    
    func createTemplate(
        title: String,
        description: String?,
        category: PromptCategory,
        tags: [String] = []
    ) async -> Bool {
        
        guard isAdmin else { return false }
        
        do {
            let template = PromptTemplate(
                title: title,
                description: description,
                category: category,
                tags: tags
            )
            
            try await db.collection("promptTemplates").document(template.id).setData(from: template)
            
            promptTemplates.insert(template, at: 0)
            
            return true
            
        } catch {
            handleError(error)
            return false
        }
    }
    
    func updateTemplate(_ template: PromptTemplate) async -> Bool {
        guard isAdmin else { return false }
        
        do {
            try await db.collection("promptTemplates").document(template.id).setData(from: template)
            
            if let index = promptTemplates.firstIndex(where: { $0.id == template.id }) {
                promptTemplates[index] = template
            }
            
            return true
            
        } catch {
            handleError(error)
            return false
        }
    }
    
    func deleteTemplate(_ templateId: String) async -> Bool {
        guard isAdmin else { return false }
        
        do {
            try await db.collection("promptTemplates").document(templateId).delete()
            promptTemplates.removeAll { $0.id == templateId }
            return true
            
        } catch {
            handleError(error)
            return false
        }
    }
    
    // MARK: - Analytics & Insights
    
    func generatePromptAnalytics(_ promptId: String) async -> PromptStats? {
        guard isAdmin else { return nil }
        
        do {
            // Fetch all responses for this prompt
            let responses = try await db.collection("promptResponses")
                .whereField("promptId", isEqualTo: promptId)
                .getDocuments()
            
            let responseData = responses.documents.compactMap { doc in
                try? doc.data(as: PromptResponse.self)
            }
            
            // Fetch likes and comments
            let likes = try await db.collection("promptResponseLikes")
                .whereField("promptId", isEqualTo: promptId)
                .getDocuments()
            
            let comments = try await db.collection("promptResponseComments")
                .whereField("promptId", isEqualTo: promptId)
                .getDocuments()
            
            // Calculate statistics
            let totalResponses = responseData.count
            let uniqueArtists = Set(responseData.map { $0.artistName }).count
            let totalLikes = likes.documents.count
            let totalComments = comments.documents.count
            
            // Calculate response times
            guard let prompt = allPrompts.first(where: { $0.id == promptId }) else { return nil }
            
            let responseTimes = responseData.map { response in
                response.submittedAt.timeIntervalSince(prompt.date)
            }
            
            let responseTimeStats = PromptStats.ResponseTimeStats(
                averageTime: responseTimes.isEmpty ? 0 : responseTimes.reduce(0, +) / Double(responseTimes.count),
                fastestTime: responseTimes.min() ?? 0,
                slowestTime: responseTimes.max() ?? 0,
                medianTime: responseTimes.sorted()[responseTimes.count / 2]
            )
            
            let engagementStats = PromptStats.EngagementStats(
                totalLikes: totalLikes,
                totalComments: totalComments,
                averageLikesPerResponse: totalResponses > 0 ? Double(totalLikes) / Double(totalResponses) : 0,
                averageCommentsPerResponse: totalResponses > 0 ? Double(totalComments) / Double(totalResponses) : 0,
                shareCount: 0 // TODO: Track sharing
            )
            
            return PromptStats(
                promptId: promptId,
                totalResponses: totalResponses,
                uniqueArtists: uniqueArtists,
                uniqueGenres: 0, // TODO: Implement genre classification
                averageRating: nil, // TODO: If we add ratings to responses
                responseTimeStats: responseTimeStats,
                engagementStats: engagementStats,
                demographicBreakdown: nil // TODO: Add demographic analysis
            )
            
        } catch {
            handleError(error)
            return nil
        }
    }
    
    // MARK: - Scheduling & Automation
    
    func schedulePrompt(_ promptId: String, for date: Date) async -> Bool {
        guard isAdmin else { return false }
        
        do {
            try await db.collection("dailyPrompts").document(promptId).updateData([
                "date": Timestamp(date: date),
                "isActive": false
            ])
            
            // Update local state
            if let index = allPrompts.firstIndex(where: { $0.id == promptId }) {
                allPrompts[index].date = date
                allPrompts[index].isActive = false
                
                // Move to scheduled if future date
                if date > Date() {
                    scheduledPrompts.insert(allPrompts[index], at: 0)
                    scheduledPrompts.sort { $0.date < $1.date }
                }
            }
            
            return true
            
        } catch {
            handleError(error)
            return false
        }
    }
    
    func generateSmartPrompt() -> PromptTemplate? {
        // Use the smart generation from PromptGenerator
        if let seasonalPrompt = PromptGenerator.generateSeasonalPrompt() {
            return seasonalPrompt
        }
        
        if let weekdayPrompt = PromptGenerator.generateWeekdayPrompt() {
            return weekdayPrompt
        }
        
        if let holidayPrompt = PromptGenerator.generateHolidayPrompt() {
            return holidayPrompt
        }
        
        // Fallback to random template
        return PromptTemplateLibrary.randomTemplate()
    }
    
    // MARK: - Content Moderation
    
    func hideResponse(_ responseId: String, reason: String) async -> Bool {
        guard isAdmin else { return false }
        
        do {
            try await db.collection("promptResponses").document(responseId).updateData([
                "isHidden": true,
                "moderationReason": reason,
                "moderatedAt": FieldValue.serverTimestamp(),
                "moderatedBy": Auth.auth().currentUser?.uid as Any
            ])
            
            return true
            
        } catch {
            handleError(error)
            return false
        }
    }
    
    func unhideResponse(_ responseId: String) async -> Bool {
        guard isAdmin else { return false }
        
        do {
            try await db.collection("promptResponses").document(responseId).updateData([
                "isHidden": false,
                "moderationReason": FieldValue.delete(),
                "moderatedAt": FieldValue.delete(),
                "moderatedBy": FieldValue.delete()
            ])
            
            return true
            
        } catch {
            handleError(error)
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
        
        print("❌ PromptAdminService Error: \(error)")
        AnalyticsService.shared.logError(error: error, context: "prompt_admin_service_error")
    }
    
    // MARK: - Computed Properties
    
    var activePrompt: DailyPrompt? {
        return allPrompts.first { $0.isActive && !$0.isArchived }
    }
    
    var upcomingPrompts: [DailyPrompt] {
        return scheduledPrompts.filter { $0.date > Date() }.sorted { $0.date < $1.date }
    }
    
    var recentPrompts: [DailyPrompt] {
        return allPrompts.filter { !$0.isActive && !$0.isArchived && $0.date <= Date() }
            .sorted { $0.date > $1.date }
            .prefix(10)
            .map { $0 }
    }
    
    var promptsByCategory: [PromptCategory: [DailyPrompt]] {
        return Dictionary(grouping: allPrompts) { $0.category }
    }
    
    var templatesByCategory: [PromptCategory: [PromptTemplate]] {
        return Dictionary(grouping: promptTemplates) { $0.category }
    }
}
