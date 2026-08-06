import Foundation

struct KinvaUser: Codable, Hashable {
    let id: String
    var name: String
    var email: String
    var birthday: Date?
    var gender: String?
    var followingIDs: Set<String>
    var followerIDs: Set<String>
    var avatarAssetName: String? = nil
}

struct KinvaPost: Codable, Hashable {
    let id: String
    let authorID: String
    var caption: String
    var topic: String
    var imageTokens: [String]
    var likedBy: Set<String>
    var comments: [KinvaComment]
    let createdAt: Date
}

struct KinvaComment: Codable, Hashable {
    let id: String
    let authorID: String
    var text: String
    let createdAt: Date
}

struct KinvaChallenge: Codable, Hashable {
    let id: String
    let authorID: String
    var title: String
    var detail: String
    var category: String
    var mediaTokens: [String]
    var diamondPrice: Int
    var likedBy: Set<String>
    var participantIDs: Set<String>
}

struct KinvaMessage: Codable, Hashable {
    enum Kind: String, Codable { case text, voice }
    let id: String
    let senderID: String
    var body: String
    let kind: Kind
    var voiceDuration: TimeInterval?
    let createdAt: Date
}

struct KinvaConversation: Codable, Hashable {
    let id: String
    let participantIDs: Set<String>
    var messages: [KinvaMessage]
    var isUnread: Bool
}

struct KinvaNotification: Codable, Hashable {
    let id: String
    let actorID: String?
    var text: String
    var targetID: String?
    let createdAt: Date
}

struct LocalReport: Codable, Hashable {
    let id: String
    let reporterID: String
    let targetID: String
    let targetType: String
    let reason: String
    let note: String?
    let createdAt: Date
}

struct DiamondTransaction: Codable, Hashable {
    let id: String
    let amount: Int
    let reason: String
    let relatedID: String?
    let createdAt: Date
}

struct InspirationResult: Codable, Hashable {
    let id: String
    let tags: [String]
    let title: String
    let breakdown: String
    let shootingTip: String
}

struct LocalAccount: Codable {
    var user: KinvaUser
    var password: String
    var profileComplete: Bool
    var acceptedAgreementVersion: String?
    var diamondBalance: Int
    var blockedUserIDs: Set<String>
    var reports: [LocalReport]
    var unlockedChallengeIDs: Set<String>
    var savedInspirations: [InspirationResult]
    var transactions: [DiamondTransaction]
}

enum MockCatalog {
    static let currentUserID = "local-user"
    static let users: [KinvaUser] = [
        KinvaUser(id: "elena", name: "Elena", email: "elena@kinva.local", birthday: nil, gender: "Woman", followingIDs: [], followerIDs: [], avatarAssetName: "1"),
        KinvaUser(id: "marcus", name: "Marcus", email: "marcus@kinva.local", birthday: nil, gender: "Man", followingIDs: [], followerIDs: [], avatarAssetName: "4"),
        KinvaUser(id: "claire", name: "Claire", email: "claire@kinva.local", birthday: nil, gender: "Woman", followingIDs: [], followerIDs: [], avatarAssetName: "3"),
        KinvaUser(id: "thorne", name: "Thorne", email: "thorne@kinva.local", birthday: nil, gender: "Man", followingIDs: [], followerIDs: [], avatarAssetName: "5"),
        KinvaUser(id: "hannah", name: "Hannah", email: "hannah@kinva.local", birthday: nil, gender: "Woman", followingIDs: [], followerIDs: [], avatarAssetName: "2"),
        KinvaUser(id: "foster", name: "Foster", email: "foster@kinva.local", birthday: nil, gender: "Man", followingIDs: [], followerIDs: [], avatarAssetName: "6"),
        KinvaUser(id: "doris", name: "Doris", email: "doris@kinva.local", birthday: nil, gender: "Woman", followingIDs: [], followerIDs: [], avatarAssetName: "7")
    ]
    static let challenges: [KinvaChallenge] = [
        KinvaChallenge(id: "seed-challenge-elena", authorID: "elena", title: "Stretch Performance", detail: "", category: "Stretch Performance", mediaTokens: ["001.mp4"], diamondPrice: 0, likedBy: [], participantIDs: []),
        KinvaChallenge(id: "seed-challenge-marcus", authorID: "marcus", title: "Dance Flow", detail: "", category: "Dance Flow", mediaTokens: ["003.mp4"], diamondPrice: 0, likedBy: [], participantIDs: []),
        KinvaChallenge(id: "seed-challenge-claire", authorID: "claire", title: "Freestyle Movement", detail: "", category: "Freestyle Movement", mediaTokens: ["009.mp4"], diamondPrice: 0, likedBy: [], participantIDs: []),
        KinvaChallenge(id: "seed-challenge-thorne", authorID: "thorne", title: "Stretch Performance", detail: "", category: "Stretch Performance", mediaTokens: ["008.mp4"], diamondPrice: 0, likedBy: [], participantIDs: []),
        KinvaChallenge(id: "seed-challenge-hannah", authorID: "hannah", title: "Dance Flow", detail: "", category: "Dance Flow", mediaTokens: ["006.mp4"], diamondPrice: 0, likedBy: [], participantIDs: []),
        KinvaChallenge(id: "seed-challenge-foster", authorID: "foster", title: "Freestyle Movement", detail: "", category: "Freestyle Movement", mediaTokens: ["004.mp4"], diamondPrice: 0, likedBy: [], participantIDs: []),
        KinvaChallenge(id: "seed-challenge-doris", authorID: "doris", title: "Stretch Performance", detail: "", category: "Stretch Performance", mediaTokens: ["002.mp4"], diamondPrice: 0, likedBy: [], participantIDs: [])
    ]
    static let posts: [KinvaPost] = [
        KinvaPost(id: "seed-post-elena", authorID: "elena", caption: "Evening hamstrings and hip opener routine. Remember to breathe through each hold.", topic: "Stretch Performance", imageTokens: ["10", "11", "17"], likedBy: [], comments: [KinvaComment(id: "seed-comment-elena", authorID: "marcus", text: "Great posture!", createdAt: Date().addingTimeInterval(-1_800))], createdAt: Date().addingTimeInterval(-3_600)),
        KinvaPost(id: "seed-post-marcus", authorID: "marcus", caption: "Quick 4-minute hip mobility drill before my run. Don't skip your mobility work!", topic: "Dance Flow", imageTokens: ["13"], likedBy: [], comments: [KinvaComment(id: "seed-comment-marcus", authorID: "claire", text: "Perfect form man", createdAt: Date().addingTimeInterval(-5_400))], createdAt: Date().addingTimeInterval(-7_200)),
        KinvaPost(id: "seed-post-thorne", authorID: "thorne", caption: "Current state: completely lost in the moment.", topic: "Stretch Performance", imageTokens: ["16"], likedBy: [], comments: [], createdAt: Date().addingTimeInterval(-10_800)),
        KinvaPost(id: "seed-post-hannah", authorID: "hannah", caption: "Unlocking some fresh floor transitions today. Just letting my body flow with the rhythm.", topic: "Dance Flow", imageTokens: ["14"], likedBy: [], comments: [], createdAt: Date().addingTimeInterval(-14_400)),
        KinvaPost(id: "seed-post-foster", authorID: "foster", caption: "Working on subtle body wave transitions today. How’s the control looking?", topic: "Freestyle Movement", imageTokens: ["15"], likedBy: [], comments: [KinvaComment(id: "seed-comment-foster", authorID: "doris", text: "Cool", createdAt: Date().addingTimeInterval(-16_200))], createdAt: Date().addingTimeInterval(-18_000)),
        KinvaPost(id: "seed-post-doris", authorID: "doris", caption: "Slow spinal wave drill to wake up the body.", topic: "Stretch Performance", imageTokens: ["2222"], likedBy: [], comments: [KinvaComment(id: "seed-comment-doris", authorID: "elena", text: "So graceful", createdAt: Date().addingTimeInterval(-19_800))], createdAt: Date().addingTimeInterval(-21_600))
    ]
    static let conversations: [KinvaConversation] = []
    static let notifications: [KinvaNotification] = [
        KinvaNotification(id: "system-welcome", actorID: nil, text: "Hello new friend, welcome to Kinva.", targetID: nil, createdAt: Date())
    ]
    static let inspirationPool: [InspirationResult] = [
        InspirationResult(id: "gravity", tags: ["Dance Flow", "Heavy & Grounded", "Floor Work"], title: "Gravity Escape", breakdown: "Start from a standing silhouette under one side-light. Drop your weight as if pulled by gravity; use elbows and knees as pivots for a seamless floor slide, then freeze into a sculptural back posture.", shootingTip: "Place a low light source on the floor to elongate the body shadow. Pair it with a heavy-bass track and match the drop to the first major beat."),
        InspirationResult(id: "ripple", tags: ["Freestyle Movement", "Liquid & Flowy", "Spine Wave"], title: "Midnight Ripple", breakdown: "Build a slow wave from the chest through the spine, then let the arms echo the motion in alternating levels.", shootingTip: "Use a single cool side light and leave enough negative space for the arm line.")
    ]
    static let diamondProducts: [(diamonds: Int, price: String)] = [
        (400, "$0.99"),
        (1_200, "$1.99"),
        (2_450, "$4.99"),
        (4_900, "$9.99"),
        (6_400, "$12.99"),
        (9_800, "$19.99"),
        (14_900, "$29.99"),
        (24_500, "$49.99"),
        (34_500, "$69.99"),
        (49_000, "$99.99")
    ]
}
