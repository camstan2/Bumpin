import Foundation

enum MockSocialData {
    static func trendingItems(count: Int, type: String) -> [TrendingItem] {
        let namesSongs = [
            ("Midnight Drive", "Astra"), ("Neon Lights", "Echo Wave"), ("Golden Hour", "Sundial"),
            ("Moonlit", "Kai Nova"), ("Afterglow", "Lumen"), ("Static Love", "Cinder"),
            ("Glass City", "Metroline"), ("Slow Burn", "Violet"), ("Daydream", "Atlas"),
            ("Horizon", "Northbound")
        ]
        let namesArtists = ["Astra", "Echo Wave", "Sundial", "Kai Nova", "Lumen", "Cinder", "Metroline", "Violet", "Atlas", "Northbound"]
        let namesAlbums = ["City Tapes", "Dusk Sessions", "Starlight", "Blueprints", "Reflections", "Low Tide", "Highrise", "Wildflower", "Skylines", "Sunsets"]

        var items: [TrendingItem] = []
        for i in 0..<max(1, count) {
            switch type {
            case "song":
                let pair = namesSongs[i % namesSongs.count]
                let logs = 5 + (i % 20)
                let rating = [nil, 3.5, 4.0, 4.5, 5.0][i % 5]
                items.append(TrendingItem(title: pair.0, subtitle: pair.1, artworkUrl: nil, logCount: logs, averageRating: rating, itemType: "song", itemId: "song_\(i)"))
            case "artist":
                let name = namesArtists[i % namesArtists.count]
                let logs = 3 + (i % 15)
                items.append(TrendingItem(title: name, subtitle: nil, artworkUrl: nil, logCount: logs, averageRating: nil, itemType: "artist", itemId: "artist_\(i)"))
            case "album":
                let title = namesAlbums[i % namesAlbums.count]
                let artist = namesArtists[(i+3) % namesArtists.count]
                let logs = 2 + (i % 12)
                let rating = [nil, 3.0, 3.5, 4.0, 4.5][i % 5]
                items.append(TrendingItem(title: title, subtitle: artist, artworkUrl: nil, logCount: logs, averageRating: rating, itemType: "album", itemId: "album_\(i)"))
            default:
                break
            }
        }
        return items
    }

    static func friendsActivity(count: Int) -> [FriendActivity] {
        let users = [
            ("u1", "alex"), ("u2", "sam"), ("u3", "jordan"), ("u4", "morgan"), ("u5", "riley"), ("u6", "casey")
        ]
        let songs = [
            ("Midnight Drive", "Astra"), ("Neon Lights", "Echo Wave"), ("Golden Hour", "Sundial"), ("Moonlit", "Kai Nova"), ("Afterglow", "Lumen")
        ]
        var out: [FriendActivity] = []
        for i in 0..<max(1, count) {
            let user = users[i % users.count]
            let song = songs[i % songs.count]
            let rating: Int? = [nil, 3, 4, 5][i % 4]
            out.append(FriendActivity(userId: user.0, username: user.1, userProfilePictureUrl: nil, songTitle: song.0, artistName: song.1, artworkUrl: nil, rating: rating, loggedAt: Date().addingTimeInterval(-Double(i) * 3600), musicLog: nil))
        }
        return out
    }

    // Genres tab: mock stories
    static func stories(for genre: String, count: Int = 6) -> [TrendingStory] {
        let baseTitles = [
            "Breakout buzz", "Underground heat", "Chart momentum", "Viral surge", "Critics' pick", "Fan favorite"
        ]
        let artists = ["Astra", "Echo Wave", "Sundial", "Kai Nova", "Lumen", "Cinder"]
        let now = Date()
        return (0..<count).map { i in
            TrendingStory(
                id: "story_\(genre)_\(i)",
                title: baseTitles[i % baseTitles.count],
                summary: "\(artists[i % artists.count]) is rising in \(genre.capitalized).",
                genre: genre,
                primaryArtist: artists[i % artists.count],
                createdAt: now.addingTimeInterval(-Double(i) * 3600),
                expiresAt: now.addingTimeInterval(12*3600)
            )
        }
    }

    // Explore tab: mock creators
    static func nowPlayingCreators(count: Int = 8) -> [UserProfile] {
        return (0..<count).map { i in
            UserProfile(
                uid: "creator_\(i)",
                email: "c\(i)@example.com",
                username: "creator\(i)",
                displayName: "Creator \(i)",
                createdAt: Date(),
                profilePictureUrl: nil,
                profileHeaderUrl: nil,
                bio: nil,
                followers: [],
                following: [],
                isVerified: i % 3 == 0,
                roles: ["creator"],
                reportCount: 0,
                violationCount: 0,
                locationSharingWith: nil,
                showNowPlaying: true,
                nowPlayingSong: "Track \(i)",
                nowPlayingArtist: ["Astra","Violet","Atlas","Lumen"][i % 4],
                nowPlayingAlbumArt: nil,
                nowPlayingUpdatedAt: Date(),
                pinnedSongs: nil,
                pinnedArtists: nil,
                pinnedAlbums: nil,
                pinnedLists: nil,
                pinnedSongsRanked: nil,
                pinnedArtistsRanked: nil,
                pinnedAlbumsRanked: nil,
                pinnedListsRanked: nil
            )
        }
    }

    static func creatorLogs(type: String, count: Int = 12) -> [MusicLog] {
        var logs: [MusicLog] = []
        let artists = ["Astra","Violet","Atlas","Lumen"]
        for i in 0..<count {
            let isArtist = (type == "artist")
            let itemType = isArtist ? "artist" : (type == "album" ? "album" : "song")
            let id = "log_\(type)_\(i)"
            let userId = "creator_\(i % 6)"
            let itemId = "item_\(i)"
            let title = isArtist ? artists[i % artists.count] : "Title \(i)"
            let artistName = artists[i % artists.count]
            let date = Date().addingTimeInterval(-Double(i) * 7200)
            let rating: Int? = [nil, 3, 4, 5][i % 4]
            let review: String? = (i % 3 == 0) ? "Loving this one." : nil
            let commentCount = i % 5
            let helpfulCount = 1 + (i % 7)
            let unhelpfulCount = 0
            let log = MusicLog(
                id: id,
                userId: userId,
                itemId: itemId,
                itemType: itemType,
                title: title,
                artistName: artistName,
                artworkUrl: nil,
                dateLogged: date,
                rating: rating,
                review: review,
                notes: nil,
                commentCount: commentCount,
                helpfulCount: helpfulCount,
                unhelpfulCount: unhelpfulCount,
                reviewPhotos: nil,
                isLiked: nil,
                thumbsUp: nil,
                thumbsDown: nil,
                isPublic: true
            )
            logs.append(log)
        }
        return logs
    }

    static func genreFriendsPopular(genre: String, count: Int = 12) -> [TrendingItem] {
        let base = trendingItems(count: count, type: "song")
        return base.enumerated().map { idx, item in
            TrendingItem(title: item.title, subtitle: item.subtitle, artworkUrl: item.artworkUrl, logCount: item.logCount + (idx % 4), averageRating: item.averageRating, itemType: item.itemType, itemId: "gfp_\(genre)_\(idx)")
        }
    }

    static func genreTrendingArtists(genre: String, count: Int = 12) -> [TrendingItem] {
        let artists = ["Astra", "Echo Wave", "Sundial", "Kai Nova", "Lumen", "Cinder", "Metroline", "Violet", "Atlas", "Northbound"]
        return (0..<count).map { i in
            TrendingItem(title: artists[i % artists.count], subtitle: nil, artworkUrl: nil, logCount: 2 + (i % 10), averageRating: nil, itemType: "artist", itemId: "gart_\(genre)_\(i)")
        }
    }

    static func genreTrendingAlbums(genre: String, count: Int = 12) -> [TrendingItem] {
        let albums = ["City Tapes", "Dusk Sessions", "Starlight", "Blueprints", "Reflections", "Low Tide", "Highrise", "Wildflower", "Skylines", "Sunsets"]
        let artists = ["Astra", "Echo Wave", "Sundial", "Kai Nova", "Lumen", "Cinder", "Metroline", "Violet", "Atlas", "Northbound"]
        return (0..<count).map { i in
            TrendingItem(title: albums[i % albums.count], subtitle: artists[(i+3) % artists.count], artworkUrl: nil, logCount: 2 + (i % 8), averageRating: [nil, 3.5, 4.0, 4.5][i % 4], itemType: "album", itemId: "galb_\(genre)_\(i)")
        }
    }
}


