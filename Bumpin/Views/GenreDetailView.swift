import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct GenreDetailView: View {
    let genre: String
    let userLogs: [MusicLog]
    @Environment(\.presentationMode) var presentationMode
    @State private var diaryViewFormat: DiaryViewFormat = .list
    @State private var diarySortOption: DiarySortOption = .mostRecent
    @State private var logToEdit: MusicLog? = nil
    @State private var logToDelete: MusicLog? = nil
    @State private var showDeleteConfirmation = false
    @State private var logToCorrectGenre: MusicLog? = nil
    @State private var showGenreCorrection = false
    @State private var selectedMusicItem: MusicSearchResult? = nil
    @State private var selectedPinnedLog: MusicLog? = nil
    
    // Filter logs for this specific genre (using same logic as main view)
    private var genreLogs: [MusicLog] {
        return userLogs.filter { log in
            // Use the same classification logic as the main overview
            let logGenre = classifyGenre(title: log.title, artist: log.artistName)
            let matches = logGenre == genre
            print("🎯 GenreDetailView: \(log.title) classified as \(logGenre), matches \(genre): \(matches)")
            return matches
        }
    }
    
    // Sorted logs based on selected sort option
    private var sortedLogs: [MusicLog] {
        return genreLogs.sorted { log1, log2 in
            switch diarySortOption {
            case .mostRecent:
                return log1.dateLogged > log2.dateLogged
            case .oldest:
                return log1.dateLogged < log2.dateLogged
            case .alphabetical:
                return log1.title.localizedCaseInsensitiveCompare(log2.title) == .orderedAscending
            case .highestRated:
                let rating1 = log1.rating ?? 0
                let rating2 = log2.rating ?? 0
                if rating1 == rating2 {
                    return log1.dateLogged > log2.dateLogged
                }
                return rating1 > rating2
            case .mostPopular:
                let rating1 = log1.rating ?? 0
                let rating2 = log2.rating ?? 0
                if rating1 == rating2 {
                    return log1.dateLogged > log2.dateLogged
                }
                return rating1 > rating2
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Genre Header
                VStack(spacing: 16) {
                    // Genre icon and title
                    HStack {
                        Circle()
                            .fill(genreColor(for: genre))
                            .frame(width: 24, height: 24)
                            .shadow(color: genreColor(for: genre).opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        Text(genre)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Spacer()
                    }
                    
                    // Stats
                    HStack {
                        Text("\(genreLogs.count) \(genreLogs.count == 1 ? "log" : "logs")")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if !genreLogs.isEmpty {
                            let avgRating = genreLogs.compactMap { $0.rating }.reduce(0, +) / max(1, genreLogs.compactMap { $0.rating }.count)
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= avgRating ? "star.fill" : "star")
                                        .font(.caption)
                                        .foregroundColor(star <= avgRating ? .yellow : .gray)
                                }
                            }
                            Text("Avg Rating")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                // Toggle Controls (same as diary)
                if !genreLogs.isEmpty {
                    GenreDetailControls(
                        viewFormat: $diaryViewFormat,
                        sortOption: $diarySortOption
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
                
                // Content
                if genreLogs.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "music.note")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No \(genre.lowercased()) logs yet.")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Your \(genre.lowercased()) logs will appear here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ScrollView {
                        if diaryViewFormat == .list {
                            LazyVStack(spacing: 12) {
                                ForEach(sortedLogs) { log in
                                    GenreDetailLogCard(
                                        log: log,
                                        onTap: {
                                            navigateToMusicProfile(log: log)
                                        },
                                        onEdit: {
                                            logToEdit = log
                                        },
                                        onDelete: {
                                            logToDelete = log
                                            showDeleteConfirmation = true
                                        },
                                        onCorrectGenre: {
                                            logToCorrectGenre = log
                                            showGenreCorrection = true
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 12) {
                                ForEach(sortedLogs) { log in
                                    GenreDetailGridCard(
                                        log: log,
                                        onTap: {
                                            navigateToMusicProfile(log: log)
                                        },
                                        onEdit: {
                                            logToEdit = log
                                        },
                                        onDelete: {
                                            logToDelete = log
                                            showDeleteConfirmation = true
                                        },
                                        onCorrectGenre: {
                                            logToCorrectGenre = log
                                            showGenreCorrection = true
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .refreshable {
                        // Refresh could be implemented to reload user data
                    }
                }
            }
            .navigationTitle("\(genre) Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .sheet(item: $logToEdit) { log in
            EditLogView(log: log) {
                // Refresh would need to be handled by parent
            }
        }
        .sheet(isPresented: $showGenreCorrection, onDismiss: { logToCorrectGenre = nil }) {
            if let log = logToCorrectGenre {
                GenreCorrectionView(log: log) {
                    // Refresh would need to be handled by parent
                }
            }
        }
        .fullScreenCover(item: $selectedMusicItem) { musicItem in
            MusicProfileView(musicItem: musicItem, pinnedLog: selectedPinnedLog)
        }
        .alert("Delete Log", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                logToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let log = logToDelete {
                    deleteLog(log)
                }
                logToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this log? This action cannot be undone.")
        }
    }
    
    // Helper functions (copied from UserProfileView)
    private func navigateToMusicProfile(log: MusicLog) {
        selectedPinnedLog = log
        selectedMusicItem = MusicSearchResult(
            id: log.itemId,
            title: log.title,
            artistName: log.artistName,
            albumName: "",
            artworkURL: log.artworkUrl,
            itemType: log.itemType,
            popularity: 0
        )
    }
    
    private func deleteLog(_ log: MusicLog) {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              log.userId == currentUserId else {
            print("❌ Cannot delete log: Not authorized")
            return
        }
        
        let db = Firestore.firestore()
        db.collection("logs").document(log.id).delete { error in
            if let error = error {
                print("❌ Error deleting log: \(error.localizedDescription)")
            } else {
                print("✅ Successfully deleted log")
            }
        }
    }
    
    // Genre classification functions (simplified versions)
    private func mapAppleMusicGenre(_ appleMusicGenre: String) -> String {
        let genre = appleMusicGenre.lowercased()
        
        switch genre {
        case let g where g.contains("hip hop") || g.contains("hip-hop") || g.contains("rap") || 
                        g.contains("trap") || g.contains("drill") || g.contains("grime"):
            return "Hip-Hop"
        case let g where g.contains("pop") && !g.contains("k-pop") && !g.contains("latin pop"):
            return "Pop"
        case let g where g.contains("r&b") || g.contains("rnb") || g.contains("soul") || 
                        g.contains("rhythm") || g.contains("contemporary r&b"):
            return "R&B"
        case let g where g.contains("electronic") || g.contains("edm") || g.contains("house") ||
                        g.contains("techno") || g.contains("trance") || g.contains("dubstep"):
            return "Electronic"
        case let g where g.contains("rock") && !g.contains("country rock") || g.contains("metal") ||
                        g.contains("punk") || g.contains("grunge") || g.contains("hardcore"):
            return "Rock"
        case let g where g.contains("indie") || g.contains("alternative") || g.contains("lo-fi"):
            return "Indie"
        case let g where g.contains("country") || g.contains("folk") || g.contains("bluegrass"):
            return "Country"
        case let g where g.contains("k-pop") || g.contains("korean") || g.contains("j-pop"):
            return "K-Pop"
        case let g where g.contains("latin") || g.contains("reggaeton") || g.contains("salsa"):
            return "Latin"
        case let g where g.contains("jazz") || g.contains("swing") || g.contains("bebop"):
            return "Jazz"
        default:
            return "Other"
        }
    }
    
    private func classifyGenre(title: String, artist: String) -> String {
        // Use the EXACT same classification logic as UserProfileView
        let artistLower = artist.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let titleLower = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let combinedText = "\(titleLower) \(artistLower)"
        
        // EXACT same artist database as UserProfileView
        let artistGenreMap: [String: String] = [
            // Hip-Hop Artists (Major Artists)
            "drake": "Hip-Hop", "kendrick lamar": "Hip-Hop", "travis scott": "Hip-Hop", "kanye west": "Hip-Hop",
            "tyler the creator": "Hip-Hop", "asap rocky": "Hip-Hop", "j cole": "Hip-Hop", "future": "Hip-Hop",
            "lil baby": "Hip-Hop", "lil wayne": "Hip-Hop", "eminem": "Hip-Hop", "jay-z": "Hip-Hop",
            "nas": "Hip-Hop", "biggie": "Hip-Hop", "tupac": "Hip-Hop", "snoop dogg": "Hip-Hop",
            "dr dre": "Hip-Hop", "50 cent": "Hip-Hop", "nicki minaj": "Hip-Hop", "cardi b": "Hip-Hop",
            "megan thee stallion": "Hip-Hop", "doja cat": "Hip-Hop", "ice spice": "Hip-Hop", "lil uzi vert": "Hip-Hop",
            "playboi carti": "Hip-Hop", "21 savage": "Hip-Hop", "metro boomin": "Hip-Hop", "gunna": "Hip-Hop",
            "young thug": "Hip-Hop", "roddy ricch": "Hip-Hop", "dababy": "Hip-Hop", "polo g": "Hip-Hop",
            "lil durk": "Hip-Hop", "pop smoke": "Hip-Hop", "juice wrld": "Hip-Hop", "xxxtentacion": "Hip-Hop",
            "ski mask the slump god": "Hip-Hop", "denzel curry": "Hip-Hop", "jid": "Hip-Hop", "earthgang": "Hip-Hop",
            "trippie redd": "Hip-Hop", "lil nas x": "Hip-Hop", "migos": "Hip-Hop", "offset": "Hip-Hop",
            "quavo": "Hip-Hop", "takeoff": "Hip-Hop", "rae sremmurd": "Hip-Hop", "swae lee": "Hip-Hop",
            
            // Pop Artists
            "taylor swift": "Pop", "ariana grande": "Pop", "billie eilish": "Pop", "dua lipa": "Pop",
            "olivia rodrigo": "Pop", "harry styles": "Pop", "ed sheeran": "Pop", "justin bieber": "Pop",
            "selena gomez": "Pop", "miley cyrus": "Pop", "katy perry": "Pop", "lady gaga": "Pop",
            "britney spears": "Pop", "madonna": "Pop", "beyonce": "Pop", "rihanna": "Pop",
            "adele": "Pop", "sam smith": "Pop", "charlie puth": "Pop", "shawn mendes": "Pop",
            "camila cabello": "Pop", "halsey": "Pop", "lorde": "Pop", "troye sivan": "Pop",
            "demi lovato": "Pop", "jonas brothers": "Pop", "maroon 5": "Pop", "onerepublic": "Pop",
            "imagine dragons": "Pop", "coldplay": "Pop", "the chainsmokers": "Pop", "zedd": "Pop",
            "bruno mars": "Pop", "post malone": "Pop", "lizzo": "Pop", "sia": "Pop",
            
            // R&B Artists
            "sza": "R&B", "frank ocean": "R&B", "the weeknd": "R&B", "bryson tiller": "R&B",
            "summer walker": "R&B", "jhene aiko": "R&B", "kehlani": "R&B", "h.e.r.": "R&B",
            "daniel caesar": "R&B", "brent faiyaz": "R&B", "kali uchis": "R&B", "solange": "R&B",
            "alicia keys": "R&B", "usher": "R&B", "chris brown": "R&B", "trey songz": "R&B",
            "miguel": "R&B", "john legend": "R&B", "maxwell": "R&B", "d'angelo": "R&B",
            "erykah badu": "R&B", "lauryn hill": "R&B", "mary j blige": "R&B", "whitney houston": "R&B",
            "mariah carey": "R&B", "janet jackson": "R&B", "prince": "R&B", "stevie wonder": "R&B",
            "anderson .paak": "R&B", "silk sonic": "R&B", "lucky daye": "R&B", "giveon": "R&B",
            
            // Electronic Artists
            "calvin harris": "Electronic", "deadmau5": "Electronic", "skrillex": "Electronic", "diplo": "Electronic",
            "martin garrix": "Electronic", "david guetta": "Electronic", "tiesto": "Electronic", "avicii": "Electronic",
            "swedish house mafia": "Electronic", "disclosure": "Electronic", "flume": "Electronic", "odesza": "Electronic",
            "porter robinson": "Electronic", "madeon": "Electronic", "rezz": "Electronic", "illenium": "Electronic",
            "marshmello": "Electronic", "alan walker": "Electronic", "daft punk": "Electronic", "justice": "Electronic",
            "aphex twin": "Electronic", "boards of canada": "Electronic", "burial": "Electronic", "four tet": "Electronic",
            
            // Rock Artists
            "foo fighters": "Rock", "red hot chili peppers": "Rock", "nirvana": "Rock", "pearl jam": "Rock",
            "soundgarden": "Rock", "alice in chains": "Rock", "stone temple pilots": "Rock", "green day": "Rock", 
            "blink-182": "Rock", "linkin park": "Rock", "system of a down": "Rock", "metallica": "Rock", 
            "iron maiden": "Rock", "black sabbath": "Rock", "led zeppelin": "Rock", "pink floyd": "Rock", 
            "the beatles": "Rock", "queens of the stone age": "Rock", "tool": "Rock", "rage against the machine": "Rock", 
            "audioslave": "Rock",
            
            // Indie Artists (keeping indie classification for these artists)
            "arctic monkeys": "Indie", "the strokes": "Indie", "radiohead": "Indie", "tame impala": "Indie", 
            "mac miller": "Indie", "rex orange county": "Indie", "clairo": "Indie", "boy pablo": "Indie", 
            "cuco": "Indie", "still woozy": "Indie", "the 1975": "Indie", "vampire weekend": "Indie", 
            "foster the people": "Indie", "mgmt": "Indie", "two door cinema club": "Indie", "phoenix": "Indie", 
            "alt-j": "Indie", "glass animals": "Indie", "cage the elephant": "Indie", "interpol": "Indie", 
            "yeah yeah yeahs": "Indie",
            
            // Country Artists
            "kacey musgraves": "Country", "chris stapleton": "Country", "maren morris": "Country",
            "keith urban": "Country", "carrie underwood": "Country", "blake shelton": "Country", "luke bryan": "Country",
            "florida georgia line": "Country", "dan + shay": "Country", "old dominion": "Country", "thomas rhett": "Country",
            "kenny chesney": "Country", "brad paisley": "Country", "tim mcgraw": "Country", "faith hill": "Country",
            
            // K-Pop Artists
            "bts": "K-Pop", "blackpink": "K-Pop", "twice": "K-Pop", "red velvet": "K-Pop",
            "itzy": "K-Pop", "aespa": "K-Pop", "newjeans": "K-Pop", "ive": "K-Pop",
            "stray kids": "K-Pop", "seventeen": "K-Pop", "txt": "K-Pop", "enhypen": "K-Pop",
            "girls generation": "K-Pop", "super junior": "K-Pop", "exo": "K-Pop", "nct": "K-Pop",
            
            // Latin Artists
            "bad bunny": "Latin", "j balvin": "Latin", "ozuna": "Latin", "maluma": "Latin",
            "karol g": "Latin", "daddy yankee": "Latin", "shakira": "Latin", "manu chao": "Latin",
            "rosalia": "Latin", "jesse & joy": "Latin", "mau y ricky": "Latin", "cnco": "Latin",
            
            // Jazz Artists
            "miles davis": "Jazz", "john coltrane": "Jazz", "ella fitzgerald": "Jazz", "billie holiday": "Jazz",
            "louis armstrong": "Jazz", "duke ellington": "Jazz", "charlie parker": "Jazz", "thelonious monk": "Jazz",
            "herbie hancock": "Jazz", "weather report": "Jazz", "chick corea": "Jazz", "pat metheny": "Jazz",
            
            // Alternative Artists (unique entries only)
            "the smiths": "Alternative", "joy division": "Alternative", "new order": "Alternative",
            "the cure": "Alternative", "depeche mode": "Alternative", "pixies": "Alternative", "sonic youth": "Alternative",
            "my bloody valentine": "Alternative", "slowdive": "Alternative", "ride": "Alternative"
        ]
        
        // Check artist database first (most reliable)
        if let genre = artistGenreMap[artistLower] {
            print("🎯 Genre classified by artist database: \(artist) → \(genre)")
            return genre
        }
        
        // Enhanced keyword matching with more comprehensive terms
        let genreKeywords: [String: [String]] = [
            "Hip-Hop": [
                "rap", "hip hop", "hiphop", "trap", "drill", "grime", "gangsta rap",
                "conscious rap", "mumble rap", "boom bap", "freestyle", "cipher",
                "lil ", "young ", "big ", "mc ", "dj ", "producer", "beats"
            ],
            "Pop": [
                "pop", "mainstream", "chart", "radio", "commercial", "dance pop",
                "electropop", "synthpop", "bubblegum", "teen pop", "adult contemporary"
            ],
            "R&B": [
                "r&b", "rnb", "rhythm and blues", "soul", "neo soul", "contemporary r&b",
                "quiet storm", "new jack swing", "urban contemporary", "smooth"
            ],
            "Rock": [
                "rock", "metal", "punk", "grunge", "hardcore", "alternative rock",
                "indie rock", "classic rock", "hard rock", "progressive rock",
                "psychedelic", "garage rock", "post punk", "new wave"
            ],
            "Electronic": [
                "electronic", "edm", "dance", "techno", "house", "trance", "dubstep",
                "drum and bass", "ambient", "synthwave", "electro", "breakbeat",
                "deep house", "progressive house", "big room", "future bass"
            ],
            "Indie": [
                "indie", "independent", "alternative", "lo-fi", "bedroom pop",
                "dream pop", "shoegaze", "post rock", "math rock", "experimental"
            ],
            "Country": [
                "country", "folk", "bluegrass", "americana", "western", "honky tonk",
                "outlaw country", "contemporary country", "country rock", "alt country"
            ],
            "Latin": [
                "latin", "reggaeton", "salsa", "bachata", "merengue", "cumbia",
                "latin pop", "latin rock", "banda", "mariachi", "ranchera"
            ],
            "K-Pop": [
                "k-pop", "kpop", "korean", "korea", "seoul", "hallyu", "idol"
            ],
            "Jazz": [
                "jazz", "swing", "bebop", "cool jazz", "fusion", "smooth jazz",
                "free jazz", "hard bop", "post bop", "contemporary jazz"
            ],
            "Classical": [
                "classical", "orchestra", "symphony", "concerto", "sonata",
                "baroque", "romantic", "modern classical", "chamber music"
            ],
            "Reggae": [
                "reggae", "dub", "ska", "dancehall", "roots reggae", "ragga"
            ],
            "Funk": [
                "funk", "disco", "groove", "p-funk", "funk rock", "electro funk"
            ],
            "Blues": [
                "blues", "delta blues", "chicago blues", "electric blues", "country blues"
            ],
            "Alternative": [
                "alternative", "alt rock", "grunge", "britpop", "post grunge",
                "alternative metal", "nu metal", "emo", "screamo"
            ]
        ]
        
        // Check for genre keywords in combined text
        for (genre, keywords) in genreKeywords {
            for keyword in keywords {
                if combinedText.contains(keyword) {
                    print("🎯 Genre classified by keyword '\(keyword)': \(artist) - \(title) → \(genre)")
                    return genre
                }
            }
        }
        
        // Enhanced artist name pattern matching
        if artistLower.contains("lil ") || artistLower.contains("young ") || 
           artistLower.contains("big ") || artistLower.hasPrefix("mc ") ||
           artistLower.contains("$") || artistLower.contains("21 ") {
            print("🎯 Genre classified by hip-hop pattern: \(artist) → Hip-Hop")
            return "Hip-Hop"
        }
        
        // Check for featuring patterns (often hip-hop)
        if combinedText.contains("feat.") || combinedText.contains("ft.") || combinedText.contains("featuring") {
            print("🎯 Genre classified by featuring pattern: \(artist) - \(title) → Hip-Hop")
            return "Hip-Hop"
        }
        
        // Song title pattern matching
        if titleLower.contains("remix") || titleLower.contains("mix") {
            print("🎯 Genre classified by remix pattern: \(title) → Electronic")
            return "Electronic"
        }
        
        // Default fallback with better distribution
        let fallbackGenres = ["Hip-Hop", "Pop", "R&B", "Rock", "Electronic", "Indie"]
        let hash = abs(artistLower.hashValue)
        let selectedGenre = fallbackGenres[hash % fallbackGenres.count]
        print("🎯 Genre classified by fallback: \(artist) - \(title) → \(selectedGenre)")
        return selectedGenre
    }
    
    private func genreColor(for genre: String) -> Color {
        switch genre.lowercased() {
        case "hip-hop": return Color.orange
        case "pop": return Color.pink
        case "r&b": return Color.purple
        case "electronic": return Color.blue
        case "rock": return Color.red
        case "indie": return Color.green
        case "country": return Color.brown
        case "k-pop": return Color.mint
        case "latin": return Color.yellow
        case "jazz": return Color.indigo
        case "classical": return Color.gray
        case "reggae": return Color.teal
        case "funk": return Color.orange.opacity(0.7)
        case "blues": return Color.cyan
        case "alternative": return Color.secondary
        case "other": return Color.gray.opacity(0.5)
        default: return Color.gray.opacity(0.5)
        }
    }
}

// MARK: - Genre Detail Card Components

private struct GenreDetailLogCard: View {
    let log: MusicLog
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onCorrectGenre: () -> Void
    @State private var userProfile: UserProfile? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                // Album artwork
                Group {
                    if let artwork = log.artworkUrl, let url = URL(string: artwork) {
                        CachedAsyncImage(url: url) { image in 
                            image.resizable().scaledToFill() 
                        } placeholder: { 
                            Color.gray.opacity(0.3) 
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3))
                    }
                }
                .frame(width: 64, height: 64)
                .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 6) {
                    // Title and artist
                    Text(log.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    if !log.artistName.isEmpty {
                        Text(log.artistName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Rating
                    if let rating = log.rating {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { s in
                                Image(systemName: s <= rating ? "star.fill" : "star")
                                    .foregroundColor(s <= rating ? .yellow : .gray)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            
            // Review text
            if let review = log.review, !review.isEmpty {
                Text(review)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .padding(.horizontal, 2)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit Log", systemImage: "pencil")
            }
            
            Button(action: onCorrectGenre) {
                Label("Correct Genre", systemImage: "music.note.list")
            }
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete Log", systemImage: "trash")
            }
        }
    }
}

private struct GenreDetailGridCard: View {
    let log: MusicLog
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onCorrectGenre: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Album artwork
            Group {
                if let artwork = log.artworkUrl, let url = URL(string: artwork) {
                    CachedAsyncImage(url: url) { image in 
                        image.resizable().scaledToFill() 
                    } placeholder: { 
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray4))
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            )
                    }
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray4))
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.caption)
                                .foregroundColor(.white)
                        )
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 2) {
                // Title
                Text(log.title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                // Artist
                if !log.artistName.isEmpty {
                    Text(log.artistName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Rating stars
                if let rating = log.rating {
                    HStack(spacing: 1) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 8))
                                .foregroundColor(star <= rating ? .yellow : .gray)
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit Log", systemImage: "pencil")
            }
            
            Button(action: onCorrectGenre) {
                Label("Correct Genre", systemImage: "music.note.list")
            }
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete Log", systemImage: "trash")
            }
        }
    }
}

// Simplified controls for genre detail view
private struct GenreDetailControls: View {
    @Binding var viewFormat: DiaryViewFormat
    @Binding var sortOption: DiarySortOption
    
    var body: some View {
        HStack {
            Spacer()
            
            HStack(spacing: 16) {
                // List/Grid Toggle
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewFormat = viewFormat == .list ? .grid : .list
                    }
                }) {
                    Image(systemName: viewFormat.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.purple)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Sort Menu
                Menu {
                    ForEach(DiarySortOption.allCases, id: \.self) { option in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                sortOption = option
                            }
                        }) {
                            HStack {
                                Image(systemName: option.icon)
                                Text(option.rawValue)
                                if sortOption == option {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.purple)
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: sortOption.icon)
                            .font(.system(size: 14))
                        Text(sortOption.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
                    .foregroundColor(.primary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// Reuse the same DiaryViewFormat and DiarySortOption enums
enum DiaryViewFormat: String, CaseIterable {
    case list = "List"
    case grid = "Grid"
    
    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "grid"
        }
    }
}

enum DiarySortOption: String, CaseIterable {
    case mostRecent = "Most Recent"
    case oldest = "Oldest"
    case alphabetical = "A-Z"
    case highestRated = "Highest Rated"
    case mostPopular = "Most Popular"
    
    var icon: String {
        switch self {
        case .mostRecent: return "clock"
        case .oldest: return "clock.arrow.circlepath"
        case .alphabetical: return "textformat.abc"
        case .highestRated: return "star.fill"
        case .mostPopular: return "heart.fill"
        }
    }
}
