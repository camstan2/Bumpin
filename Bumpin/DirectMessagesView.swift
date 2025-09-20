import SwiftUI
import FirebaseAuth
import FirebaseFirestore

final class DMUserMetaCache {
    static let shared = DMUserMetaCache()
    private init() {}
    private var cache: [String: (username: String, pfp: String?)] = [:]
    
    func get(_ uid: String) -> (String, String?)? {
        return cache[uid].map { ($0.username, $0.pfp) }
    }
    
    func set(uid: String, username: String, pfp: String?) {
        cache[uid] = (username, pfp)
    }
}

struct DMInboxView: View {
    @State private var inbox: [Conversation] = []
    @State private var requests: [Conversation] = []
    @State private var selectedConversation: Conversation?
    @State private var inboxListener: ListenerRegistration? = nil
    @State private var requestsListener: ListenerRegistration? = nil
    @State private var showingCompose: Bool = false
    @State private var composeSelectedUser: UserProfile? = nil
    @State private var segment: Int = 0
    @State private var userMeta: [String: (username: String, pfp: String?)] = [:]

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Messages", selection: $segment) {
                    Text("Inbox").tag(0)
                    Text("Requests").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                List(currentList, id: \.id) { convo in
                    HStack(spacing: 12) {
                        EnhancedConversationListItem(
                            conversation: convo,
                            displayName: otherDisplayName(convo),
                            profileImageUrl: otherProfileImageUrl(convo),
                            onTap: { selectedConversation = convo }
                        )
                        
                        if segment == 1 {
                            HStack(spacing: 8) {
                                Button("Accept") {
                                    if let uid = Auth.auth().currentUser?.uid {
                                        DirectMessageService.shared.acceptRequest(conversationId: convo.id, userId: uid) { err in
                                            if let err = err { print("Accept error: \(err.localizedDescription)") }
                                        }
                                    }
                                }
                                .font(.caption2)
                                .foregroundColor(.green)
                                
                                Button("Decline") {
                                    if let uid = Auth.auth().currentUser?.uid {
                                        DirectMessageService.shared.declineRequest(conversationId: convo.id, userId: uid) { err in
                                            if let err = err { print("Decline error: \(err.localizedDescription)") }
                                        }
                                    }
                                }
                                .font(.caption2)
                                .foregroundColor(.red)
                            }
                        } else if isUnread(convo) {
                            Circle().fill(Color.purple).frame(width: 8, height: 8)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Messages")
            .onAppear(perform: attach)
            .onDisappear(perform: detach)
            .onChange(of: inbox.count) { _, _ in ensureUserMeta() }
            .onChange(of: requests.count) { _, _ in ensureUserMeta() }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenConversation"))) { note in
                if let convo = note.object as? Conversation {
                    selectedConversation = convo
                }
            }
            .fullScreenCover(item: $selectedConversation) { convo in
                ConversationView(conversation: convo, onDismiss: {
                    selectedConversation = nil
                })
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCompose = true }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCompose) {
            NavigationView {
                DMComposeSearchView(onSelect: { user in
                    showingCompose = false
                    DirectMessageService.shared.getOrCreateConversation(with: user.uid) { convo, err in
                        if let convo = convo { selectedConversation = convo }
                    }
                })
                .navigationTitle("New Message")
            }
        }
    }

    private var currentList: [Conversation] { segment == 0 ? inbox : requests }

    private func attach() {
        inboxListener?.remove(); requestsListener?.remove()
        inboxListener = DirectMessageService.shared.observeInbox { list in
            inbox = list
            ensureUserMeta()
        }
        requestsListener = DirectMessageService.shared.observeRequests { list in
            requests = list
            ensureUserMeta()
        }
    }

    private func detach() {
        inboxListener?.remove(); inboxListener = nil
        requestsListener?.remove(); requestsListener = nil
    }

    private func otherUserId(_ convo: Conversation) -> String? {
        let myId = Auth.auth().currentUser?.uid
        return convo.participantIds.first { $0 != myId }
    }

    private func otherDisplayName(_ convo: Conversation) -> String {
        // Handle bot conversations
        if convo.isBotConversation {
            return "Music Matchmaking Bot"
        }
        
        if let uid = otherUserId(convo), let meta = userMeta[uid] {
            return meta.username
        }
        if let uid = otherUserId(convo) { return "@\(uid.prefix(6))" }
        return "@user"
    }
    
    private func otherProfileImageUrl(_ convo: Conversation) -> String? {
        // Bot conversations don't have profile images
        if convo.isBotConversation {
            return nil
        }
        
        if let uid = otherUserId(convo), let meta = userMeta[uid] {
            return meta.pfp
        }
        return nil
    }

    @ViewBuilder
    private func avatarView(for convo: Conversation) -> some View {
        let size: CGFloat = 40
        if let uid = otherUserId(convo), let meta = userMeta[uid], let urlString = meta.pfp, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle())
                case .failure(_):
                    Circle().fill(Color.purple.opacity(0.2)).frame(width: size, height: size)
                case .empty:
                    Circle().fill(Color.gray.opacity(0.2)).frame(width: size, height: size)
                @unknown default:
                    Circle().fill(Color.gray.opacity(0.2)).frame(width: size, height: size)
                }
            }
        } else {
            Circle().fill(Color.purple.opacity(0.2)).frame(width: size, height: size)
        }
    }

    private func ensureUserMeta() {
        let myId = Auth.auth().currentUser?.uid
        let allConversations = inbox + requests
        let otherUserIds = allConversations.compactMap { convo in
            convo.participantIds.first { $0 != myId }
        }
        let missing = otherUserIds.filter { DMUserMetaCache.shared.get($0) == nil && userMeta[$0] == nil }
        guard !missing.isEmpty else { return }
        let db = Firestore.firestore()
        for batch in missing.chunked(into: 10) {
            db.collection("users").whereField("uid", in: batch).getDocuments { snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                var updates: [String: (String, String?)] = [:]
                for doc in documents {
                    let data = doc.data()
                    let uid = data["uid"] as? String ?? doc.documentID
                    let username = data["username"] as? String ?? data["displayName"] as? String ?? "user"
                    let pfp = data["profilePictureUrl"] as? String
                    DMUserMetaCache.shared.set(uid: uid, username: username, pfp: pfp)
                    updates[uid] = (username, pfp)
                }
                if !updates.isEmpty {
                    DispatchQueue.main.async {
                        for (k, v) in updates { userMeta[k] = v }
                    }
                }
            }
        }
    }

    private func isUnread(_ convo: Conversation) -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        guard let lastAt = convo.lastTimestamp else { return false }
        let lastRead = convo.lastReadAtByUser?[uid]
        return (lastRead == nil) || (lastRead! < lastAt)
    }
}

struct DMComposeSearchView: View {
    var onSelect: (UserProfile) -> Void
    @State private var searchText = ""
    @State private var results: [UserProfile] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Search users", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onSubmit { search() }
                Button(action: search) { Image(systemName: "magnifyingglass").foregroundColor(.purple) }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding()

            if isLoading { ProgressView().padding(.top, 12) }
            if let error = error { Text(error).foregroundColor(.red).padding(.top, 12) }

            List(results) { user in
                Button(action: { onSelect(user) }) {
                    HStack(spacing: 16) {
                        if let url = user.profilePictureUrl, let u = URL(string: url) {
                            AsyncImage(url: u) { phase in
                                phase.image?.resizable().scaledToFill()
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                        } else {
                            Circle().fill(Color.purple.opacity(0.2)).frame(width: 44, height: 44)
                        }
                        VStack(alignment: .leading) {
                            Text(user.displayName).font(.subheadline).fontWeight(.semibold)
                            Text("@\(user.username)").font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(PlainListStyle())
        }
    }

    private func search() {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { results = []; return }
        isLoading = true; error = nil
        let db = Firestore.firestore()
        let ql = q.lowercased()
        db.collection("users")
            .whereField("username_lower", isGreaterThanOrEqualTo: ql)
            .whereField("username_lower", isLessThanOrEqualTo: ql + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments { snap, err in
                isLoading = false
                if let err = err { error = err.localizedDescription; return }
                var found: [UserProfile] = []
                for doc in snap?.documents ?? [] {
                    if let u = try? doc.data(as: UserProfile.self) { found.append(u) }
                }
                if found.isEmpty {
                    db.collection("users")
                        .whereField("displayName_lower", isGreaterThanOrEqualTo: ql)
                        .whereField("displayName_lower", isLessThanOrEqualTo: ql + "\u{f8ff}")
                        .limit(to: 20)
                        .getDocuments { snap2, _ in
                            for doc in snap2?.documents ?? [] {
                                if let u = try? doc.data(as: UserProfile.self) { found.append(u) }
                            }
                            results = found
                        }
                } else {
                    results = found
                }
            }
    }
}
struct ConversationView: View, Identifiable {
    let id = UUID()
    let conversation: Conversation
    let onDismiss: () -> Void

    @State private var messages: [DirectMessage] = []
    @State private var hasMore: Bool = true
    @State private var isLoadingMore: Bool = false
    @State private var text: String = ""
    @State private var isOtherTyping: Bool = false
    @State private var typingTask: Task<Void, Never>? = nil
    @State private var lastDmSentAt: Date = .distantPast
    @State private var messagesListener: ListenerRegistration? = nil
    @State private var presenceListener: ListenerRegistration? = nil
    @State private var otherUserProfile: UserProfile? = nil
    @State private var keyboardHeight: CGFloat = 0
    @State private var showingUserProfile = false
    @State private var isHeaderPressed = false

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Custom Header
                customHeader
                
                // Messages Area
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            // Load More Button
                            if hasMore {
                                loadMoreButton
                                    .padding(.top, 20)
                            }
                            
                            // Messages
                            ForEach(messages) { msg in
                                EnhancedMessageBubble(
                                    message: msg,
                                    isCurrentUser: msg.senderId == Auth.auth().currentUser?.uid,
                                    otherUserProfile: otherUserProfile
                                )
                                .id(msg.id)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .opacity
                                ))
                            }
                            
                            // Typing Indicator
                            if isOtherTyping {
                                TypingIndicatorView(otherUserProfile: otherUserProfile)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                    .onChange(of: messages.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.3)) {
                            if let last = messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .background(
                    LinearGradient(
                        colors: [Color(.systemBackground), Color(.systemGray6).opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                // Message Input
                messageInputBar
            }
            .background(Color(.systemBackground))
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .onAppear(perform: attach)
        .onDisappear(perform: detach)
        .onChange(of: messages.count) { _, _ in markRead() }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                withAnimation(.easeOut(duration: 0.3)) {
                    keyboardHeight = keyboardFrame.cgRectValue.height
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                keyboardHeight = 0
            }
        }
        .fullScreenCover(isPresented: $showingUserProfile) {
            if let otherUser = otherUserProfile {
                NavigationView {
                    UserProfileView(userId: otherUser.uid)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Back") {
                                    showingUserProfile = false
                                }
                                .foregroundColor(.purple)
                            }
                        }
                }
            }
        }
    }
    
    // MARK: - Custom Header
    
    private var customHeader: some View {
        HStack(spacing: 16) {
            // Back Button
            Button(action: onDismiss) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 17, weight: .medium))
                }
                .foregroundColor(.purple)
            }
            
            Spacer()
            
            // User Info
            if conversation.isBotConversation {
                botHeaderContent
            } else {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isHeaderPressed = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isHeaderPressed = false
                        }
                        showingUserProfile = true
                    }
                }) {
                    userHeaderContent
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(isHeaderPressed ? 0.95 : 1.0)
            }
            
            Spacer()
            
            // Action Buttons
            headerActions
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        )
    }
    
    private var botHeaderContent: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                )
            
            Text("Music Bot")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
    
    private var userHeaderContent: some View {
        VStack(spacing: 4) {
            // Profile Picture
            Group {
                if let profile = otherUserProfile,
                   let urlString = profile.profilePictureUrl,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure(_), .empty:
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple.opacity(0.7), .blue.opacity(0.5)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                )
                        @unknown default:
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                    }
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.7), .blue.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        )
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.purple.opacity(0.3), lineWidth: 2)
            )
            
            // Username
            Text(otherUserProfile?.displayName ?? "User")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Text("@\(otherUserProfile?.username ?? "user")")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
    
    private var headerActions: some View {
        HStack(spacing: 16) {
            if isRequestForMe {
                Button(action: declineRequest) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                }
                
                Button(action: acceptRequest) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                }
            } else {
                Button(action: {}) {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Load More Button
    
    private var loadMoreButton: some View {
        Button(action: loadMore) {
            HStack(spacing: 8) {
                if isLoadingMore {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.purple)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 16))
                }
                
                Text(isLoadingMore ? "Loading..." : "Load previous messages")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.purple)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.purple.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .disabled(isLoadingMore)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Message Input Bar
    
    private var messageInputBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Text Input
                HStack(spacing: 8) {
                    TextField("Type a message...", text: $text, axis: .vertical)
                        .font(.system(size: 16))
                        .lineLimit(1...6)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color(.systemGray6))
                        )
                        .onChange(of: text) { _, _ in handleTyping() }
                }
                
                // Send Button
                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(canSend ? .purple : .gray)
                        .scaleEffect(canSend ? 1.0 : 0.8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: canSend)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .padding(.bottom, keyboardHeight > 0 ? 0 : 34) // Account for home indicator
    }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func handleTyping() {
        if let uid = Auth.auth().currentUser?.uid {
            typingTask?.cancel()
            let currentIsTyping = !text.isEmpty
            typingTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 350_000_000)
                if !Task.isCancelled {
                    DirectMessageService.shared.setTyping(conversationId: conversation.id, userId: uid, isTyping: currentIsTyping)
                }
            }
        }
    }

    private var isRequestForMe: Bool {
        if let uid = Auth.auth().currentUser?.uid {
            return conversation.requestFor.contains(uid)
        }
        return false
    }

    private func attach() {
        messagesListener?.remove(); presenceListener?.remove()
        messagesListener = DirectMessageService.shared.observeMessages(conversationId: conversation.id, limit: 50) { msgs in
            messages = msgs
            hasMore = !msgs.isEmpty // naive; real check would compare to total
        }
        if let uid = Auth.auth().currentUser?.uid {
            presenceListener = DirectMessageService.shared.observeOtherTyping(conversationId: conversation.id, currentUserId: uid) { typing in
                isOtherTyping = typing
            }
        }
        
        // Fetch other user profile
        fetchOtherUserProfile()
    }
    
    private func fetchOtherUserProfile() {
        guard !conversation.isBotConversation else { return }
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        guard let otherUserId = conversation.participantIds.first(where: { $0 != currentUserId }) else { return }
        
        Firestore.firestore().collection("users").document(otherUserId).getDocument { snapshot, error in
            if let error = error {
                print("❌ Error fetching user profile: \(error.localizedDescription)")
                return
            }
            
            if let snapshot = snapshot, let profile = try? snapshot.data(as: UserProfile.self) {
                DispatchQueue.main.async {
                    self.otherUserProfile = profile
                }
            }
        }
    }

    private func detach() {
        messagesListener?.remove(); messagesListener = nil
        presenceListener?.remove(); presenceListener = nil
    }

    private func send() {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        // Throttle sends to 10/sec
        let now = Date()
        if now.timeIntervalSince(lastDmSentAt) < 0.1 { return }
        lastDmSentAt = now
        text = ""
        DirectMessageService.shared.sendMessage(conversationId: conversation.id, text: body) { err in
            if let err = err { print("DM send error: \(err.localizedDescription)") }
        }
    }

    private func acceptRequest() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        DirectMessageService.shared.acceptRequest(conversationId: conversation.id, userId: uid) { err in
            if let err = err { print("Accept error: \(err.localizedDescription)") }
        }
    }

    private func declineRequest() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        DirectMessageService.shared.declineRequest(conversationId: conversation.id, userId: uid) { err in
            if let err = err { print("Decline error: \(err.localizedDescription)") }
        }
    }

    private func loadMore() {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        let first = messages.first
        DirectMessageService.shared.fetchMoreMessages(conversationId: conversation.id, after: first, limit: 50) { newMsgs, err in
            DispatchQueue.main.async {
                isLoadingMore = false
                if let err = err { print("Load more error: \(err.localizedDescription)"); return }
                if newMsgs.isEmpty { hasMore = false; return }
                messages = newMsgs + messages
            }
        }
    }

    private func markRead() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        DirectMessageService.shared.markConversationRead(conversationId: conversation.id, userId: uid, completion: nil)
    }
}

// MARK: - Enhanced Message Bubble

struct EnhancedMessageBubble: View {
    let message: DirectMessage
    let isCurrentUser: Bool
    let otherUserProfile: UserProfile?
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser {
                Spacer(minLength: 60)
                messageContent
            } else {
                // Other user's avatar
                Group {
                    if let profile = otherUserProfile,
                       let urlString = profile.profilePictureUrl,
                       let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure(_), .empty:
                                Circle()
                                    .fill(Color.purple.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                    )
                            @unknown default:
                                Circle().fill(Color.gray.opacity(0.3))
                            }
                        }
                    } else {
                        Circle()
                            .fill(Color.purple.opacity(0.3))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
                
                messageContent
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 4)
    }
    
    private var messageContent: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 2) {
            // Message bubble
            Text(message.text)
                .font(.system(size: 16))
                .foregroundColor(isCurrentUser ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            isCurrentUser
                                ? LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color(.systemGray5), Color(.systemGray6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                )
            
            // Timestamp
            Text(formatTime(message.createdAt))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDate(date, inSameDayAs: Date()) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    let otherUserProfile: UserProfile?
    @State private var animating = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Avatar
            Group {
                if let profile = otherUserProfile,
                   let urlString = profile.profilePictureUrl,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure(_), .empty:
                            Circle()
                                .fill(Color.purple.opacity(0.3))
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                )
                        @unknown default:
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                    }
                } else {
                    Circle()
                        .fill(Color.purple.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                        )
                }
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
            
            // Typing animation
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .scaleEffect(animating ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray5))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            
            Spacer(minLength: 60)
        }
        .padding(.horizontal, 4)
        .onAppear {
            animating = true
        }
    }
}