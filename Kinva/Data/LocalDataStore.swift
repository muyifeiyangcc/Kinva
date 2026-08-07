import Foundation

@MainActor
final class LocalDataStore {
    static let shared = LocalDataStore()
    static let didChangeNotification = Notification.Name("KinvaLocalDataDidChange")

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let accountKey = "kinva.local.account.v1"
    private let accountsKey = "kinva.local.accounts.v2"
    private let sessionKey = "kinva.local.session.v2"
    private let legacySessionKey = "kinva.local.session.v1"
    private let postsKey = "kinva.local.posts.v1"
    private let seedVersionKey = "kinva.local.seed.version.v4"
    private let challengesKey = "kinva.local.challenges.v1"
    private let conversationsKey = "kinva.local.conversations.v1"
    private let conversationsByAccountKey = "kinva.local.conversations.by-account.v2"
    private let deletedSeedTestAccountKey = "kinva.local.test-account.deleted.v1"
    private let zeroBalanceSeedTestAccountKey = "kinva.local.test-account.zero-balance.v1"
    private let avatarTokensKey = "kinva.local.avatar-tokens.v1"
    private let eulaAcceptedKey = "kinva.device.eula.accepted.v1"
    private static let seedTestUserID = "local-test-user"
    private static let seedTestEmail = "123@gmail.com"
    private static let seedTestPassword = "12345678"

    private var accounts: [String: LocalAccount]
    private var conversationsByAccount: [String: [KinvaConversation]]
    private(set) var account: LocalAccount
    private(set) var posts: [KinvaPost]
    private(set) var challenges: [KinvaChallenge]
    private(set) var conversations: [KinvaConversation]
    private(set) var notifications: [KinvaNotification] = MockCatalog.notifications
    private(set) var parseFailure: Error?

    var isSignedIn: Bool { defaults.string(forKey: sessionKey) != nil || defaults.bool(forKey: legacySessionKey) }
    /// Device-level consent. This deliberately does not belong to an account,
    /// so signing out or deleting an account never makes the EULA appear again.
    var hasAcceptedEULA: Bool { defaults.bool(forKey: eulaAcceptedKey) }
    var currentUserID: String { account.user.id }

    func acceptEULA() {
        defaults.set(true, forKey: eulaAcceptedKey)
    }

    func avatarToken(userID: String) -> String? {
        guard let token = avatarTokens[userID], FileManager.default.fileExists(atPath: token) else { return nil }
        return token
    }

    func updateCurrentAvatar(token: String) throws {
        guard FileManager.default.fileExists(atPath: token) else { throw LocalStoreError.invalidInput }
        var values = avatarTokens
        values[currentUserID] = token
        avatarTokens = values
        notify()
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let fallback = Self.defaultAccount()
        var loadedAccounts: [String: LocalAccount] = [:]
        var loadedConversations: [String: [KinvaConversation]] = [:]
        var selectedID: String? = defaults.string(forKey: sessionKey)
        posts = MockCatalog.posts
        challenges = MockCatalog.challenges
        do {
            if let value = defaults.data(forKey: accountsKey) {
                loadedAccounts = try decoder.decode([String: LocalAccount].self, from: value)
            } else if let value = defaults.data(forKey: accountKey) {
                let migrated = try decoder.decode(LocalAccount.self, from: value)
                loadedAccounts = [migrated.user.id: migrated]
            }
            if selectedID == nil, defaults.bool(forKey: legacySessionKey) { selectedID = loadedAccounts.values.first?.user.id }
            if let value = defaults.data(forKey: conversationsByAccountKey) {
                loadedConversations = try decoder.decode([String: [KinvaConversation]].self, from: value)
            } else if let value = defaults.data(forKey: conversationsKey), let id = loadedAccounts.values.first?.user.id {
                loadedConversations[id] = try decoder.decode([KinvaConversation].self, from: value)
            }
            if let value = defaults.data(forKey: postsKey) { posts = try decoder.decode([KinvaPost].self, from: value) }
            if let value = defaults.data(forKey: challengesKey) { challenges = try decoder.decode([KinvaChallenge].self, from: value) }
        } catch {
            parseFailure = error
        }
        for id in loadedAccounts.keys {
            if var value = loadedAccounts[id] {
                value.user.email = Self.normalizeEmail(value.user.email)
                loadedAccounts[id] = value
            }
        }
        if defaults.integer(forKey: seedVersionKey) < 4 {
            Self.replaceLegacySeedData(accounts: &loadedAccounts,
                                       conversations: &loadedConversations,
                                       posts: &posts,
                                       challenges: &challenges)
            if let accountsData = try? encoder.encode(loadedAccounts),
               let conversationsData = try? encoder.encode(loadedConversations),
               let postsData = try? encoder.encode(posts),
               let challengesData = try? encoder.encode(challenges) {
                defaults.set(accountsData, forKey: accountsKey)
                defaults.set(conversationsData, forKey: conversationsByAccountKey)
                defaults.set(postsData, forKey: postsKey)
                defaults.set(challengesData, forKey: challengesKey)
                defaults.set(4, forKey: seedVersionKey)
            }
        }
        if defaults.integer(forKey: seedVersionKey) < 5 {
            let seededChallenges = Dictionary(uniqueKeysWithValues: MockCatalog.challenges.map { ($0.id, $0) })
            for index in challenges.indices {
                guard let seeded = seededChallenges[challenges[index].id],
                      challenges[index].authorID == seeded.authorID,
                      challenges[index].mediaTokens == seeded.mediaTokens else { continue }
                challenges[index].detail = seeded.detail
            }
            if let challengesData = try? encoder.encode(challenges) {
                defaults.set(challengesData, forKey: challengesKey)
                defaults.set(5, forKey: seedVersionKey)
            }
        }
        if defaults.integer(forKey: seedVersionKey) < 6 {
            let seededChallenges = Dictionary(uniqueKeysWithValues: MockCatalog.challenges.map { ($0.id, $0) })
            for index in challenges.indices {
                guard let seeded = seededChallenges[challenges[index].id],
                      challenges[index].authorID == seeded.authorID,
                      challenges[index].mediaTokens == seeded.mediaTokens else { continue }
                challenges[index].diamondPrice = seeded.diamondPrice
            }
            if let challengesData = try? encoder.encode(challenges) {
                defaults.set(challengesData, forKey: challengesKey)
                defaults.set(6, forKey: seedVersionKey)
            }
        }
        if !defaults.bool(forKey: deletedSeedTestAccountKey),
           !loadedAccounts.values.contains(where: { Self.normalizeEmail($0.user.email) == Self.seedTestEmail }) {
            let test = Self.seedTestAccount()
            loadedAccounts[test.user.id] = test
            loadedConversations[test.user.id] = Self.seedTestConversations()
            if let accountsData = try? encoder.encode(loadedAccounts) {
                defaults.set(accountsData, forKey: accountsKey)
            }
            if let conversationsData = try? encoder.encode(loadedConversations) {
                defaults.set(conversationsData, forKey: conversationsByAccountKey)
            }
        }
        if !defaults.bool(forKey: deletedSeedTestAccountKey),
           var test = loadedAccounts[Self.seedTestUserID] {
            let followerID = Self.seedTestFollowerID()
            var shouldPersist = false
            var didMigrateBalance = false
            if !defaults.bool(forKey: zeroBalanceSeedTestAccountKey) {
                // Remove the old 12,312 seed grant without discarding real
                // consumable purchases. The transaction ledger is the source
                // of truth for everything earned or spent after initialization.
                test.diamondBalance = max(0, test.transactions.reduce(0) { $0 + $1.amount })
                shouldPersist = true
                didMigrateBalance = true
            }
            if !test.user.followerIDs.contains(followerID) {
                test.user.followerIDs.insert(followerID)
                shouldPersist = true
            }
            if !test.user.followingIDs.contains(followerID) {
                test.user.followingIDs.insert(followerID)
                shouldPersist = true
            }
            if shouldPersist {
                loadedAccounts[Self.seedTestUserID] = test
                if let accountsData = try? encoder.encode(loadedAccounts) {
                    defaults.set(accountsData, forKey: accountsKey)
                    if didMigrateBalance {
                        defaults.set(true, forKey: zeroBalanceSeedTestAccountKey)
                    }
                }
            }
            if loadedConversations[Self.seedTestUserID]?.contains(where: { $0.participantIDs.contains(followerID) }) != true {
                loadedConversations[Self.seedTestUserID] = Self.seedTestConversations()
                if let conversationsData = try? encoder.encode(loadedConversations) {
                    defaults.set(conversationsData, forKey: conversationsByAccountKey)
                }
            }
        }
        let accountValues = loadedAccounts
        if let selectedID, accountValues[selectedID] == nil {
            defaults.removeObject(forKey: sessionKey)
            defaults.removeObject(forKey: legacySessionKey)
        }
        let activeID = selectedID.flatMap { accountValues[$0]?.user.id } ?? accountValues.keys.sorted().first
        let activeConversations = activeID.flatMap { loadedConversations[$0] } ?? []
        accounts = accountValues
        account = activeID.flatMap { accountValues[$0] } ?? fallback
        conversationsByAccount = loadedConversations
        conversations = activeConversations
    }

    private static func defaultAccount() -> LocalAccount {
        let user = KinvaUser(id: MockCatalog.currentUserID,
                             name: "Local Dancer",
                             email: "local@kinva.local",
                             birthday: nil,
                             gender: nil,
                             followingIDs: [],
                             followerIDs: [])
        return LocalAccount(user: user, password: "kinva123", profileComplete: true, acceptedAgreementVersion: nil, diamondBalance: 12_312, blockedUserIDs: [], reports: [], unlockedChallengeIDs: [], savedInspirations: [], transactions: [])
    }

    private static func seedTestAccount() -> LocalAccount {
        let followerID = seedTestFollowerID()
        let user = KinvaUser(id: seedTestUserID,
                             name: "123",
                             email: seedTestEmail,
                             birthday: nil,
                             gender: nil,
                             followingIDs: [followerID],
                             followerIDs: [followerID])
        return LocalAccount(user: user,
                            password: seedTestPassword,
                            profileComplete: true,
                            acceptedAgreementVersion: nil,
                            diamondBalance: 0,
                            blockedUserIDs: [],
                            reports: [],
                            unlockedChallengeIDs: [],
                            savedInspirations: [],
                            transactions: [])
    }

    private static func seedTestFollowerID() -> String {
        MockCatalog.users.first?.id ?? "elena"
    }

    private static func seedTestConversations() -> [KinvaConversation] {
        let followerID = seedTestFollowerID()
        return [
            KinvaConversation(id: "conversation-\(seedTestUserID)-\(followerID)",
                              participantIDs: [seedTestUserID, followerID],
                              messages: [
                                  KinvaMessage(id: "test-m1", senderID: followerID, body: "Welcome to Kinva!", kind: .text, voiceDuration: nil, createdAt: Date().addingTimeInterval(-600))
                              ],
                              isUnread: true)
        ]
    }

    private static func replaceLegacySeedData(accounts: inout [String: LocalAccount],
                                              conversations: inout [String: [KinvaConversation]],
                                              posts: inout [KinvaPost],
                                              challenges: inout [KinvaChallenge]) {
        let legacyUserIDs: Set<String> = ["sophia", "alice", "mary"]
        let legacyPostIDs: Set<String> = ["post-1", "post-2", "post-3"]
        let legacyChallengeIDs: Set<String> = ["challenge-stretch", "challenge-gravity"]
        let currentSeedPostIDs = Set(MockCatalog.posts.map(\.id))
        let currentSeedChallengeIDs = Set(MockCatalog.challenges.map(\.id))

        if let oldDefault = accounts[MockCatalog.currentUserID],
           normalizeEmail(oldDefault.user.email) == "katrina@kinva.local" {
            accounts.removeValue(forKey: MockCatalog.currentUserID)
            conversations.removeValue(forKey: MockCatalog.currentUserID)
        }

        for id in Array(accounts.keys) {
            guard var value = accounts[id] else { continue }
            value.user.followingIDs.subtract(legacyUserIDs)
            value.user.followerIDs.subtract(legacyUserIDs)
            value.blockedUserIDs.subtract(legacyUserIDs)
            value.unlockedChallengeIDs.subtract(legacyChallengeIDs)
            accounts[id] = value
        }

        posts.removeAll { legacyPostIDs.contains($0.id) || currentSeedPostIDs.contains($0.id) }
        posts = posts.map { post in
            var value = post
            value.likedBy.subtract(legacyUserIDs)
            value.comments.removeAll { legacyUserIDs.contains($0.authorID) }
            return value
        }
        posts.append(contentsOf: MockCatalog.posts)

        challenges.removeAll { legacyChallengeIDs.contains($0.id) || currentSeedChallengeIDs.contains($0.id) }
        challenges = challenges.map { challenge in
            var value = challenge
            value.likedBy.subtract(legacyUserIDs)
            value.participantIDs.subtract(legacyUserIDs)
            return value
        }
        challenges.append(contentsOf: MockCatalog.challenges)

        for accountID in Array(conversations.keys) {
            conversations[accountID]?.removeAll { conversation in
                conversation.id == "conversation-sophia" ||
                !conversation.participantIDs.isDisjoint(with: legacyUserIDs)
            }
        }
    }

    func user(id: String) -> KinvaUser? {
        if id == currentUserID { return account.user }
        if let local = accounts[id]?.user { return local }
        guard var user = MockCatalog.users.first(where: { $0.id == id }) else { return nil }
        if account.user.followerIDs.contains(id) { user.followingIDs.insert(currentUserID) }
        if account.user.followingIDs.contains(id) { user.followerIDs.insert(currentUserID) }
        return user
    }

    func visiblePosts(followingOnly: Bool = false) -> [KinvaPost] {
        posts.filter { post in
            !account.blockedUserIDs.contains(post.authorID) && (!followingOnly || account.user.followingIDs.contains(post.authorID))
        }.map { post in
            var filtered = post
            filtered.comments.removeAll { account.blockedUserIDs.contains($0.authorID) }
            return filtered
        }
    }

    func visibleChallenges() -> [KinvaChallenge] { challenges.filter { !account.blockedUserIDs.contains($0.authorID) } }
    func visibleConversations() -> [KinvaConversation] { conversations.filter { $0.participantIDs.isDisjoint(with: account.blockedUserIDs) } }
    func visibleNotifications() -> [KinvaNotification] { notifications.filter { $0.actorID.map { !account.blockedUserIDs.contains($0) } ?? true } }
    func visibleRelations(_ ids: Set<String>) -> [KinvaUser] { ids.filter { !account.blockedUserIDs.contains($0) }.compactMap(user(id:)) }

    @discardableResult func signIn(email: String, password: String) -> Bool {
        let normalized = Self.normalizeEmail(email)
        guard let match = accounts.values.first(where: { Self.normalizeEmail($0.user.email) == normalized && $0.password == password }) else { return false }
        switchAccount(match)
        defaults.set(match.user.id, forKey: sessionKey)
        defaults.removeObject(forKey: legacySessionKey)
        notify()
        return true
    }

    func createAccount(email: String, password: String) throws {
        let normalized = Self.normalizeEmail(email)
        guard Self.isValidEmail(normalized), password.count >= 6 else { throw LocalStoreError.invalidInput }
        guard !accounts.values.contains(where: { Self.normalizeEmail($0.user.email) == normalized }) else { throw LocalStoreError.accountExists }
        let id = "local-\(UUID().uuidString)"
        let user = KinvaUser(id: id, name: normalized.split(separator: "@").first.map(String.init) ?? "Local Dancer", email: normalized, birthday: nil, gender: nil, followingIDs: [], followerIDs: [])
        let created = LocalAccount(user: user, password: password, profileComplete: false, acceptedAgreementVersion: nil, diamondBalance: 0, blockedUserIDs: [], reports: [], unlockedChallengeIDs: [], savedInspirations: [], transactions: [])
        accounts[id] = created
        conversationsByAccount[id] = []
        do {
            try persistAccounts()
            try persistConversationsByAccount()
        } catch {
            accounts.removeValue(forKey: id); conversationsByAccount.removeValue(forKey: id); throw error
        }
        switchAccount(created)
        defaults.set(id, forKey: sessionKey)
        defaults.removeObject(forKey: legacySessionKey)
        notify()
    }

    func resetPassword(email: String, password: String) throws {
        let normalized = Self.normalizeEmail(email)
        guard let id = accounts.first(where: { Self.normalizeEmail($0.value.user.email) == normalized })?.key else { throw LocalStoreError.notFound }
        guard password.count >= 6 else { throw LocalStoreError.invalidInput }
        accounts[id]?.password = password
        if id == currentUserID { account.password = password }
        try persistAccounts()
    }

    func updateProfile(name: String, birthday: Date?, gender: String?) throws {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw LocalStoreError.invalidInput }
        account.user.name = clean; account.user.birthday = birthday; account.user.gender = gender; account.profileComplete = true
        try persistAccount()
    }

    func acceptAgreement(version: String = "1.0") throws { account.acceptedAgreementVersion = version; try persistAccount() }
    func signOut() { defaults.removeObject(forKey: sessionKey); defaults.removeObject(forKey: legacySessionKey); notify() }

    func deleteCurrentAccount() throws {
        let deletedID = currentUserID
        let oldAccounts = accounts
        let oldConversations = conversationsByAccount
        let oldPosts = posts
        let oldChallenges = challenges
        let oldNotifications = notifications
        let oldAvatarTokens = avatarTokens
        let oldDeletedSeedTestAccountFlag = defaults.bool(forKey: deletedSeedTestAccountKey)
        let deletedAvatarToken = oldAvatarTokens[deletedID]
        var updatedAvatarTokens = oldAvatarTokens
        updatedAvatarTokens.removeValue(forKey: deletedID)
        let removedPostIDs = Set(posts.filter { $0.authorID == deletedID }.map(\.id))
        let removedChallengeIDs = Set(challenges.filter { $0.authorID == deletedID }.map(\.id))
        accounts.removeValue(forKey: deletedID)
        conversationsByAccount.removeValue(forKey: deletedID)
        posts.removeAll { $0.authorID == deletedID }
        posts = posts.map { post in
            var value = post
            value.likedBy.remove(deletedID)
            value.comments.removeAll { $0.authorID == deletedID }
            return value
        }
        challenges.removeAll { $0.authorID == deletedID }
        challenges = challenges.map { challenge in
            var value = challenge
            value.likedBy.remove(deletedID)
            value.participantIDs.remove(deletedID)
            return value
        }
        notifications.removeAll { $0.actorID == deletedID || ($0.targetID.map { removedPostIDs.contains($0) || removedChallengeIDs.contains($0) } ?? false) }
        do {
            let accountsData = try encoder.encode(accounts)
            let conversationsData = try encoder.encode(conversationsByAccount)
            let postsData = try encoder.encode(posts)
            let challengesData = try encoder.encode(challenges)
            defaults.set(accountsData, forKey: accountsKey)
            defaults.set(conversationsData, forKey: conversationsByAccountKey)
            defaults.set(postsData, forKey: postsKey)
            defaults.set(challengesData, forKey: challengesKey)
            avatarTokens = updatedAvatarTokens
            if deletedID == Self.seedTestUserID {
                defaults.set(true, forKey: deletedSeedTestAccountKey)
            }
            defaults.removeObject(forKey: accountKey)
            defaults.removeObject(forKey: sessionKey)
            defaults.removeObject(forKey: legacySessionKey)
            let fallback = accounts.values.sorted { $0.user.id < $1.user.id }.first ?? Self.defaultAccount()
            account = fallback
            conversations = conversationsByAccount[fallback.user.id] ?? []
            notify()
            if let deletedAvatarToken { try? FileManager.default.removeItem(atPath: deletedAvatarToken) }
        } catch {
            accounts = oldAccounts
            conversationsByAccount = oldConversations
            posts = oldPosts
            challenges = oldChallenges
            notifications = oldNotifications
            avatarTokens = oldAvatarTokens
            defaults.set(oldDeletedSeedTestAccountFlag, forKey: deletedSeedTestAccountKey)
            account = oldAccounts[deletedID] ?? Self.defaultAccount()
            conversations = conversationsByAccount[deletedID] ?? []
            throw LocalStoreError.writeFailed
        }
    }

    func block(userID: String) throws {
        guard userID != currentUserID else { throw LocalStoreError.cannotBlockSelf }
        account.blockedUserIDs.insert(userID)
        do { try persistAccount() } catch { account.blockedUserIDs.remove(userID); throw error }
    }

    func unblock(userID: String) throws { account.blockedUserIDs.remove(userID); try persistAccount() }

    func report(targetID: String, targetType: String, reason: String, note: String?) throws {
        account.reports.append(LocalReport(id: UUID().uuidString, reporterID: currentUserID, targetID: targetID, targetType: targetType, reason: reason, note: note, createdAt: Date()))
        try persistAccount() // Deliberately does not mutate blockedUserIDs or visible content.
    }

    func toggleFollow(userID: String) throws -> Bool {
        if account.user.followingIDs.contains(userID) { account.user.followingIDs.remove(userID) } else { account.user.followingIDs.insert(userID) }
        try persistAccount(); return account.user.followingIDs.contains(userID)
    }

    func togglePostLike(postID: String) throws {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { throw LocalStoreError.notFound }
        if posts[index].likedBy.contains(currentUserID) { posts[index].likedBy.remove(currentUserID) } else { posts[index].likedBy.insert(currentUserID) }
        try persist(posts, key: postsKey)
    }

    func addComment(postID: String, text: String) throws {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let index = posts.firstIndex(where: { $0.id == postID }) else { throw LocalStoreError.invalidInput }
        posts[index].comments.append(KinvaComment(id: UUID().uuidString, authorID: currentUserID, text: clean, createdAt: Date()))
        try persist(posts, key: postsKey)
    }

    func deleteComment(postID: String, commentID: String) throws {
        guard let postIndex = posts.firstIndex(where: { $0.id == postID }),
              let comment = posts[postIndex].comments.first(where: { $0.id == commentID }),
              comment.authorID == currentUserID else { throw LocalStoreError.notFound }
        posts[postIndex].comments.removeAll { $0.id == commentID }
        try persist(posts, key: postsKey)
    }

    func createPost(caption: String, topic: String, imageCount: Int) throws -> KinvaPost {
        try createPost(caption: caption, topic: topic, imageTokens: (0..<imageCount).map { "legacy-local-\($0)" })
    }

    func createPost(caption: String, topic: String, imageTokens: [String]) throws -> KinvaPost {
        let validTokens = imageTokens.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && FileManager.default.fileExists(atPath: $0) }
        guard !validTokens.isEmpty || !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LocalStoreError.invalidInput }
        let post = KinvaPost(id: UUID().uuidString, authorID: currentUserID, caption: caption, topic: topic, imageTokens: validTokens, likedBy: [], comments: [], createdAt: Date())
        posts.insert(post, at: 0); try persist(posts, key: postsKey); return post
    }

    func deletePost(id: String) throws {
        guard posts.contains(where: { $0.id == id && $0.authorID == currentUserID }) else { throw LocalStoreError.notFound }
        posts.removeAll { $0.id == id }
        notifications.removeAll { $0.targetID == id }
        try persist(posts, key: postsKey)
    }

    func createChallenge(title: String, detail: String, category: String, price: Int) throws -> KinvaChallenge {
        try createChallenge(title: title, detail: detail, category: category, price: price, mediaTokens: [])
    }

    func createChallenge(title: String, detail: String, category: String, price: Int, mediaTokens: [String]) throws -> KinvaChallenge {
        let clean = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let validTokens = mediaTokens.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && FileManager.default.fileExists(atPath: $0) }
        guard !clean.isEmpty, price >= 0, !validTokens.isEmpty else { throw LocalStoreError.invalidInput }
        let challenge = KinvaChallenge(id: UUID().uuidString, authorID: currentUserID, title: title, detail: clean, category: category, mediaTokens: validTokens, diamondPrice: price, likedBy: [], participantIDs: [])
        challenges.insert(challenge, at: 0); try persist(challenges, key: challengesKey); return challenge
    }

    func deleteChallenge(id: String) throws {
        guard challenges.contains(where: { $0.id == id && $0.authorID == currentUserID }) else { throw LocalStoreError.notFound }
        let oldChallenges = challenges
        let oldAccount = account
        challenges.removeAll { $0.id == id }
        account.unlockedChallengeIDs.remove(id)
        notifications.removeAll { $0.targetID == id }
        do {
            try persist(challenges, key: challengesKey)
            try persistAccount()
        } catch {
            challenges = oldChallenges
            account = oldAccount
            try? persist(challenges, key: challengesKey)
            try? persistAccount()
            throw error
        }
    }

    func toggleChallengeLike(id: String) throws {
        guard let index = challenges.firstIndex(where: { $0.id == id }) else { throw LocalStoreError.notFound }
        if challenges[index].likedBy.contains(currentUserID) { challenges[index].likedBy.remove(currentUserID) } else { challenges[index].likedBy.insert(currentUserID) }
        try persist(challenges, key: challengesKey)
    }

    func joinChallenge(id: String) throws {
        guard let index = challenges.firstIndex(where: { $0.id == id }) else { throw LocalStoreError.notFound }
        challenges[index].participantIDs.insert(currentUserID)
        try persist(challenges, key: challengesKey)
    }

    func unlockChallenge(id: String) throws {
        guard let challenge = challenges.first(where: { $0.id == id }) else { throw LocalStoreError.notFound }
        // A creator always owns access to their own challenge. Keep this
        // safeguard in the data layer as well as the UI so no alternate entry
        // point can charge diamonds for self-authored content.
        guard challenge.authorID != currentUserID else { return }
        guard !account.unlockedChallengeIDs.contains(id) else { return }
        guard account.diamondBalance >= challenge.diamondPrice else { throw LocalStoreError.insufficientDiamonds }
        let oldBalance = account.diamondBalance
        account.diamondBalance -= challenge.diamondPrice
        account.unlockedChallengeIDs.insert(id)
        account.transactions.append(DiamondTransaction(id: UUID().uuidString, amount: -challenge.diamondPrice, reason: "Unlock challenge", relatedID: id, createdAt: Date()))
        do { try persistAccount() } catch { account.diamondBalance = oldBalance; account.unlockedChallengeIDs.remove(id); throw error }
    }

    func generateInspiration(tags: [String]) throws -> InspirationResult {
        guard !tags.isEmpty else { throw LocalStoreError.invalidInput }
        guard account.diamondBalance >= 300 else { throw LocalStoreError.insufficientDiamonds }
        let selected = Set(tags)
        let direction = ["Dance Flow", "Freestyle Movement", "Stretch Performance"].first(where: selected.contains) ?? "Dance Flow"
        let texture = ["Liquid & Flowy", "Sharp & Robotic", "Heavy & Grounded", "Ethereal & Airy", "Dramatic & Emotional"].first(where: selected.contains) ?? "Liquid & Flowy"
        let focus = ["Floor Work", "Upper Body", "Spine Wave", "Wall-Assisted Flow", "Balance & Lines"].first(where: selected.contains) ?? "Balance & Lines"
        let titles: [String: String] = [
            "Dance Flow": "Gravity Escape",
            "Freestyle Movement": "Midnight Pulse",
            "Stretch Performance": "Weightless Lines"
        ]
        let directionCopy: [String: String] = [
            "Dance Flow": "Begin in a clean standing silhouette and let one gesture travel continuously through the whole body.",
            "Freestyle Movement": "Start with a restrained groove, then interrupt the rhythm with one unexpected directional change.",
            "Stretch Performance": "Open with a long diagonal line, holding the shape long enough for the extension to read clearly."
        ]
        let textureCopy: [String: String] = [
            "Liquid & Flowy": "Connect every transition without stopping, allowing the wrists and shoulders to finish each wave.",
            "Sharp & Robotic": "Contrast precise isolations with brief freezes, keeping every angle deliberate and clean.",
            "Heavy & Grounded": "Drop your weight through the knees and hips, using gravity to create a dense, sculptural quality.",
            "Ethereal & Airy": "Lift through the sternum and soften the arms so the movement seems to float beyond the beat.",
            "Dramatic & Emotional": "Build from restraint to one expansive release, letting the face and breath support the final accent."
        ]
        let focusCopy: [String: String] = [
            "Floor Work": "Use an elbow and knee as pivots for a seamless floor slide, then recover through a spiral.",
            "Upper Body": "Lead with the rib cage and elbows while the lower body stays quiet, then reverse the pathway.",
            "Spine Wave": "Send a slow wave from the chest through the spine and finish by folding into a compact shape.",
            "Wall-Assisted Flow": "Let one palm trace the wall as a guide, changing levels while preserving continuous contact.",
            "Balance & Lines": "Finish on a single-leg balance with a long opposing arm line and hold for two counts."
        ]
        let lighting: [String: String] = [
            "Floor Work": "Place a low side light near floor level to lengthen the body shadow.",
            "Upper Body": "Frame from the waist up and use soft frontal light so the isolations remain readable.",
            "Spine Wave": "Use a three-quarter camera angle and a narrow side light to reveal the curve of the spine.",
            "Wall-Assisted Flow": "Shoot parallel to the wall with a single side light to preserve texture and depth.",
            "Balance & Lines": "Choose a wide, uncluttered frame and place the key light opposite the extended arm."
        ]
        let music: [String: String] = [
            "Liquid & Flowy": "Pair it with an atmospheric track and let each transition land between beats.",
            "Sharp & Robotic": "Use a crisp electronic rhythm and align freezes with the strongest percussion hits.",
            "Heavy & Grounded": "Choose a heavy-bass track and match the lowest movement level to the first major drop.",
            "Ethereal & Airy": "Use spacious vocals or ambient pads, cutting only after the final suspended shape.",
            "Dramatic & Emotional": "Select a cinematic build and save the widest gesture for the musical climax."
        ]
        let result = InspirationResult(
            id: UUID().uuidString,
            tags: tags.sorted(),
            title: titles[direction] ?? "Movement Study",
            breakdown: [directionCopy[direction], textureCopy[texture], focusCopy[focus]].compactMap { $0 }.joined(separator: " "),
            shootingTip: [lighting[focus], music[texture]].compactMap { $0 }.joined(separator: " ")
        )
        let oldBalance = account.diamondBalance
        account.diamondBalance -= 300
        account.transactions.append(DiamondTransaction(id: UUID().uuidString, amount: -300, reason: "Generate inspiration", relatedID: result.id, createdAt: Date()))
        do { try persistAccount(); return result } catch { account.diamondBalance = oldBalance; throw error }
    }

    func saveInspiration(_ value: InspirationResult) throws { if !account.savedInspirations.contains(value) { account.savedInspirations.append(value) }; try persistAccount() }

    func addDiamonds(_ amount: Int, transactionID: String) throws {
        guard amount > 0, !account.transactions.contains(where: { $0.id == transactionID }) else { return }
        let previousBalance = account.diamondBalance
        account.diamondBalance += amount
        account.transactions.append(DiamondTransaction(id: transactionID, amount: amount, reason: "Consumable purchase", relatedID: nil, createdAt: Date()))
        do {
            try persistAccount()
        } catch {
            account.diamondBalance = previousBalance
            account.transactions.removeAll { $0.id == transactionID }
            throw error
        }
    }

    func sendText(_ text: String, conversationID: String) throws {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let index = conversations.firstIndex(where: { $0.id == conversationID }) else { throw LocalStoreError.invalidInput }
        conversations[index].messages.append(KinvaMessage(id: UUID().uuidString, senderID: currentUserID, body: clean, kind: .text, voiceDuration: nil, createdAt: Date()))
        try persistCurrentConversations()
    }

    func sendVoice(duration: TimeInterval, conversationID: String) throws {
        try sendVoice(duration: duration, token: "", conversationID: conversationID)
    }

    func sendVoice(duration: TimeInterval, token: String, conversationID: String) throws {
        guard duration >= 1, duration <= 60, let index = conversations.firstIndex(where: { $0.id == conversationID }) else { throw LocalStoreError.invalidInput }
        guard token.isEmpty || FileManager.default.fileExists(atPath: token) else { throw LocalStoreError.invalidInput }
        conversations[index].messages.append(KinvaMessage(id: UUID().uuidString, senderID: currentUserID, body: token, kind: .voice, voiceDuration: duration, createdAt: Date()))
        try persistCurrentConversations()
    }

    func resetMockData() {
        parseFailure = nil; posts = MockCatalog.posts; challenges = MockCatalog.challenges
        conversations = currentUserID == Self.seedTestUserID ? Self.seedTestConversations() : []
        conversationsByAccount[currentUserID] = conversations
        try? persist(posts, key: postsKey); try? persist(challenges, key: challengesKey)
        try? persistConversationsByAccount()
    }

    private static func normalizeEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var avatarTokens: [String: String] {
        get { defaults.dictionary(forKey: avatarTokensKey) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: avatarTokensKey) }
    }

    private static func isValidEmail(_ email: String) -> Bool {
        guard let at = email.firstIndex(of: "@"), at > email.startIndex, at < email.index(before: email.endIndex) else { return false }
        return email[at...].contains(".")
    }

    private func switchAccount(_ value: LocalAccount) {
        account = value
        conversations = conversationsByAccount[value.user.id] ?? []
    }

    private func persistAccounts() throws {
        try persist(accounts, key: accountsKey)
        // v1 stored one account (including its password); once v2 is written it is no longer needed.
        defaults.removeObject(forKey: accountKey)
    }

    private func persistConversationsByAccount() throws {
        try persist(conversationsByAccount, key: conversationsByAccountKey)
        defaults.removeObject(forKey: conversationsKey)
    }

    private func persistCurrentConversations() throws {
        conversationsByAccount[currentUserID] = conversations
        try persistConversationsByAccount()
    }

    private func persistAccount() throws {
        accounts[currentUserID] = account
        try persistAccounts()
    }
    private func persist<T: Encodable>(_ value: T, key: String) throws {
        do { defaults.set(try encoder.encode(value), forKey: key); notify() } catch { throw LocalStoreError.writeFailed }
    }
    private func notify() { NotificationCenter.default.post(name: Self.didChangeNotification, object: self) }
}

enum LocalStoreError: LocalizedError {
    case invalidInput, notFound, insufficientDiamonds, writeFailed, cannotBlockSelf, accountExists
    var errorDescription: String? {
        switch self {
        case .invalidInput: return "Please check the local input."
        case .notFound: return "This local item no longer exists."
        case .insufficientDiamonds: return "Not enough diamonds."
        case .writeFailed: return "The change could not be saved."
        case .cannotBlockSelf: return "You cannot block yourself."
        case .accountExists: return "An account with this email already exists."
        }
    }
}
