import Foundation
import SwiftUI

// MARK: - Mock Data for Daily Prompts Demo

struct DailyPromptMockData {
    
    // MARK: - Mock Prompt
    static let mockPrompt = DailyPrompt(
        title: "First song you play on vacation",
        description: "That perfect song that kicks off your getaway mood - the moment you know you're officially on vacation!",
        category: .activity,
        createdBy: "admin_user",
        expiresAt: Date().addingTimeInterval(3600 * 18) // 18 hours from now
    ).applying {
        $0.isActive = true
        $0.totalResponses = 47
        $0.featuredSongs = ["good4u", "blinding_lights", "levitating", "watermelon_sugar"]
    }
    
    // MARK: - Mock User Responses
    static let mockResponses: [PromptResponse] = [
        PromptResponse(
            promptId: mockPrompt.id,
            userId: "user_sarah",
            username: "SarahVibes",
            userProfilePictureUrl: "https://example.com/sarah.jpg",
            songId: "good4u",
            songTitle: "good 4 u",
            artistName: "Olivia Rodrigo",
            albumName: "SOUR",
            artworkUrl: "https://example.com/sour_artwork.jpg",
            appleMusicUrl: "https://music.apple.com/song/good4u",
            explanation: "This song is pure vacation energy! The moment it comes on, I know I'm ready to leave all my stress behind and just have fun. Perfect for that first day feeling! ✈️",
            isPublic: true
        ).applying {
            $0.likeCount = 23
            $0.commentCount = 8
        },
        
        PromptResponse(
            promptId: mockPrompt.id,
            userId: "user_mike",
            username: "MikeMelodies",
            userProfilePictureUrl: "https://example.com/mike.jpg",
            songId: "blinding_lights",
            songTitle: "Blinding Lights",
            artistName: "The Weeknd",
            albumName: "After Hours",
            artworkUrl: "https://example.com/after_hours.jpg",
            appleMusicUrl: "https://music.apple.com/song/blinding_lights",
            explanation: "Nothing says 'vacation mode activated' like this synth-pop masterpiece. It's got that nostalgic 80s vibe that makes everything feel like a movie montage!",
            isPublic: true
        ).applying {
            $0.likeCount = 19
            $0.commentCount = 5
        },
        
        PromptResponse(
            promptId: mockPrompt.id,
            userId: "user_alex",
            username: "AlexAdventures",
            userProfilePictureUrl: "https://example.com/alex.jpg",
            songId: "levitating",
            songTitle: "Levitating",
            artistName: "Dua Lipa",
            albumName: "Future Nostalgia",
            artworkUrl: "https://example.com/future_nostalgia.jpg",
            appleMusicUrl: "https://music.apple.com/song/levitating",
            explanation: "This song literally makes me feel like I'm floating! Perfect for that weightless vacation feeling when all your worries just disappear.",
            isPublic: true
        ).applying {
            $0.likeCount = 31
            $0.commentCount = 12
        },
        
        PromptResponse(
            promptId: mockPrompt.id,
            userId: "user_emma",
            username: "EmmaEscapes",
            userProfilePictureUrl: "https://example.com/emma.jpg",
            songId: "watermelon_sugar",
            songTitle: "Watermelon Sugar",
            artistName: "Harry Styles",
            albumName: "Fine Line",
            artworkUrl: "https://example.com/fine_line.jpg",
            appleMusicUrl: "https://music.apple.com/song/watermelon_sugar",
            explanation: "Summer vibes all year round! This song instantly transports me to a sunny beach no matter where I am. Pure vacation magic! 🍉☀️",
            isPublic: true
        ).applying {
            $0.likeCount = 27
            $0.commentCount = 9
        },
        
        PromptResponse(
            promptId: mockPrompt.id,
            userId: "user_jordan",
            username: "JordanJams",
            userProfilePictureUrl: "https://example.com/jordan.jpg",
            songId: "sunflower",
            songTitle: "Sunflower",
            artistName: "Post Malone, Swae Lee",
            albumName: "Spider-Man: Into the Spider-Verse",
            artworkUrl: "https://example.com/spiderverse.jpg",
            appleMusicUrl: "https://music.apple.com/song/sunflower",
            explanation: "This song just makes me smile instantly! It's got that carefree, happy energy that's perfect for starting any adventure.",
            isPublic: true
        ).applying {
            $0.likeCount = 15
            $0.commentCount = 4
        },
        
        PromptResponse(
            promptId: mockPrompt.id,
            userId: "user_taylor",
            username: "TaylorTunes",
            userProfilePictureUrl: "https://example.com/taylor.jpg",
            songId: "as_it_was",
            songTitle: "As It Was",
            artistName: "Harry Styles",
            albumName: "Harry's House",
            artworkUrl: "https://example.com/harrys_house.jpg",
            appleMusicUrl: "https://music.apple.com/song/as_it_was",
            explanation: "There's something so nostalgic and freeing about this song. It perfectly captures that feeling of leaving everything behind and just being present.",
            isPublic: true
        ).applying {
            $0.likeCount = 22
            $0.commentCount = 7
        }
    ]
    
    // MARK: - Mock Leaderboard
    static let mockLeaderboard = PromptLeaderboard(
        promptId: mockPrompt.id,
        songRankings: [
            SongRanking(
                songId: "levitating",
                songTitle: "Levitating",
                artistName: "Dua Lipa",
                albumName: "Future Nostalgia",
                artworkUrl: "https://example.com/future_nostalgia.jpg",
                appleMusicUrl: "https://music.apple.com/song/levitating",
                voteCount: 8,
                sampleUsers: [
                    ResponseUser(userId: "user_alex", username: "AlexAdventures", explanation: "Makes me feel like I'm floating!"),
                    ResponseUser(userId: "user_maya", username: "MayaMusic", explanation: "Ultimate vacation anthem"),
                    ResponseUser(userId: "user_chris", username: "ChrisChords", explanation: "Can't help but dance to this")
                ]
            ).applying {
                $0.percentage = 17.0
                $0.rank = 1
            },
            
            SongRanking(
                songId: "good4u",
                songTitle: "good 4 u",
                artistName: "Olivia Rodrigo",
                albumName: "SOUR",
                artworkUrl: "https://example.com/sour_artwork.jpg",
                appleMusicUrl: "https://music.apple.com/song/good4u",
                voteCount: 7,
                sampleUsers: [
                    ResponseUser(userId: "user_sarah", username: "SarahVibes", explanation: "Pure vacation energy!"),
                    ResponseUser(userId: "user_kai", username: "KaiKicks", explanation: "Gets me hyped instantly"),
                    ResponseUser(userId: "user_zoe", username: "ZoeZones", explanation: "Perfect mood booster")
                ]
            ).applying {
                $0.percentage = 14.9
                $0.rank = 2
            },
            
            SongRanking(
                songId: "watermelon_sugar",
                songTitle: "Watermelon Sugar",
                artistName: "Harry Styles",
                albumName: "Fine Line",
                artworkUrl: "https://example.com/fine_line.jpg",
                appleMusicUrl: "https://music.apple.com/song/watermelon_sugar",
                voteCount: 6,
                sampleUsers: [
                    ResponseUser(userId: "user_emma", username: "EmmaEscapes", explanation: "Summer vibes all year!"),
                    ResponseUser(userId: "user_ryan", username: "RyanRhythms", explanation: "Instant beach mood"),
                    ResponseUser(userId: "user_lily", username: "LilyLyrics", explanation: "Makes me feel free")
                ]
            ).applying {
                $0.percentage = 12.8
                $0.rank = 3
            },
            
            SongRanking(
                songId: "blinding_lights",
                songTitle: "Blinding Lights",
                artistName: "The Weeknd",
                albumName: "After Hours",
                artworkUrl: "https://example.com/after_hours.jpg",
                appleMusicUrl: "https://music.apple.com/song/blinding_lights",
                voteCount: 5,
                sampleUsers: [
                    ResponseUser(userId: "user_mike", username: "MikeMelodies", explanation: "80s synth perfection"),
                    ResponseUser(userId: "user_sofia", username: "SofiaSound", explanation: "Movie montage vibes")
                ]
            ).applying {
                $0.percentage = 10.6
                $0.rank = 4
            },
            
            SongRanking(
                songId: "as_it_was",
                songTitle: "As It Was",
                artistName: "Harry Styles",
                albumName: "Harry's House",
                artworkUrl: "https://example.com/harrys_house.jpg",
                appleMusicUrl: "https://music.apple.com/song/as_it_was",
                voteCount: 4,
                sampleUsers: [
                    ResponseUser(userId: "user_taylor", username: "TaylorTunes", explanation: "Nostalgic and freeing"),
                    ResponseUser(userId: "user_sam", username: "SamSounds", explanation: "Perfect road trip song")
                ]
            ).applying {
                $0.percentage = 8.5
                $0.rank = 5
            }
        ],
        totalResponses: 47
    )
    
    // MARK: - Mock User Stats
    static let mockUserStats = UserPromptStats(userId: "current_user").applying {
        $0.currentStreak = 7
        $0.longestStreak = 12
        $0.totalResponses = 23
        $0.lastResponseDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        $0.favoriteCategories = [
            .activity: 8,
            .mood: 6,
            .nostalgia: 5,
            .social: 4
        ]
        $0.totalLikesReceived = 156
        $0.totalCommentsReceived = 43
        $0.averageResponseTime = 127.5 // About 2 minutes
    }
    
    // MARK: - Mock Comments
    static let mockComments: [String: [PromptResponseComment]] = [
        "levitating_response": [
            PromptResponseComment(
                responseId: "levitating_response",
                promptId: mockPrompt.id,
                userId: "user_maya",
                username: "MayaMusic",
                userProfilePictureUrl: "https://example.com/maya.jpg",
                text: "YES! This song is the ultimate vacation anthem! 🎵"
            ),
            PromptResponseComment(
                responseId: "levitating_response",
                promptId: mockPrompt.id,
                userId: "user_chris",
                username: "ChrisChords",
                userProfilePictureUrl: "https://example.com/chris.jpg",
                text: "Perfect choice! This song never fails to put me in a good mood"
            ),
            PromptResponseComment(
                responseId: "levitating_response",
                promptId: mockPrompt.id,
                userId: "user_jordan",
                username: "JordanJams",
                userProfilePictureUrl: "https://example.com/jordan.jpg",
                text: "Adding this to my vacation playlist right now! 🌴"
            )
        ],
        
        "good4u_response": [
            PromptResponseComment(
                responseId: "good4u_response",
                promptId: mockPrompt.id,
                userId: "user_kai",
                username: "KaiKicks",
                userProfilePictureUrl: "https://example.com/kai.jpg",
                text: "Olivia Rodrigo knows how to capture emotions perfectly!"
            ),
            PromptResponseComment(
                responseId: "good4u_response",
                promptId: mockPrompt.id,
                userId: "user_zoe",
                username: "ZoeZones",
                userProfilePictureUrl: "https://example.com/zoe.jpg",
                text: "This song gets me so pumped! Great vacation starter 🔥"
            )
        ]
    ]
    
    // MARK: - Mock Likes
    static let mockLikes: [String: [PromptResponseLike]] = [
        "levitating_response": [
            PromptResponseLike(responseId: "levitating_response", promptId: mockPrompt.id, userId: "user_maya", username: "MayaMusic"),
            PromptResponseLike(responseId: "levitating_response", promptId: mockPrompt.id, userId: "user_chris", username: "ChrisChords"),
            PromptResponseLike(responseId: "levitating_response", promptId: mockPrompt.id, userId: "user_jordan", username: "JordanJams"),
            PromptResponseLike(responseId: "levitating_response", promptId: mockPrompt.id, userId: "user_kai", username: "KaiKicks"),
            PromptResponseLike(responseId: "levitating_response", promptId: mockPrompt.id, userId: "user_zoe", username: "ZoeZones")
        ],
        
        "good4u_response": [
            PromptResponseLike(responseId: "good4u_response", promptId: mockPrompt.id, userId: "user_alex", username: "AlexAdventures"),
            PromptResponseLike(responseId: "good4u_response", promptId: mockPrompt.id, userId: "user_taylor", username: "TaylorTunes"),
            PromptResponseLike(responseId: "good4u_response", promptId: mockPrompt.id, userId: "user_emma", username: "EmmaEscapes")
        ]
    ]
    
    // MARK: - Mock Coordinator with Data
    @MainActor
    static func createMockCoordinator(userHasResponded: Bool = false) -> DailyPromptCoordinator {
        let coordinator = DailyPromptCoordinator()
        
        // Set up mock prompt data directly (for preview/demo purposes)
        configureMockData(for: coordinator, userHasResponded: userHasResponded)
        
        return coordinator
    }
    
    // MARK: - Configure Mock Data for Coordinator
    @MainActor
    static func configureMockData(for coordinator: DailyPromptCoordinator, userHasResponded: Bool = false) {
        // Set up mock prompt
        coordinator.promptService.currentPrompt = mockPrompt
        coordinator.promptService.promptLeaderboard = mockLeaderboard
        coordinator.promptService.userPromptStats = mockUserStats
        
        // Set user response if specified
        if userHasResponded {
            coordinator.promptService.userResponse = PromptResponse(
                promptId: mockPrompt.id,
                userId: "current_user",
                username: "You",
                userProfilePictureUrl: nil,
                songId: "vacation_song",
                songTitle: "Vacation",
                artistName: "Dirty Heads",
                albumName: "Sound of Change",
                artworkUrl: "https://example.com/vacation_artwork.jpg",
                explanation: "This song literally has 'vacation' in the title and it perfectly captures that laid-back, carefree feeling I want when I'm getting away from it all!",
                isPublic: true
            )
        }
        
        // Set up mock interaction data
        coordinator.interactionService.responseLikes = mockLikes
        coordinator.interactionService.responseComments = mockComments
        coordinator.interactionService.userLikedResponses = userHasResponded ? ["levitating_response"] : []
    }
    
    // MARK: - Additional Mock Data
    static let mockPromptHistory: [DailyPrompt] = [
        DailyPrompt(
            title: "Song that instantly cheers you up",
            description: "Your guaranteed mood booster",
            category: .mood,
            createdBy: "admin_user",
            expiresAt: Date().addingTimeInterval(-3600 * 24) // Yesterday
        ).applying {
            $0.date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            $0.isActive = false
            $0.totalResponses = 73
        },
        
        DailyPrompt(
            title: "Perfect rainy day song",
            description: "What matches the sound of raindrops?",
            category: .mood,
            createdBy: "admin_user",
            expiresAt: Date().addingTimeInterval(-3600 * 48) // 2 days ago
        ).applying {
            $0.date = Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
            $0.isActive = false
            $0.totalResponses = 91
        },
        
        DailyPrompt(
            title: "Best song to sing with friends",
            description: "The ultimate group singalong anthem",
            category: .social,
            createdBy: "admin_user",
            expiresAt: Date().addingTimeInterval(-3600 * 72) // 3 days ago
        ).applying {
            $0.date = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
            $0.isActive = false
            $0.totalResponses = 126
        }
    ]
}

// MARK: - Helper Extension for Mock Data

extension DailyPrompt {
    func applying(_ modifier: (inout DailyPrompt) -> Void) -> DailyPrompt {
        var copy = self
        modifier(&copy)
        return copy
    }
}

extension PromptResponse {
    func applying(_ modifier: (inout PromptResponse) -> Void) -> PromptResponse {
        var copy = self
        modifier(&copy)
        return copy
    }
}

extension SongRanking {
    func applying(_ modifier: (inout SongRanking) -> Void) -> SongRanking {
        var copy = self
        modifier(&copy)
        return copy
    }
}

extension UserPromptStats {
    func applying(_ modifier: (inout UserPromptStats) -> Void) -> UserPromptStats {
        var copy = self
        modifier(&copy)
        return copy
    }
}
