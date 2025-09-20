import Foundation
import FirebaseFirestore

struct MusicList: Identifiable, Codable, Equatable {
    var id: String
    var userId: String
    var title: String
    var description: String?
    var coverImageUrl: String? = nil
    var items: [String] // Array of song/album IDs
    var createdAt: Date
    var listType: String? // "regular" or "listenNext"
}

extension MusicList {
    static func createList(_ list: MusicList, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        do {
            try db.collection("lists").document(list.id).setData(from: list) { error in
                completion?(error)
            }
        } catch {
            completion?(error)
        }
    }

    static func fetchListsForUser(userId: String, completion: @escaping ([MusicList]?, Error?) -> Void) {
        let db = Firestore.firestore()
        db.collection("lists").whereField("userId", isEqualTo: userId).order(by: "createdAt", descending: true).getDocuments { snapshot, error in
            if let error = error {
                completion(nil, error)
                return
            }
            let lists = snapshot?.documents.compactMap { try? $0.data(as: MusicList.self) }
            completion(lists, nil)
        }
    }

    static func fetchAllLists(completion: @escaping ([MusicList]?, Error?) -> Void) {
        let db = Firestore.firestore()
        db.collection("lists").order(by: "createdAt", descending: true).getDocuments { snapshot, error in
            if let error = error {
                completion(nil, error)
                return
            }
            let lists = snapshot?.documents.compactMap { try? $0.data(as: MusicList.self) }
            completion(lists, nil)
        }
    }

    static func deleteList(listId: String, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        db.collection("lists").document(listId).delete { error in
            completion?(error)
        }
    }

    static func updateList(_ list: MusicList, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        do {
            try db.collection("lists").document(list.id).setData(from: list) { error in
                completion?(error)
            }
        } catch {
            completion?(error)
        }
    }

    static func fetchOrCreateListenNextList(for userId: String, completion: @escaping (MusicList?, Error?) -> Void) {
        let db = Firestore.firestore()
        
        // Simple query without ordering to avoid index requirement
        db.collection("lists")
            .whereField("userId", isEqualTo: userId)
            .whereField("listType", isEqualTo: "listenNext")
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching Listen Next: \(error)")
                    completion(nil, error)
                    return
                }
                
                if let document = snapshot?.documents.first,
                   let existingList = try? document.data(as: MusicList.self) {
                    print("✅ Found existing Listen Next list")
                    completion(existingList, nil)
                } else {
                    print("🆕 No Listen Next list found, creating new one")
                    // Create a new Listen Next list
                    let newList = MusicList(
                        id: UUID().uuidString,
                        userId: userId,
                        title: "Listen Next",
                        description: "Songs, albums, or artists you want to check out soon.",
                        items: [],
                        createdAt: Date(),
                        listType: "listenNext"
                    )
                    createList(newList) { error in
                        if let error = error {
                            print("❌ Error creating new Listen Next list: \(error)")
                            completion(nil, error)
                        } else {
                            print("✅ Successfully created new Listen Next list")
                            completion(newList, nil)
                        }
                    }
                }
            }
    }
} 