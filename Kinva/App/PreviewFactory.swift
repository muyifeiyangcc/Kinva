import UIKit

@MainActor
enum PreviewFactory {
    static func root(route: String?) -> UIViewController {
        switch route {
        case "welcome": return WelcomeViewController()
        case "signin": return SignInViewController()
        case "signup": return SignUpViewController()
        case "profile-form": return ProfileFormViewController(mode: .onboarding)
        case "ai": return InspirationSelectionViewController()
        case "challenge-detail": return ChallengeDetailViewController(challenge: LocalDataStore.shared.visibleChallenges()[0])
        case "report": return ReportViewController(targetID: "elena", targetType: "user")
        case "recharge": return recharge()
        case "settings": return SettingsViewController()
        case "explore": return tabs(selected: 1)
        case "messages": return tabs(selected: 2)
        case "profile": return tabs(selected: 3)
        case "challenge": return tabs(selected: 0)
        default: return SplashViewController()
        }
    }

    static func tabs(selected: Int = 0) -> UIViewController {
        let challenge = ChallengeHomeViewController()
        let explore = ExploreViewController()
        explore.display(posts: LocalDataStore.shared.visiblePosts().map { ViewModelAdapters.post($0) }, feed: .trending)
        let messages = MessagesListViewController()
        messages.display(conversations: LocalDataStore.shared.visibleConversations().map { ViewModelAdapters.conversation($0) })
        let profile = myProfile()
        let controllers = [challenge, explore, messages, profile].map { viewController in
            let navigation = UINavigationController(rootViewController: viewController)
            navigation.view.backgroundColor = AppTheme.background
            navigation.navigationBar.backgroundColor = AppTheme.background
            navigation.navigationBar.isTranslucent = false
            return navigation
        }
        let titles = ["Challenge", "Explore", "Messages", "Me"]
        let tabImages = [("tab1", "tab1_sel"), ("tab2", "tab2_sel"), ("tab3", "tab3_sel"), ("tab4", "tab4_sel")]
        for index in controllers.indices {
            let images = tabImages[index]
            controllers[index].tabBarItem = UITabBarItem(title: titles[index],
                                                         image: tabImage(named: images.0),
                                                         selectedImage: tabImage(named: images.1))
        }
        let tab = UITabBarController(); tab.viewControllers = controllers; tab.view.backgroundColor = AppTheme.background; tab.selectedIndex = min(max(0, selected), controllers.count - 1)
        tab.tabBar.tintColor = AppTheme.blue; tab.tabBar.unselectedItemTintColor = UIColor(hex: 0xC4C8CB); tab.tabBar.backgroundColor = .white
        tab.tabBar.layer.cornerRadius = 22; tab.tabBar.layer.cornerCurve = .continuous; tab.tabBar.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        return tab
    }

    private static func tabImage(named name: String) -> UIImage? {
        UIImage(named: name)?.withRenderingMode(.alwaysOriginal)
    }

    static func myProfile() -> MyProfileViewController {
        let store = LocalDataStore.shared
        let screen = MyProfileViewController()
        let avatar = kinvaAvatarImage(userID: store.currentUserID)
        screen.configureProfile(name: store.account.user.name, followingCount: store.account.user.followingIDs.count, followerCount: store.account.user.followerIDs.count, balance: store.account.diamondBalance, avatar: avatar)
        screen.setPosts(store.posts.filter { $0.authorID == store.currentUserID }.map { MyProfileViewController.PostItem(id: $0.id, authorName: store.account.user.name, authorImage: avatar, caption: $0.caption, topic: $0.topic) })
        screen.setChallenges(store.challenges.filter { $0.authorID == store.currentUserID }.map { MyProfileViewController.ChallengeItem(id: $0.id, title: $0.title) })
        screen.setJoined(store.visibleChallenges().filter { $0.participantIDs.contains(store.currentUserID) }.map { MyProfileViewController.ChallengeItem(id: $0.id, title: $0.title) })
        return screen
    }

    static func recharge() -> RechargeViewController {
        let screen = RechargeViewController(); screen.setBalance(LocalDataStore.shared.account.diamondBalance)
        screen.setTiers(MockCatalog.diamondProducts.enumerated().map { index, item in RechargeViewController.Tier(id: "tier-\(index)", diamonds: item.diamonds, price: item.price) })
        return screen
    }
}
