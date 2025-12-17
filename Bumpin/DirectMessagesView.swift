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
            VStack(spacing: 0) {
                // Custom Tab Selector (matching notifications design)
                HStack(spacing: 0) {
                    ForEach([("Inbox", 0), ("Requests", 1)], id: \.1) { title, tag in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                segment = tag
                            }
                        }) {
                            VStack(spacing: 4) {
                                Text(title)
                                    .font(.subheadline)
                                    .fontWeight(segment == tag ? .bold : .regular)
                                    .foregroundColor(segment == tag ? .primary : .secondary)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                
                                // Bottom indicator line
                                if segment == tag {
                                    Rectangle()
                                        .fill(Color.purple)
                                        .frame(height: 3)
                                } else {
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(height: 3)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(segment == tag ? Color.purple.opacity(0.12) : Color.clear)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .background(Color(.systemBackground))
                
                // Content
                if currentList.isEmpty {
                    emptyStateView
                } else {
                    List(currentList, id: \.id) { convo in
                        HStack(spacing: 12) {
                            EnhancedConversationListItem(
                                conversation: convo,
                                displayName: conversationDisplayName(convo),
                                subtitle: conversationSubtitle(convo),
                                participantsPreview: conversationParticipantsPreview(convo),
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
                                Circle().fill(Color.blue).frame(width: 9, height: 9)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .listStyle(PlainListStyle())
                }
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
                ConversationView(
                    conversation: convo,
                    onDismiss: { selectedConversation = nil },
                    initialDisplayName: conversationDisplayName(convo),
                    initialProfilePictureUrl: conversationParticipantsPreview(convo).first?.1
                )
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
                DMComposeSearchView { conversation in
                    showingCompose = false
                    selectedConversation = conversation
                }
                .navigationTitle("New Message")
            }
            .navigationViewStyle(.stack)
        }
    }

    private var currentList: [Conversation] { segment == 0 ? inbox : requests }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: segment == 0 ? "tray" : "envelope.badge")
                    .font(.system(size: 48))
                    .foregroundColor(.purple)
            }
            
            // Text content
            VStack(spacing: 8) {
                Text(segment == 0 ? "No messages yet" : "No message requests")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(segment == 0
                    ? "Start a conversation with your friends and\nshare your music tastes"
                    : "You have no pending message requests")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            
            // CTA Button (only for inbox)
            if segment == 0 {
                Button(action: { showingCompose = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("Start a New Chat")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color.purple)
                    )
                    .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

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

    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private func otherUserId(_ convo: Conversation) -> String? {
        guard let myId = currentUserId else { return nil }
        return convo.participantIds.first { $0 != myId }
    }
    
    private func conversationDisplayName(_ convo: Conversation) -> String {
        if convo.isBotConversation {
            return "Music Matchmaking Bot"
        }
        
        if convo.isGroupConversation {
            if let name = convo.groupName, !name.isEmpty {
                return name
            }
            let names = conversationParticipantsPreview(convo).map { $0.0 }
            if names.isEmpty {
                return "Group Chat"
            } else if names.count == 1 {
                return names[0]
            } else if names.count == 2 {
                return "\(names[0]), \(names[1])"
            } else {
                return "\(names[0]), \(names[1]) +\(names.count - 2)"
            }
        }
        
        if let uid = otherUserId(convo), let meta = userMeta[uid] {
            return meta.username
        }
        if let uid = otherUserId(convo) { return "@\(uid.prefix(6))" }
        return "@user"
    }
    
    private func conversationSubtitle(_ convo: Conversation) -> String {
        if let last = convo.lastMessage, !last.isEmpty {
            return last
        }
        if convo.isGroupConversation {
            return "\(max(convo.participantIds.count, 2)) members"
        }
        if let uid = otherUserId(convo), let meta = userMeta[uid] {
            return "@\(meta.username)"
        }
        return "Message"
    }
    
    private func conversationParticipantsPreview(_ convo: Conversation) -> [(String, String?)] {
        guard let myId = Auth.auth().currentUser?.uid else { return [] }
        var previews: [(String, String?)] = []
        let others = convo.participantIds.filter { $0 != myId }
        for uid in others.prefix(2) {
            if let meta = userMeta[uid] {
                previews.append((meta.username, meta.pfp))
            } else if let cached = DMUserMetaCache.shared.get(uid) {
                previews.append((cached.0, cached.1))
            } else {
                previews.append(("@\(uid.prefix(6))", nil))
            }
        }
        return previews
    }
    
    private func ensureUserMeta() {
        guard let myId = Auth.auth().currentUser?.uid else { return }
        let allConversations = inbox + requests
        let otherUserIds = Set(allConversations.flatMap { convo in
            convo.participantIds.filter { $0 != myId }
        })
        let missing = otherUserIds.filter { DMUserMetaCache.shared.get($0) == nil && userMeta[$0] == nil }
        guard !missing.isEmpty else { return }
        let db = Firestore.firestore()
        for batch in Array(missing).chunked(into: 10) {
            db.collection("users").whereField("uid", in: batch).getDocuments { snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                var updates: [String: (String, String?)] = [:]
                for doc in documents {
                    let data = doc.data()
                    let uid = data["uid"] as? String ?? doc.documentID
                    let username = data["username"] as? String ?? data["displayName"] as? String ?? "user"
                    let pfp = data["profilePictureUrl"] as? String
                        ?? data["profileImageUrl"] as? String
                        ?? data["profileHeaderUrl"] as? String
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
    var onConversationReady: (Conversation) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var results: [UserProfile] = []
    @State private var selectedUsers: [UserProfile] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var groupName: String = ""
    @State private var isCreatingConversation = false
    
    private var isGroupChat: Bool { selectedUsers.count > 1 }
    private var canStartChat: Bool { !selectedUsers.isEmpty && !isCreatingConversation }
    
    var body: some View {
        VStack(spacing: 0) {
            searchBar
            
            if !selectedUsers.isEmpty {
                selectionChips
            }
            
            if isGroupChat {
                groupNameField
            }
            
            if isLoading {
                ProgressView()
                    .padding(.top, 16)
            }
            if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
            
            List {
                ForEach(results) { user in
                    Button {
                        toggleSelection(for: user)
                    } label: {
                        HStack(spacing: 16) {
                            avatar(for: user)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("@\(user.username)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedUsers.contains(where: { $0.uid == user.uid }) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.purple)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(PlainListStyle())
            
            Button(action: startConversation) {
                HStack {
                    if isCreatingConversation {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                    Text(isGroupChat ? "Start Group Chat" : "Start Chat")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canStartChat ? Color.purple : Color.gray.opacity(0.4))
                .foregroundColor(.white)
                .cornerRadius(14)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .disabled(!canStartChat)
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("Search users", text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .onSubmit { search() }
            Button(action: search) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.purple)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 12)
    }
    
    private var selectionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(selectedUsers, id: \.uid) { user in
                    HStack(spacing: 6) {
                        Text(user.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                        Button(action: { removeSelection(user) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption2)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.15))
                    .cornerRadius(16)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }
    
    private var groupNameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Group Name")
                .font(.caption)
                .foregroundColor(.secondary)
            TextField("Auto-generated", text: $groupName)
                .textFieldStyle(.roundedBorder)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    private func avatar(for user: UserProfile) -> some View {
        Group {
            if let url = user.profilePictureUrl, let u = URL(string: url) {
                AsyncImage(url: u) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.purple.opacity(0.2))
                }
            } else {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .overlay(
                        Text(user.displayName.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.purple)
                    )
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }
    
    private func toggleSelection(for user: UserProfile) {
        if let index = selectedUsers.firstIndex(where: { $0.uid == user.uid }) {
            selectedUsers.remove(at: index)
        } else {
            selectedUsers.append(user)
        }
    }
    
    private func removeSelection(_ user: UserProfile) {
        selectedUsers.removeAll { $0.uid == user.uid }
    }
    
    private func generatedGroupName() -> String {
        let names = selectedUsers.map { $0.displayName }
        if names.count <= 2 {
            return names.joined(separator: ", ")
        } else {
            return "\(names[0]), \(names[1]) +\(names.count - 2)"
        }
    }
    
    private func startConversation() {
        guard !selectedUsers.isEmpty, !isCreatingConversation else { return }
        isCreatingConversation = true
        let ids = selectedUsers.map { $0.uid }
        let proposedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = proposedName.isEmpty ? (isGroupChat ? generatedGroupName() : nil) : proposedName
        
        DirectMessageService.shared.getOrCreateConversation(with: ids, groupName: finalName) { convo, error in
            isCreatingConversation = false
            if let error = error {
                self.error = error.localizedDescription
                return
            }
            if let convo = convo {
                dismiss()
                onConversationReady(convo)
            }
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
    
    @State private var fallbackDisplayName: String?
    @State private var fallbackProfilePictureUrl: String?

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
    @State private var participantProfiles: [String: UserProfile] = [:]
    @State private var showParticipantsSheet = false
    @State private var profileToShow: UserProfile?
    @State private var isHeaderPressed = false
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private func otherUserId(_ conversation: Conversation) -> String? {
        guard let current = currentUserId else { return nil }
        return conversation.participantIds.first { $0 != current }
    }

    private var currentDisplayName: String {
        primaryOtherProfile?.displayName ?? fallbackDisplayName ?? "User"
    }
    
    private var currentProfilePictureUrl: String? {
        if let profile = primaryOtherProfile {
            return profile.profilePictureUrl
                ?? profile.profileHeaderUrl
                ?? fallbackProfilePictureUrl
        }
        return fallbackProfilePictureUrl
    }
    
    private var primaryOtherProfile: UserProfile? {
        if conversation.isGroupConversation {
            if let current = currentUserId {
                return participantProfiles.first(where: { $0.key != current })?.value
            }
            return participantProfiles.values.first
        } else {
            if let profile = otherUserProfile {
                return profile
            }
            if let other = otherUserId(conversation) {
                return participantProfiles[other]
            }
            return nil
        }
    }

    init(conversation: Conversation,
         onDismiss: @escaping () -> Void,
         initialDisplayName: String? = nil,
         initialProfilePictureUrl: String? = nil) {
        self.conversation = conversation
        self.onDismiss = onDismiss
        _fallbackDisplayName = State(initialValue: initialDisplayName)
        _fallbackProfilePictureUrl = State(initialValue: initialProfilePictureUrl)
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                customHeader
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            if hasMore {
                                loadMoreTrigger
                            }
                            
                            if isLoadingMore {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 12)
                            }
                            
                            ForEach(messages) { msg in
                                let isCurrent = msg.senderId == (currentUserId ?? "")
                                EnhancedMessageBubble(
                                    message: msg,
                                    isCurrentUser: isCurrent,
                                    senderProfile: participantProfiles[msg.senderId],
                                    showSenderName: conversation.isGroupConversation && !isCurrent
                                )
                                .id(msg.id)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .opacity
                                ))
                            }
                            
                            if isOtherTyping {
                                TypingIndicatorView(
                                    participantProfile: primaryOtherProfile,
                                    isGroup: conversation.isGroupConversation
                                )
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                    }
                    .onChange(of: messages.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.3)) {
                            if let last = messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onTapGesture { dismissKeyboard() }
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if value.translation.height > 50 {
                                    dismissKeyboard()
                                }
                            }
                    )
                }
                .background(
                    LinearGradient(
                        colors: [Color(.systemBackground), Color(.systemGray6).opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .safeAreaInset(edge: .bottom) {
            messageInputBar
        }
        .onAppear(perform: attach)
        .onDisappear(perform: detach)
        .onChange(of: messages.count) { _, _ in markRead() }
        .sheet(isPresented: $showParticipantsSheet) {
            participantsSheet
        }
        .fullScreenCover(item: $profileToShow) { profile in
            // Show a lightweight profile (overview only) with a dismiss button
            UserProfileView(
                userId: profile.uid,
                showFullProfile: false,
                prefetchedProfile: profile,
                showDismissButton: true
            )
        }
    }
    
    // MARK: - Custom Header
    
    private var customHeader: some View {
        ZStack {
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.purple)
                }
                Spacer()
                if conversation.isGroupConversation {
                    Button(action: { showParticipantsSheet = true }) {
                        Image(systemName: "person.2.circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.purple)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            HStack {
                Spacer()
                if conversation.isBotConversation {
                    botHeaderContent
                } else if conversation.isGroupConversation {
                    groupHeaderContent
                } else {
                    Button(action: {
                        if let profile = primaryOtherProfile {
                            profileToShow = profile
                        }
                    }) {
                        userHeaderContent
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer()
            }
        }
        .frame(height: 64)
        .background(
            Rectangle()
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
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
    
    private var groupHeaderContent: some View {
        VStack(spacing: 4) {
            Button(action: { showParticipantsSheet = true }) {
                HStack(spacing: 8) {
                    groupAvatarPreview
                    Text(conversation.groupName ?? "Group Chat")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            Text("\(conversation.participantIds.count) members")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var groupAvatarPreview: some View {
        let others: [UserProfile]
        if let current = currentUserId {
            others = participantProfiles.filter { $0.key != current }.map { $0.value }
        } else {
            others = Array(participantProfiles.values)
        }
        let previews = Array(others.prefix(2))
        return ZStack {
            ForEach(Array(previews.enumerated()), id: \.offset) { index, profile in
                avatarImage(for: profile)
                    .frame(width: 34, height: 34)
                    .offset(x: index == 0 ? -10 : 10)
            }
        }
        .frame(width: 56, height: 36)
    }
    
    private func avatarImage(for profile: UserProfile) -> some View {
        AsyncImage(url: URL(string: profile.profilePictureUrl ?? profile.profileHeaderUrl ?? "")) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.purple.opacity(0.6), .blue.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Text(profile.displayName.prefix(1).uppercased())
                        .font(.caption)
                        .foregroundColor(.white)
                )
        }
        .clipShape(Circle())
    }
    
    private var userHeaderContent: some View {
        VStack(spacing: 4) {
            // Profile Picture
            Group {
                if let urlString = currentProfilePictureUrl,
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
            Text(currentDisplayName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
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
    
    private var loadMoreTrigger: some View {
        Color.clear
            .frame(height: 1)
            .onAppear {
                if hasMore && !isLoadingMore {
                    loadMore()
                }
            }
    }
    
    // MARK: - Message Input Bar
    
    private var messageInputBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Text Input
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
                
                // Send Button
                Button(action: {
                    if canSend {
                        send()
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(canSend ? .purple : Color(.systemGray4))
                }
                .disabled(!canSend)
                .animation(.easeInOut(duration: 0.15), value: canSend)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func handleTyping() {
        guard let uid = currentUserId else { return }
        typingTask?.cancel()
        let currentIsTyping = !text.isEmpty
        typingTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            if !Task.isCancelled {
                DirectMessageService.shared.setTyping(conversationId: conversation.id, userId: uid, isTyping: currentIsTyping)
            }
        }
    }

    private var isRequestForMe: Bool {
        guard let uid = currentUserId else { return false }
        return conversation.requestFor.contains(uid)
    }

    private func attach() {
        messagesListener?.remove(); presenceListener?.remove()
        messagesListener = DirectMessageService.shared.observeMessages(conversationId: conversation.id, limit: 50) { msgs in
            messages = msgs
            hasMore = !msgs.isEmpty // naive; real check would compare to total
        }
        if let uid = currentUserId {
            presenceListener = DirectMessageService.shared.observeOtherTyping(conversationId: conversation.id, currentUserId: uid) { typing in
                isOtherTyping = typing
            }
        }
        
        fetchParticipantProfiles()
    }
    
    private func fetchParticipantProfiles() {
        Task {
            var fetched: [String: UserProfile] = [:]
            for uid in conversation.participantIds {
            if let profile = await UserProfileCache.shared.getProfile(userId: uid) {
                fetched[uid] = profile
                continue
            }
            
            do {
                let snapshot = try await Firestore.firestore().collection("users").document(uid).getDocument()
                if let profile = try? snapshot.data(as: UserProfile.self) {
                    fetched[uid] = profile
                }
            } catch {
                print("❌ Error fetching participant profile: \(error.localizedDescription)")
            }
            }
            
            await MainActor.run {
                self.participantProfiles = fetched
                if !conversation.isGroupConversation,
                   let current = currentUserId,
                   let other = fetched.first(where: { $0.key != current })?.value {
                    self.otherUserProfile = other
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

    private var participantsSheet: some View {
        NavigationStack {
            List {
                ForEach(participantProfiles.values.sorted(by: { $0.displayName < $1.displayName })) { profile in
                    Button(action: {
                        profileToShow = profile
                        showParticipantsSheet = false
                    }) {
                        HStack(spacing: 12) {
                            avatarImage(for: profile)
                                .frame(width: 44, height: 44)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("@\(profile.username)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Participants")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { showParticipantsSheet = false }
                }
            }
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
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Enhanced Message Bubble

struct EnhancedMessageBubble: View {
    let message: DirectMessage
    let isCurrentUser: Bool
    let senderProfile: UserProfile?
    let showSenderName: Bool
    @State private var showSafetyMenu = false
    @State private var showReportSheet = false
    @State private var showBlockSheet = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser {
                Spacer(minLength: 60)
                messageContent
            } else {
                avatar
                messageContent
                menuButton
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 4)
    }
    
    private var avatar: some View {
        Group {
            if let urlString = senderProfile?.profilePictureUrl,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        Circle().fill(Color.purple.opacity(0.3))
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
    }
    
    private var messageContent: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
            if showSenderName, let name = senderProfile?.displayName {
                Text(name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            
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
            
            Text(formatTime(message.createdAt))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
    }

    private var menuButton: some View {
        Menu {
            ReportMenuButton(
                contentId: message.id,
                contentType: .chatMessage,
                reportedUserId: message.senderId,
                reportedUsername: senderProfile?.username ?? senderProfile?.displayName ?? "user",
                contentPreview: message.text,
                onReport: { showReportSheet = true },
                onBlock: { showBlockSheet = true }
            )
        } label: {
            Image(systemName: "ellipsis")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.trailing, 8)
        .sheet(isPresented: $showReportSheet) {
            ReportContentView(
                contentId: message.id,
                contentType: .chatMessage,
                reportedUserId: message.senderId,
                reportedUsername: senderProfile?.username ?? senderProfile?.displayName ?? "user",
                contentPreview: message.text
            )
        }
        .sheet(isPresented: $showBlockSheet) {
            BlockUserView(
                userId: message.senderId,
                username: senderProfile?.username ?? senderProfile?.displayName ?? "user",
                profilePictureUrl: senderProfile?.profilePictureUrl
            )
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
    let participantProfile: UserProfile?
    let isGroup: Bool
    @State private var animating = false
    
    var body: some View {
        if isGroup {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(participantProfile?.displayName ?? "Someone") is typing…")
                    .font(.caption)
                    .foregroundColor(.secondary)
                indicatorDots
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.systemGray6))
            )
            .padding(.horizontal, 4)
        } else {
            HStack(alignment: .bottom, spacing: 8) {
                avatar
                indicatorDots
                Spacer(minLength: 60)
            }
            .padding(.horizontal, 4)
        }
    }
    
    private var avatar: some View {
        Group {
            if let urlString = participantProfile?.profilePictureUrl,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        Circle().fill(Color.purple.opacity(0.3))
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
    }
    
    private var indicatorDots: some View {
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
        .onAppear { animating = true }
    }
}