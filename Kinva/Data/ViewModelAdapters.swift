import Foundation

@MainActor
enum ViewModelAdapters {
    static func author(id: String) -> SocialAuthorViewModel { author(id: id, store: .shared) }
    static func author(id: String, store: LocalDataStore) -> SocialAuthorViewModel {
        let user = store.user(id: id)
        return SocialAuthorViewModel(id: id, name: user?.name ?? "Local Dancer", subtitle: nil)
    }

    static func post(_ value: KinvaPost) -> SocialPostViewModel { post(value, store: .shared) }
    static func post(_ value: KinvaPost, store: LocalDataStore) -> SocialPostViewModel {
        SocialPostViewModel(id: value.id,
                            author: author(id: value.authorID, store: store),
                            caption: value.caption,
                            topic: value.topic,
                            imageTokens: value.imageTokens,
                            imageCount: value.imageTokens.count,
                            likeCount: value.likedBy.count,
                            isLiked: value.likedBy.contains(store.currentUserID))
    }

    static func comment(_ value: KinvaComment) -> SocialCommentViewModel { comment(value, store: .shared) }
    static func comment(_ value: KinvaComment, store: LocalDataStore) -> SocialCommentViewModel {
        SocialCommentViewModel(id: value.id,
                               author: author(id: value.authorID, store: store),
                               timestamp: RelativeDateTimeFormatter().localizedString(for: value.createdAt, relativeTo: Date()),
                               body: value.text,
                               canDelete: value.authorID == store.currentUserID)
    }

    static func profile(userID: String) -> SocialProfileViewModel? { profile(userID: userID, store: .shared) }
    static func profile(userID: String, store: LocalDataStore) -> SocialProfileViewModel? {
        guard let user = store.user(id: userID), !store.account.blockedUserIDs.contains(userID) else { return nil }
        return SocialProfileViewModel(user: author(id: userID, store: store),
                                      followingCount: compact(user.followingIDs.count),
                                      followerCount: compact(user.followerIDs.count),
                                      isFollowing: store.account.user.followingIDs.contains(userID),
                                      canMessage: store.account.user.followingIDs.contains(userID) && user.followingIDs.contains(store.currentUserID),
                                      posts: store.visiblePosts().filter { $0.authorID == userID }.map { post($0, store: store) })
    }

    static func participant(for conversation: KinvaConversation) -> MessageParticipantViewModel { participant(for: conversation, store: .shared) }
    static func participant(for conversation: KinvaConversation, store: LocalDataStore) -> MessageParticipantViewModel {
        let otherID = conversation.participantIDs.first { $0 != store.currentUserID } ?? store.currentUserID
        let user = store.user(id: otherID)
        return MessageParticipantViewModel(id: otherID, name: user?.name ?? "Local Dancer")
    }

    static func conversation(_ value: KinvaConversation) -> MessageConversationViewModel { conversation(value, store: .shared) }
    static func conversation(_ value: KinvaConversation, store: LocalDataStore) -> MessageConversationViewModel {
        let last = value.messages.last
        return MessageConversationViewModel(id: value.id,
                                            participant: participant(for: value, store: store),
                                            preview: last?.kind == .voice ? "Voice message" : (last?.body ?? "No messages"),
                                            timestamp: last.map { RelativeDateTimeFormatter().localizedString(for: $0.createdAt, relativeTo: Date()) } ?? "",
                                            isUnread: value.isUnread)
    }

    static func chatMessage(_ value: KinvaMessage) -> ChatMessageViewModel { chatMessage(value, store: .shared) }
    static func chatMessage(_ value: KinvaMessage, store: LocalDataStore) -> ChatMessageViewModel {
        let participant = MessageParticipantViewModel(id: value.senderID, name: store.user(id: value.senderID)?.name ?? "Local Dancer")
        let kind: ChatMessageViewModel.Kind = value.kind == .voice
            ? .voice(duration: "\(Int(value.voiceDuration ?? 0))″", progress: 0)
            : .text(value.body)
        return ChatMessageViewModel(id: value.id,
                                    sender: participant,
                                    isOutgoing: value.senderID == store.currentUserID,
                                    kind: kind,
                                    voiceToken: value.kind == .voice ? value.body : nil)
    }

    static func notification(_ value: KinvaNotification) -> SystemNotificationViewModel { notification(value, store: .shared) }
    static func notification(_ value: KinvaNotification, store: LocalDataStore) -> SystemNotificationViewModel {
        SystemNotificationViewModel(id: value.id,
                                    actor: value.actorID.map { id in MessageParticipantViewModel(id: id, name: store.user(id: id)?.name ?? "Local Dancer") },
                                    text: value.text,
                                    timestamp: RelativeDateTimeFormatter().localizedString(for: value.createdAt, relativeTo: Date()),
                                    hasThumbnail: value.targetID != nil)
    }

    private static func compact(_ count: Int) -> String {
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
}
