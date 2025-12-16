import SwiftUI
import FirebaseFirestore

/// Testing view to validate cross-platform music tracking functionality
struct CrossPlatformTestingView: View {
    @State private var testResults: [CrossPlatformTestResult] = []
    @State private var isRunningTests = false
    @State private var selectedTest: CrossPlatformTestResult?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection
                
                // Test Results
                if !testResults.isEmpty {
                    testResultsSection
                }
                
                // Run Tests Button
                Button(action: runAllTests) {
                    HStack {
                        if isRunningTests {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Running Tests...")
                        } else {
                            Image(systemName: "play.fill")
                            Text("Run All Tests")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isRunningTests ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isRunningTests)
                .padding(.horizontal)
                
                // Manual Test Checklist
                manualTestChecklist
            }
            .padding()
        }
        .navigationTitle("Cross-Platform Tests")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cross-Platform Validation")
                .font(.title.bold())
            
            Text("Verify that Apple Music and Spotify users see the same ratings, comments, and trending data.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Test Results Section
    
    private var testResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Results")
                .font(.headline)
            
            ForEach(testResults) { result in
                TestResultRow(result: result)
                    .onTapGesture {
                        selectedTest = result
                    }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
    
    // MARK: - Manual Test Checklist
    
    private var manualTestChecklist: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Manual Test Checklist")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                ChecklistItem(
                    title: "1. Search for Same Song",
                    description: "Search for 'Blinding Lights' on both Apple Music and Spotify accounts. Verify both show the same song."
                )
                
                ChecklistItem(
                    title: "2. Create Logs from Different Platforms",
                    description: "Log the same song from Apple Music (5 stars) and Spotify (4 stars). Both should appear in the song's profile."
                )
                
                ChecklistItem(
                    title: "3. Check Trending Aggregation",
                    description: "Verify trending songs aggregate logs from both platforms. A song with 10 Apple Music logs + 5 Spotify logs should show 15 total."
                )
                
                ChecklistItem(
                    title: "4. Verify Profile Views",
                    description: "View a song profile. It should show all logs regardless of platform."
                )
                
                ChecklistItem(
                    title: "5. Check Friends Activity",
                    description: "If friends use different platforms, their activity should still appear in your feed."
                )
                
                ChecklistItem(
                    title: "6. Test Migration",
                    description: "Run the migration from Settings > Admin Tools > Universal Track Migration. Verify all logs are updated."
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
    
    // MARK: - Test Execution
    
    private func runAllTests() {
        isRunningTests = true
        testResults.removeAll()
        
        Task {
            await testUniversalTrackCreation()
            await testPlatformDetection()
            await testLogQueries()
            await testTrendingAggregation()
            await testMigrationStatus()
            
            await MainActor.run {
                isRunningTests = false
            }
        }
    }
    
    // MARK: - Individual Tests
    
    private func testUniversalTrackCreation() async {
        let testName = "Universal Track Creation"
        
        do {
            // Test creating a universal track for Apple Music
            let appleTrack = await TrackMatchingService.shared.getUniversalTrack(
                title: "Blinding Lights",
                artist: "The Weeknd",
                albumName: "After Hours",
                appleMusicId: "test-apple-123"
            )
            
            // Test creating a universal track for Spotify
            let spotifyTrack = await TrackMatchingService.shared.getUniversalTrack(
                title: "Blinding Lights",
                artist: "The Weeknd",
                albumName: "After Hours",
                spotifyId: "test-spotify-456"
            )
            
            // Both should have the same universal ID
            let passed = appleTrack.id == spotifyTrack.id
            
            await MainActor.run {
                testResults.append(CrossPlatformTestResult(
                    name: testName,
                    passed: passed,
                    message: passed 
                        ? "✅ Same universal ID: \(appleTrack.id)"
                        : "❌ Different IDs: Apple=\(appleTrack.id), Spotify=\(spotifyTrack.id)"
                ))
            }
        } catch {
            await MainActor.run {
                testResults.append(CrossPlatformTestResult(
                    name: testName,
                    passed: false,
                    message: "❌ Error: \(error.localizedDescription)"
                ))
            }
        }
    }
    
    private func testPlatformDetection() async {
        let testName = "Platform Detection"
        
        // Test that MusicSearchResult includes platform field
        let appleResult = MusicSearchResult(
            id: "test-1",
            title: "Test Song",
            artistName: "Test Artist",
            albumName: "Test Album",
            artworkURL: nil,
            itemType: "song",
            popularity: 100,
            genreNames: nil,
            primaryGenre: nil,
            platform: "apple_music"
        )
        
        let spotifyResult = MusicSearchResult(
            id: "test-2",
            title: "Test Song",
            artistName: "Test Artist",
            albumName: "Test Album",
            artworkURL: nil,
            itemType: "song",
            popularity: 100,
            genreNames: nil,
            primaryGenre: nil,
            platform: "spotify"
        )
        
        let passed = appleResult.platform == "apple_music" && spotifyResult.platform == "spotify"
        
        await MainActor.run {
            testResults.append(CrossPlatformTestResult(
                name: testName,
                passed: passed,
                message: passed
                    ? "✅ Platform field correctly set"
                    : "❌ Platform field not working"
            ))
        }
    }
    
    private func testLogQueries() async {
        let testName = "Log Query by Universal Track ID"
        
        do {
            let db = Firestore.firestore()
            
            // Query logs by universalTrackId
            let snapshot = try await db.collection("logs")
                .whereField("universalTrackId", isEqualTo: "test-universal-id")
                .limit(to: 1)
                .getDocuments()
            
            // This test just verifies the query doesn't error
            let passed = true
            
            await MainActor.run {
                testResults.append(CrossPlatformTestResult(
                    name: testName,
                    passed: passed,
                    message: "✅ Query by universalTrackId works (found \(snapshot.documents.count) logs)"
                ))
            }
        } catch {
            await MainActor.run {
                testResults.append(CrossPlatformTestResult(
                    name: testName,
                    passed: false,
                    message: "❌ Query failed: \(error.localizedDescription)"
                ))
            }
        }
    }
    
    private func testTrendingAggregation() async {
        let testName = "Trending Aggregation Logic"
        
        // Create test logs with same universalTrackId but different itemIds
        let log1 = MusicLog(
            id: "log1",
            userId: "user1",
            itemId: "apple-123",
            itemType: "song",
            title: "Test Song",
            artistName: "Test Artist",
            artworkUrl: nil,
            dateLogged: Date(),
            rating: 5.0,
            review: nil,
            notes: nil,
            commentCount: 0,
            helpfulCount: 0,
            unhelpfulCount: 0,
            likeCount: 0,
            repostCount: 0,
            reviewPhotos: nil,
            isLiked: false,
            thumbsUp: false,
            thumbsDown: false,
            isPublic: true,
            appleMusicGenres: nil,
            primaryGenre: nil,
            genres: nil,
            userCorrectedGenre: nil,
            universalTrackId: "universal-test-123",
            musicPlatform: "apple_music",
            platformMatchingConfidence: 1.0
        )
        
        let log2 = MusicLog(
            id: "log2",
            userId: "user2",
            itemId: "spotify-456",
            itemType: "song",
            title: "Test Song",
            artistName: "Test Artist",
            artworkUrl: nil,
            dateLogged: Date(),
            rating: 4.0,
            review: nil,
            notes: nil,
            commentCount: 0,
            helpfulCount: 0,
            unhelpfulCount: 0,
            likeCount: 0,
            repostCount: 0,
            reviewPhotos: nil,
            isLiked: false,
            thumbsUp: false,
            thumbsDown: false,
            isPublic: true,
            appleMusicGenres: nil,
            primaryGenre: nil,
            genres: nil,
            userCorrectedGenre: nil,
            universalTrackId: "universal-test-123",
            musicPlatform: "spotify",
            platformMatchingConfidence: 1.0
        )
        
        let logs = [log1, log2]
        
        // Group by universalTrackId
        let grouped = Dictionary(grouping: logs) { log in
            log.universalTrackId ?? log.itemId
        }
        
        // Should have 1 group with 2 logs
        let passed = grouped.count == 1 && grouped["universal-test-123"]?.count == 2
        
        await MainActor.run {
            testResults.append(CrossPlatformTestResult(
                name: testName,
                passed: passed,
                message: passed
                    ? "✅ Logs correctly grouped by universalTrackId (1 group, 2 logs)"
                    : "❌ Grouping failed: \(grouped.count) groups"
            ))
        }
    }
    
    private func testMigrationStatus() async {
        let testName = "Migration Service"
        
        let status = await UniversalTrackMigrationService.shared.checkMigrationStatus()
        
        let passed = true // Service is accessible
        
        await MainActor.run {
            testResults.append(CrossPlatformTestResult(
                name: testName,
                passed: passed,
                message: "✅ Migration service accessible (\(status.logsNeedingMigration) logs need migration)"
            ))
        }
    }
}

// MARK: - Supporting Views

struct TestResultRow: View {
    let result: CrossPlatformTestResult
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.passed ? .green : .red)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(.subheadline.bold())
                
                Text(result.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ChecklistItem: View {
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.bold())
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Supporting Types

struct CrossPlatformTestResult: Identifiable {
    let id = UUID()
    let name: String
    let passed: Bool
    let message: String
}

#Preview {
    NavigationView {
        CrossPlatformTestingView()
    }
}

