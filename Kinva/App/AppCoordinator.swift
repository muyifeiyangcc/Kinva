import UIKit
import Darwin

@MainActor
final class AppCoordinator: NSObject, UITabBarControllerDelegate {
    private let window: UIWindow
    private let store = LocalDataStore.shared
    private var tabBarController: UITabBarController?
    private var challengeScreen: ChallengeHomeViewController?
    private var exploreScreen: ExploreViewController?
    private var messagesScreen: MessagesListViewController?
    private var profileScreen: MyProfileViewController?

    init(window: UIWindow) { self.window = window }

    deinit { NotificationCenter.default.removeObserver(self) }

    func start() {
        NotificationCenter.default.addObserver(self, selector: #selector(localDataChanged), name: LocalDataStore.didChangeNotification, object: nil)
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-KINVA_ROUTE"), arguments.indices.contains(index + 1) {
            let root = PreviewFactory.root(route: arguments[index + 1])
            if let tabs = root as? UITabBarController {
                tabs.view.backgroundColor = AppTheme.background
                installRoot(tabs)
            } else {
                let navigation = UINavigationController(rootViewController: root)
                navigation.view.backgroundColor = AppTheme.background
                navigation.navigationBar.backgroundColor = AppTheme.background
                navigation.navigationBar.isTranslucent = false
                installRoot(navigation)
            }
            return
        }
        // LaunchScreen.storyboard is the only launch presentation. Installing an
        // app-owned splash here made the same launch artwork appear a second time.
        let needsEULA = !store.hasAcceptedEULA
        store.isSignedIn ? showMain() : showWelcome()
        if needsEULA {
            DispatchQueue.main.async { [weak self] in
                self?.presentInitialEULA()
            }
        }
    }

    @objc private func localDataChanged() {
        guard tabBarController != nil else { return }
        refreshAll()
        if let top = currentNavigationController?.topViewController,
           let challenge = (top as? ChallengeDetailViewController)?.challenge,
           store.account.blockedUserIDs.contains(challenge.authorID) {
            top.navigationController?.popViewController(animated: true)
        }
    }

    private func setRoot(_ controller: UIViewController, navigation: Bool = true) {
        let root: UIViewController
        if navigation {
            let nav = UINavigationController(rootViewController: controller)
            nav.view.backgroundColor = AppTheme.background
            nav.navigationBar.backgroundColor = AppTheme.background
            nav.navigationBar.isTranslucent = false
            root = nav
        } else {
            root = controller
        }
        root.view.backgroundColor = AppTheme.background
        installRoot(root)
    }

    /// Installs a root outside the transition closure. UIKit owns the root view
    /// frame; manually assigning it during scene connection can preserve a
    /// transient compact scene size and create letterboxed black bands.
    private func installRoot(_ root: UIViewController, animated: Bool = true) {
        window.rootViewController = root
        window.backgroundColor = AppTheme.background
        window.makeKeyAndVisible()
        root.view.backgroundColor = AppTheme.background
        if animated {
            UIView.transition(with: window, duration: 0.25, options: [.transitionCrossDissolve, .beginFromCurrentState]) {
                self.window.layoutIfNeeded()
            }
        }
    }

    private func showWelcome() {
        let screen = WelcomeViewController()
        screen.onContinueAsGuest = { [weak self] in self?.showMain() }
        screen.onSignUp = { [weak self] in self?.showSignUp(from: screen) }
        screen.onSignIn = { [weak self] in self?.showSignIn(from: screen) }
        screen.onAppleIdentity = { [weak self] in self?.showProfileForm(mode: .onboarding, from: screen) }
        screen.onOpenTerms = { [weak self, weak screen] in
            guard let self, let screen else { return }
            self.openInternalWebPage(title: "Terms of Service", from: screen)
        }
        screen.onOpenPrivacy = { [weak self, weak screen] in
            guard let self, let screen else { return }
            self.openInternalWebPage(title: "Privacy Policy", from: screen)
        }
        setRoot(screen)
    }

    private func showSignIn(from source: UIViewController) {
        let screen = SignInViewController()
        screen.onBack = { [weak screen] in screen?.navigationController?.popViewController(animated: true) }
        screen.onAlternateAction = { [weak self] in guard let self else { return }; self.showSignUp(from: screen) }
        screen.onAuxiliaryAction = { [weak self] in self?.showResetPassword(from: screen) }
        screen.onSubmit = { [weak self, weak screen] in
            guard let self, let screen else { return }
            let email = screen.emailField.textField.text ?? ""; let password = screen.passwordField.textField.text ?? ""
            guard self.store.signIn(email: email, password: password) else { screen.showLocalAlert(title: "Sign in failed", message: "The Email or password is incorrect."); return }
            self.store.account.profileComplete ? self.showMain() : self.showProfileForm(mode: .onboarding, from: screen)
        }
        source.navigationController?.pushSecondLevel(screen, animated: true)
    }

    private func showSignUp(from source: UIViewController) {
        let screen = SignUpViewController()
        screen.onBack = { [weak screen] in screen?.navigationController?.popViewController(animated: true) }
        screen.onAlternateAction = { [weak self] in guard let self else { return }; self.showSignIn(from: screen) }
        screen.onSubmit = { [weak self, weak screen] in
            guard let self, let screen else { return }
            let email = screen.emailField.textField.text ?? ""; let password = screen.passwordField.textField.text ?? ""; let confirmation = screen.confirmationField.textField.text ?? ""
            guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { screen.showLocalAlert(title: "Enter your email", message: "A Email is required to create an account."); return }
            guard password.count >= 6 else { screen.showLocalAlert(title: "Password too short", message: "Use at least six characters for this account."); return }
            guard password == confirmation else { screen.showLocalAlert(title: "Passwords differ", message: "Enter the same password twice."); return }
            do { try self.store.createAccount(email: email, password: password); self.showProfileForm(mode: .onboarding, from: screen) }
            catch { screen.showLocalAlert(title: "Could not sign up", message: error.localizedDescription) }
        }
        source.navigationController?.pushSecondLevel(screen, animated: true)
    }

    private func showResetPassword(from source: UIViewController) {
        let screen = ResetPasswordViewController(); screen.emailField.textField.text = store.account.user.email
        screen.onBack = { [weak screen] in screen?.navigationController?.popViewController(animated: true) }
        screen.onSubmit = { [weak self, weak screen] in
            guard let self, let screen else { return }
            let email = screen.emailField.textField.text ?? ""; let password = screen.passwordField.textField.text ?? ""; let confirmation = screen.confirmationField.textField.text ?? ""
            guard password == confirmation else { screen.showLocalAlert(title: "Passwords differ", message: "Enter the same password twice."); return }
            do { try self.store.resetPassword(email: email, password: password); screen.navigationController?.popViewController(animated: true) }
            catch { screen.showLocalAlert(title: "Could not reset", message: error.localizedDescription) }
        }
        source.navigationController?.pushSecondLevel(screen, animated: true)
    }

    private func showProfileForm(mode: ProfileFormViewController.Mode, from source: UIViewController?) {
        let screen = ProfileFormViewController(mode: mode)
        if let image = kinvaAvatarImage(userID: store.currentUserID) {
            screen.avatarView.setImage(image)
        }
        screen.selectedAvatarToken = store.avatarToken(userID: store.currentUserID)
        if mode == .editing {
            screen.nameField.textField.text = store.account.user.name
            screen.selectGender(store.account.user.gender)
            if let birthday = store.account.user.birthday { screen.birthdayField.textField.text = DateFormatter.kinvaDay.string(from: birthday) }
        }
        screen.onBack = { [weak screen] in screen?.navigationController?.popViewController(animated: true) }
        screen.onChoosePhoto = { [weak self, weak screen] in
            guard let self, let screen else { return }
            self.presentPhotoSource(from: screen, maxCount: 1) { [weak screen] tokens in
                guard let screen, let token = tokens.first, let image = UIImage(contentsOfFile: token) else { return }
                screen.selectedAvatarToken = token
                screen.avatarView.setImage(image)
            }
        }
        screen.onChooseBirthday = { [weak self, weak screen] in self?.chooseBirthday(from: screen) }
        screen.onSave = { [weak self, weak screen] in
            guard let self, let screen else { return }
            let birthday = screen.birthdayField.textField.text.flatMap(DateFormatter.kinvaDay.date(from:))
            do {
                try self.store.updateProfile(name: screen.nameField.textField.text ?? "", birthday: birthday, gender: screen.selectedGender)
                if let token = screen.selectedAvatarToken { try self.store.updateCurrentAvatar(token: token) }
                if mode == .onboarding {
                    self.showMain()
                } else {
                    self.refreshAll()
                    screen.navigationController?.popViewController(animated: true)
                }
            } catch { screen.showLocalAlert(title: "Could not save", message: error.localizedDescription) }
        }
        if let source { source.navigationController?.pushSecondLevel(screen, animated: true) } else { currentNavigationController?.pushSecondLevel(screen, animated: true) }
    }

    private func chooseBirthday(from source: ProfileFormViewController?) {
        guard let source else { return }
        let selectedDate = source.birthdayField.textField.text.flatMap(DateFormatter.kinvaDay.date(from:))
        let picker = BirthdayPickerViewController(selectedDate: selectedDate)
        picker.onDone = { [weak source] date in
            source?.birthdayField.textField.text = DateFormatter.kinvaDay.string(from: date)
        }
        source.present(picker, animated: true)
    }

    private func presentPhotoSource(from source: UIViewController,
                                    maxCount: Int,
                                    onSelected: @escaping ([String]) -> Void) {
        let handleResult: (Result<[String], Error>) -> Void = { [weak source] result in
            switch result {
            case .success(let tokens):
                onSelected(tokens)
            case .failure(let error):
                if case LocalMediaSelectionError.cancelled = error { return }
                source?.showLocalAlert(title: "Could not select image", message: error.localizedDescription)
            }
        }
        source.showKinvaActionSheet(items: [
            KinvaActionSheetItem(title: "Choose from Library") { [weak source] in
                guard let source else { return }
                LocalMediaPicker.shared.pickImages(from: source, maxCount: maxCount, completion: handleResult)
            },
            KinvaActionSheetItem(title: "Take Photo") { [weak source] in
                guard let source else { return }
                LocalMediaPicker.shared.capturePhoto(from: source, completion: handleResult)
            },
            KinvaActionSheetItem(title: "Cancel", style: .cancel, handler: {})
        ])
    }

    private func presentAgreement(from source: UIViewController, cancelReturnsToWelcome: Bool = false) {
        let body = "Kinva User Agreement\n\nKinva is a purely local creative tool. Your profile, posts, challenges, relationships, messages, reports, blocklist and diamond records stay on this device. Reporting records a local entry and does not hide a user. Blocking is separate and filters that user's content throughout the app.\n\nYou control local media permissions and may delete your account data at any time."
        let agreement = AgreementModalViewController(body: body)
        agreement.onCancel = { [weak agreement, weak self] in agreement?.dismiss(animated: true) { if cancelReturnsToWelcome { self?.showWelcome() } } }
        agreement.onAgree = { [weak agreement, weak self] in do { try self?.store.acceptAgreement(); agreement?.dismiss(animated: true) } catch { agreement?.showLocalAlert(title: "Could not save", message: error.localizedDescription) } }
        source.present(agreement, animated: true)
    }

    private func presentInitialEULA() {
        guard !store.hasAcceptedEULA,
              let source = window.rootViewController else { return }
        let body = """
        Welcome to Kinva! To keep our creative community safe and positive, the following content is strictly prohibited in the app:

        1. Any content involving child sexual abuse material, exploitation, or harm to children.
        
        2. Fake, misleading, or harmful messages regarding current events or public safety.
        
        3. Violence, bullying, harassment, and explicit or pornographic content.
        
        If any violations are found, your content will be deleted and your account will be banned. By tapping "I agree", you agree to the Terms of Use and Privacy Policy.
        """
        let agreement = AgreementModalViewController(body: body)
        agreement.onAgree = { [weak self, weak agreement] in
            guard let self else { return }
            self.store.acceptEULA()
            agreement?.dismiss(animated: true)
        }
        agreement.onCancel = {
            exit(EXIT_SUCCESS)
        }
        source.present(agreement, animated: false)
    }

    private func showMain() {
        let challenge = ChallengeHomeViewController(), explore = ExploreViewController(), messages = MessagesListViewController(), profile = MyProfileViewController()
        challengeScreen = challenge; exploreScreen = explore; messagesScreen = messages; profileScreen = profile
        configureChallenge(challenge); configureExplore(explore); configureMessages(messages); configureProfile(profile)
        let controllers = [challenge, explore, messages, profile].map { viewController in
            let navigation = UINavigationController(rootViewController: viewController)
            navigation.view.backgroundColor = AppTheme.background
            navigation.navigationBar.backgroundColor = AppTheme.background
            navigation.navigationBar.isTranslucent = false
            return navigation
        }
        let titles = ["Challenge", "Explore", "Messages", "Me"]
        let tabImages = [("tab1", "tab1_sel"), ("tab2", "tab2_sel"), ("tab3", "tab3_sel"), ("tab4", "tab4_sel")]
        for i in controllers.indices {
            let images = tabImages[i]
            controllers[i].tabBarItem = UITabBarItem(title: titles[i],
                                                     image: tabImage(named: images.0),
                                                     selectedImage: tabImage(named: images.1))
        }
        let tabs = UITabBarController(); tabs.viewControllers = controllers; tabs.delegate = self; tabs.view.backgroundColor = AppTheme.background; tabs.tabBar.tintColor = AppTheme.blue; tabs.tabBar.unselectedItemTintColor = UIColor(hex: 0xC4C8CB); tabs.tabBar.backgroundColor = .white
        tabs.tabBar.layer.cornerRadius = 22; tabs.tabBar.layer.cornerCurve = .continuous; tabs.tabBar.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        tabBarController = tabs; setRoot(tabs, navigation: false); refreshAll()
    }

    func tabBarController(_ tabBarController: UITabBarController,
                          shouldSelect viewController: UIViewController) -> Bool {
        guard !store.isSignedIn,
              let controllers = tabBarController.viewControllers,
              let index = controllers.firstIndex(of: viewController),
              index >= 2 else { return true }
        presentAuthenticationRequired()
        return false
    }

    @discardableResult
    private func requireSignedIn() -> Bool {
        guard !store.isSignedIn else { return true }
        presentAuthenticationRequired()
        return false
    }

    private func presentAuthenticationRequired() {
        guard let source = currentNavigationController?.topViewController,
              source.presentedViewController == nil else { return }
        let prompt = AccountConfirmationViewController(kind: .authenticationRequired)
        prompt.onCancel = { [weak prompt] in
            prompt?.dismiss(animated: true)
        }
        prompt.onConfirm = { [weak self, weak prompt, weak source] in
            prompt?.dismiss(animated: true) {
                guard let self, let source else { return }
                self.showSignIn(from: source)
            }
        }
        source.present(prompt, animated: true)
    }

    private func tabImage(named name: String) -> UIImage? {
        UIImage(named: name)?.withRenderingMode(.alwaysOriginal)
    }

    private func configureChallenge(_ screen: ChallengeHomeViewController) {
        screen.onCreateChallenge = { [weak self] in self?.openCreateChallenge() }
        screen.onInspiration = { [weak self] in self?.openInspiration() }
        screen.onChallenge = { [weak self] value in self?.openChallenge(value) }
    }

    private func openCreateChallenge() {
        guard requireSignedIn() else { return }
        let screen = CreateChallengeViewController(); screen.onChooseVideo = { [weak screen] in
            guard let screen else { return }
            LocalMediaPicker.shared.pickVideo(from: screen) { result in
                switch result {
                case .success(let tokens): screen.setMediaTokens(tokens)
                case .failure(let error):
                    if case LocalMediaSelectionError.cancelled = error { return }
                    screen.showLocalAlert(title: "Could not select video", message: error.localizedDescription)
                }
            }
        }
        screen.onRecordVideo = { [weak screen] in
            guard let screen else { return }
            LocalMediaPicker.shared.recordVideo(from: screen) { result in
                switch result {
                case .success(let tokens): screen.setMediaTokens(tokens)
                case .failure(let error):
                    if case LocalMediaSelectionError.cancelled = error { return }
                    screen.showLocalAlert(title: "Could not record video", message: error.localizedDescription)
                }
            }
        }
        screen.onPublished = { [weak self, weak screen] _ in self?.refreshAll(); screen?.navigationController?.popViewController(animated: true) }
        currentNavigationController?.pushSecondLevel(screen, animated: true)
    }

    private func openChallenge(_ challenge: KinvaChallenge) {
        guard requireSignedIn() else { return }
        guard !store.account.blockedUserIDs.contains(challenge.authorID) else { currentNavigationController?.topViewController?.showLocalAlert(title: "User blocked", message: "Unblock this user from Settings to view their challenge."); return }
        let screen = ChallengeDetailViewController(challenge: challenge)
        screen.onAuthor = { [weak self] id in self?.openProfile(userID: id) }
        screen.onAccess = { [weak self, weak screen] value in self?.openChallengeAccess(value, from: screen) }
        currentNavigationController?.pushSecondLevel(screen, animated: true)
    }

    private func openChallengeAccess(_ challenge: KinvaChallenge, from source: ChallengeDetailViewController?) {
        let screen = ChallengeAccessViewController(challenge: challenge)
        screen.onAuthor = { [weak self] id in self?.openProfile(userID: id) }
        screen.onRecharge = { [weak self] in self?.openRecharge() }
        screen.onUnlocked = { [weak self] in
            self?.refreshAll()
        }
        screen.onFinished = { [weak self, weak screen] in
            self?.refreshAll()
            screen?.navigationController?.popViewController(animated: true)
        }
        screen.onPlay = { [weak screen] challenge in
            let playback = ChallengePlaybackViewController(challenge: challenge)
            playback.modalPresentationStyle = .fullScreen
            screen?.present(playback, animated: true)
        }
        (source?.navigationController ?? currentNavigationController)?.pushSecondLevel(screen, animated: true)
    }

    private func openInspiration() {
        guard requireSignedIn() else { return }
        let screen = InspirationSelectionViewController(); screen.onGenerated = { [weak screen] result in let next = InspirationResultViewController(result: result); next.onSaved = { [weak next] in next?.navigationController?.popToRootViewController(animated: true) }; screen?.navigationController?.pushSecondLevel(next, animated: true) }
        screen.onRecharge = { [weak self] in self?.openRecharge() }
        currentNavigationController?.pushSecondLevel(screen, animated: true)
    }

    private func configureExplore(_ screen: ExploreViewController) {
        var feed: ExploreViewController.Feed = .trending
        let refresh = { [weak self, weak screen] in guard let self, let screen else { return }; screen.display(posts: self.store.visiblePosts(followingOnly: feed == .following).map { ViewModelAdapters.post($0) }, feed: feed) }
        screen.onRetry = refresh; screen.onFeedChanged = { value in feed = value; refresh() }
        screen.onNotifications = { [weak self] in self?.openNotifications() }; screen.onCompose = { [weak self] in self?.openComposePost() }
        screen.onPost = { [weak self] value in self?.openPost(id: value.id) }; screen.onAuthor = { [weak self] value in self?.openProfile(userID: value.id) }
        screen.onPostMenu = { [weak self] value, anchor in self?.showUserActions(targetID: value.author.id, targetType: "post", anchor: anchor) }
        refresh()
    }

    private func openComposePost() {
        guard requireSignedIn() else { return }
        let screen = ComposePostViewController(); var draft = ComposePostViewController.Draft()
        screen.onBack = { [weak screen] current in if current.imageCount > 0 || !current.description.isEmpty { screen?.showConfirmation(title: "Discard draft?", message: "Your local draft has not been posted.", confirm: "Discard") { screen?.navigationController?.popViewController(animated: true) } } else { screen?.navigationController?.popViewController(animated: true) } }
        screen.onAddImages = { [weak self, weak screen] in
            guard let self, let screen else { return }
            let remaining = max(0, 6 - draft.imageTokens.count)
            guard remaining > 0 else { screen.showLocalAlert(title: "Maximum reached", message: "Choose up to six images for one post."); return }
            self.presentPhotoSource(from: screen, maxCount: remaining) { [weak screen] tokens in
                draft.imageTokens.append(contentsOf: tokens)
                screen?.display(draft: draft)
            }
        }
        screen.onRemoveImage = { [weak screen] index in guard index < draft.imageTokens.count else { return }; draft.imageTokens.remove(at: index); screen?.display(draft: draft) }
        screen.onPost = { [weak self, weak screen] value in guard let self else { return }; do { _ = try self.store.createPost(caption: value.description, topic: value.topic, imageTokens: value.imageTokens); self.refreshAll(); screen?.navigationController?.popViewController(animated: true) } catch { screen?.showLocalAlert(title: "Could not post", message: error.localizedDescription) } }
        currentNavigationController?.pushSecondLevel(screen, animated: true)
    }

    private func openPost(id: String) {
        guard requireSignedIn() else { return }
        guard let post = store.visiblePosts().first(where: { $0.id == id }) else { currentNavigationController?.topViewController?.showLocalAlert(title: "Content unavailable", message: "This post was removed or its author is blocked."); return }
        let screen = PostDetailViewController()
        let display = { [weak self, weak screen] in guard let self, let screen, let current = self.store.visiblePosts().first(where: { $0.id == id }) else { return }; screen.display(post: ViewModelAdapters.post(current), comments: current.comments.map { ViewModelAdapters.comment($0) }) }
        screen.onBack = { [weak screen] in screen?.navigationController?.popViewController(animated: true) }
        screen.onAuthor = { [weak self] author in self?.openProfile(userID: author.id) }
        screen.onMenu = { [weak self] anchor in self?.showUserActions(targetID: post.authorID, targetType: "post", anchor: anchor) }
        screen.onImageTap = { [weak self] tokens, index in self?.openImageBrowser(tokens: tokens, startIndex: index) }
        screen.onLike = { [weak self] in try? self?.store.togglePostLike(postID: id); display() }
        screen.onSendComment = { [weak self, weak screen] text in
            do {
                try self?.store.addComment(postID: id, text: text)
                display()
                return true
            } catch {
                screen?.showLocalAlert(title: "Could not comment", message: error.localizedDescription)
                return false
            }
        }
        screen.onCommentMenu = { [weak self, weak screen] comment, anchor in
            guard let self, let screen else { return }
            if comment.canDelete {
                screen.showConfirmation(title: "Delete Comment", message: "Delete your local comment?", confirm: "Delete") { do { try self.store.deleteComment(postID: id, commentID: comment.id); display() } catch { screen.showLocalAlert(title: "Could not delete", message: error.localizedDescription) } }
            } else {
                self.showUserActions(targetID: comment.author.id, targetType: "comment", anchor: anchor)
            }
        }
        display(); currentNavigationController?.pushSecondLevel(screen, animated: true)
    }

    private func openImageBrowser(tokens: [String], startIndex: Int) {
        let screen = ImageBrowserViewController(tokens: tokens, startIndex: startIndex)
        currentNavigationController?.pushSecondLevel(screen, animated: true)
    }

    private func openProfile(userID: String) {
        guard requireSignedIn() else { return }
        if userID == store.currentUserID { tabBarController?.selectedIndex = 3; return }
        let screen = OtherProfileViewController()
        let display = { [weak screen] in guard let screen else { return }; if let model = ViewModelAdapters.profile(userID: userID) { screen.display(profile: model) } else { screen.displayUnavailable("This user is blocked. Manage them in your blocklist.") } }
        screen.onBack = { [weak screen] in screen?.navigationController?.popViewController(animated: true) }; screen.onRetry = display
        screen.onMenu = { [weak self] anchor in self?.showUserActions(targetID: userID, targetType: "user", anchor: anchor) }
        screen.onFollow = { [weak self] in _ = try? self?.store.toggleFollow(userID: userID); display(); self?.refreshAll() }
        screen.onMessage = { [weak self, weak screen] in guard let self else { return }; guard let model = ViewModelAdapters.profile(userID: userID), model.canMessage else { screen?.showKinvaNotice(title: "Connect to Chat", message: "Follow each other to unlock messages."); return }; if let conversation = self.store.visibleConversations().first(where: { $0.participantIDs.contains(userID) }) { self.openChat(conversationID: conversation.id) } }
        screen.onFollowingList = { [weak self] in self?.openRelations(.following, userID: userID) }; screen.onFollowersList = { [weak self] in self?.openRelations(.followers, userID: userID) }
        screen.onPost = { [weak self] post in self?.openPost(id: post.id) }
        screen.onPostMenu = { [weak self] post, anchor in
            self?.showUserActions(targetID: post.author.id, targetType: "post", anchor: anchor)
        }
        display(); currentNavigationController?.pushSecondLevel(screen, animated: true)
    }

    private func showUserActions(targetID: String, targetType: String, anchor: UIView) {
        guard requireSignedIn() else { return }
        _ = anchor
        guard let source = currentNavigationController?.topViewController else { return }
        source.showKinvaActionSheet(items: [
            KinvaActionSheetItem(title: "Report") { [weak self] in self?.openReport(targetID: targetID, type: targetType) },
            KinvaActionSheetItem(title: "Block", style: .destructive) { [weak self, weak source] in
                source?.showConfirmation(title: "Block User", message: "Their content will be hidden throughout Kinva.", confirm: "Block") {
                    do { try self?.store.block(userID: targetID); self?.refreshAll(); source?.navigationController?.popToRootViewController(animated: true) } catch { source?.showLocalAlert(title: "Could not block", message: error.localizedDescription) }
                }
            },
            KinvaActionSheetItem(title: "Cancel", style: .cancel, handler: {})
        ])
    }

    private func openReport(targetID: String, type: String) {
        let screen = ReportViewController(targetID: targetID, targetType: type); screen.onBack = { [weak screen] in screen?.navigationController?.popViewController(animated: true) }
        screen.onReport = { [weak self, weak screen] reason, note in
            do {
                try self?.store.report(targetID: targetID, targetType: type, reason: reason.rawValue, note: note)
                screen?.showKinvaNotice(title: "Report Successful",
                                        message: "Thank you. Your report has been submitted.")
            } catch {
                screen?.showKinvaNotice(title: "Could Not Report", message: error.localizedDescription)
            }
        }
        currentNavigationController?.pushSecondLevel(screen, animated: true)
    }

    private func configureMessages(_ screen: MessagesListViewController) {
        screen.onRetry = { [weak self] in self?.refreshMessages() }; screen.onSystemNotifications = { [weak self] in self?.openNotifications() }; screen.onConversation = { [weak self] value in self?.openChat(conversationID: value.id) }; refreshMessages()
    }

    private func openChat(conversationID: String) {
        guard let conversation = store.visibleConversations().first(where: { $0.id == conversationID }) else { return }
        let screen = ChatViewController(); let participant = ViewModelAdapters.participant(for: conversation)
        let display = { [weak self, weak screen] in
            guard let self, let screen, let current = self.store.visibleConversations().first(where: { $0.id == conversationID }) else { return }
            let canSend = self.store.account.user.followingIDs.contains(participant.id) && (self.store.user(id: participant.id)?.followingIDs.contains(self.store.currentUserID) == true)
            let timestamp = current.messages.last.map { Self.chatTimeFormatter.string(from: $0.createdAt) }
            screen.display(participant: participant,
                           timestamp: timestamp,
                           messages: current.messages.map { ViewModelAdapters.chatMessage($0) },
                           canSend: canSend)
        }
        screen.onBack = { [weak screen] in screen?.navigationController?.popViewController(animated: true) }; screen.onRetry = display
        screen.onAuthor = { [weak self] id in self?.openProfile(userID: id) }
        screen.onMenu = { [weak self] anchor in self?.showUserActions(targetID: participant.id, targetType: "conversation", anchor: anchor) }
        screen.onSendText = { [weak self, weak screen] text in do { try self?.store.sendText(text, conversationID: conversationID); display(); self?.refreshMessages() } catch { screen?.showLocalAlert(title: "Could not send", message: error.localizedDescription) } }
        let handleRecording: (Result<LocalVoiceRecording, Error>) -> Void = { [weak self, weak screen] result in
            guard let self else { return }
                switch result {
                case .success(let recording):
                    do { try self.store.sendVoice(duration: recording.duration, token: recording.token, conversationID: conversationID); display(); self.refreshMessages() }
                    catch { screen?.showLocalAlert(title: "Could not save voice", message: error.localizedDescription) }
                case .failure(let error):
                    if case VoiceServiceError.notRecording = error { return }
                    if case VoiceServiceError.tooShort = error { screen?.showLocalAlert(title: "Keep holding", message: error.localizedDescription) }
                }
        }
        screen.onVoicePressBegan = { [weak screen] in
            LocalVoiceRecorderService.shared.begin(onFinished: handleRecording) { result in
                if case .failure(let error) = result { screen?.showLocalAlert(title: "Microphone unavailable", message: error.localizedDescription) }
            }
        }
        screen.onVoicePressEnded = { cancelled in
            LocalVoiceRecorderService.shared.end(cancelled: cancelled, completion: handleRecording)
        }
        screen.onPlayVoice = { message in
            guard let token = message.voiceToken else { return false }
            return LocalVoicePlayer.shared.toggle(token: token) { [weak screen] progress in
                screen?.updateVoiceProgress(messageID: message.id, progress: progress)
            }
        }
        display(); currentNavigationController?.pushSecondLevel(screen, animated: true)
    }

    private func openNotifications() {
        guard requireSignedIn() else { return }
        let screen = SystemNotificationsViewController(); screen.onBack = { [weak screen] in screen?.navigationController?.popViewController(animated: true) }; screen.onRetry = { [weak self, weak screen] in screen?.display(notifications: self?.store.visibleNotifications().map { ViewModelAdapters.notification($0) } ?? []) }; screen.display(notifications: store.visibleNotifications().map { ViewModelAdapters.notification($0) }); currentNavigationController?.pushSecondLevel(screen, animated: true)
    }

    private func configureProfile(_ screen: MyProfileViewController) {
        screen.onSettings = { [weak self] in self?.openSettings() }; screen.onEditProfile = { [weak self, weak screen] in self?.showProfileForm(mode: .editing, from: screen) }
        screen.onFollowing = { [weak self] in self?.openRelations(.following, userID: self?.store.currentUserID) }; screen.onFollowers = { [weak self] in self?.openRelations(.followers, userID: self?.store.currentUserID) }; screen.onRecharge = { [weak self] in self?.openRecharge() }
        screen.onSelectPost = { [weak self] item in self?.openPost(id: item.id) }
        screen.onDeletePost = { [weak self, weak screen] item in screen?.showConfirmation(title: "Delete Post", message: "Delete this post?", confirm: "Delete") { do { try self?.store.deletePost(id: item.id); self?.refreshAll() } catch { screen?.showLocalAlert(title: "Could not delete", message: error.localizedDescription) } } }
        screen.onSelectChallenge = { [weak self] item in if let value = self?.store.challenges.first(where: { $0.id == item.id }) { self?.openChallenge(value) } }
        screen.onDeleteChallenge = { [weak self, weak screen] item in screen?.showConfirmation(title: "Delete Challenge", message: "Delete this challenge?", confirm: "Delete") { do { try self?.store.deleteChallenge(id: item.id); self?.refreshAll() } catch { screen?.showLocalAlert(title: "Could not delete", message: error.localizedDescription) } } }
        refreshProfile()
    }

    private func openSettings() {
        let screen = SettingsViewController(); screen.onBack = { [weak screen] in screen?.navigationController?.popViewController(animated: true) }
        screen.onSelectItem = { [weak self, weak screen] item in
            guard let self, let screen else { return }
            switch item {
            case .privacyPolicy:
                self.openInternalWebPage(title: "Privacy Policy", from: screen)
            case .termsOfService:
                self.openInternalWebPage(title: "Terms of Service", from: screen)
            case .editProfile:
                self.showProfileForm(mode: .editing, from: screen)
            case .blacklist:
                self.openBlacklist()
            case .signOut:
                self.presentAccountConfirmation(.signOut, from: screen)
            case .deleteAccount:
                self.presentAccountConfirmation(.deleteAccount, from: screen)
            }
        }
        currentNavigationController?.pushSecondLevel(screen, animated: true)
    }

    private func openInternalWebPage(title: String, from source: UIViewController) {
        guard let url = URL(string: "https://www.baidu.com") else { return }
        let screen = InternalWebViewController(title: title, url: url)
        screen.onBack = { [weak screen] in
            screen?.navigationController?.popViewController(animated: true)
        }
        source.navigationController?.pushSecondLevel(screen, animated: true)
    }

    private func presentAccountConfirmation(_ kind: AccountConfirmationViewController.Kind, from source: UIViewController) {
        let confirmation = AccountConfirmationViewController(kind: kind); confirmation.onCancel = { [weak confirmation] in confirmation?.dismiss(animated: true) }; confirmation.onConfirm = { [weak self, weak confirmation] in guard let self else { return }; do { if kind == .signOut { self.store.signOut() } else { try self.store.deleteCurrentAccount() }; confirmation?.dismiss(animated: true) { self.showWelcome() } } catch { confirmation?.showLocalAlert(title: "Could not complete", message: error.localizedDescription) } }; source.present(confirmation, animated: true)
    }

    private func openRelations(_ kind: RelationListViewController.Kind, userID: String?) {
        let screen = RelationListViewController(kind: kind)
        let reloadRelations: () -> Void = { [weak self, weak screen] in
            guard let self, let screen else { return }
            let user = userID.flatMap(self.store.user(id:)) ?? self.store.account.user
            let ids = kind == .following ? user.followingIDs : user.followerIDs
            screen.setItems(self.store.visibleRelations(ids).map {
                RelationListViewController.Item(
                    id: $0.id,
                    displayName: $0.name,
                    avatarImage: kinvaAvatarImage(userID: $0.id),
                    isConnected: self.store.account.user.followingIDs.contains($0.id)
                )
            })
        }
        reloadRelations()
        screen.onBack = { [weak screen] in
            screen?.navigationController?.popViewController(animated: true)
        }
        screen.onSelectPerson = { [weak self] item in
            self?.openProfile(userID: item.id)
        }
        screen.onAction = { [weak self, weak screen] item in
            guard let self else { return }
            do {
                _ = try self.store.toggleFollow(userID: item.id)
                self.refreshAll()
                reloadRelations()
            } catch {
                screen?.showLocalAlert(title: "Could not update", message: error.localizedDescription)
            }
        }
        currentNavigationController?.pushSecondLevel(screen, animated: true)
    }

    private func openBlacklist() {
        let screen = BlacklistViewController()
        let reloadBlacklist: () -> Void = { [weak self, weak screen] in
            guard let self, let screen else { return }
            let values = self.store.account.blockedUserIDs.compactMap(self.store.user(id:))
            screen.setItems(values.map {
                RelationListViewController.Item(id: $0.id,
                                                displayName: $0.name,
                                                avatarImage: kinvaAvatarImage(userID: $0.id))
            })
        }
        reloadBlacklist()
        screen.onBack = { [weak screen] in
            screen?.navigationController?.popViewController(animated: true)
        }
        screen.onAction = { [weak self, weak screen] item in
            guard let self else { return }
            do {
                try self.store.unblock(userID: item.id)
                self.refreshAll()
                reloadBlacklist()
            } catch {
                screen?.showLocalAlert(title: "Could not unblock", message: error.localizedDescription)
            }
        }
        currentNavigationController?.pushSecondLevel(screen, animated: true)
    }

    private func openRecharge() {
        let screen = RechargeViewController()
        let purchaseManager = ConsumablePurchaseManager.shared
        screen.setBalance(store.account.diamondBalance)
        screen.onBack = { [weak screen] in
            screen?.navigationController?.popViewController(animated: true)
        }
        screen.onLoadProducts = { [weak screen] in
            screen?.showProductsLoading()
            purchaseManager.loadProducts { [weak screen] result in
                switch result {
                case .success(let products):
                    screen?.setTiers(products.map {
                        RechargeViewController.Tier(id: $0.identifier,
                                                    diamonds: $0.diamonds,
                                                    price: $0.displayPrice)
                    })
                case .failure(let error):
                    screen?.showProductsError(error.localizedDescription)
                }
            }
        }
        screen.onSelectTier = { [weak self, weak screen] tier in
            screen?.showConfirmation(title: "Recharge",
                                     message: "Add \(tier.diamonds) consumable diamonds for \(tier.price)?",
                                     confirm: "Continue") {
                screen?.setPurchaseLoading(true)
                purchaseManager.purchase(productID: tier.id) { [weak self, weak screen] result in
                    screen?.setPurchaseLoading(false)
                    switch result {
                    case .success(let diamonds):
                        screen?.setBalance(self?.store.account.diamondBalance ?? 0)
                        self?.refreshAll()
                        screen?.showLocalAlert(title: "Recharge successful",
                                               message: "\(diamonds) diamonds were added to your balance.")
                    case .failure(let error):
                        screen?.showLocalAlert(title: "Purchase not completed",
                                               message: error.localizedDescription)
                    }
                }
            }
        }
        currentNavigationController?.pushSecondLevel(screen, animated: true)
    }

    private var currentNavigationController: UINavigationController? {
        if let tabs = window.rootViewController as? UITabBarController { return tabs.selectedViewController as? UINavigationController }
        return window.rootViewController as? UINavigationController
    }

    private func refreshAll() { refreshExplore(); refreshMessages(); refreshProfile() }
    private func refreshExplore() { exploreScreen?.display(posts: store.visiblePosts().map { ViewModelAdapters.post($0) }, feed: .trending) }
    private func refreshMessages() { messagesScreen?.display(conversations: store.visibleConversations().map { ViewModelAdapters.conversation($0) }) }
    private func refreshProfile() {
        guard let screen = profileScreen else { return }
        let user = store.account.user
        let avatar = kinvaAvatarImage(userID: store.currentUserID)
        screen.configureProfile(
            name: user.name,
            followingCount: store.visibleRelations(user.followingIDs).count,
            followerCount: store.visibleRelations(user.followerIDs).count,
            balance: store.account.diamondBalance,
            avatar: avatar
        )
        screen.setPosts(store.posts.filter { $0.authorID == store.currentUserID }.map {
            MyProfileViewController.PostItem(
                id: $0.id,
                authorName: user.name,
                authorImage: avatar,
                imageTokens: $0.imageTokens,
                caption: $0.caption,
                topic: $0.topic
            )
        })
        screen.setChallenges(store.challenges.filter { $0.authorID == store.currentUserID }.map {
            MyProfileViewController.ChallengeItem(
                id: $0.id,
                title: $0.title,
                mediaTokens: $0.mediaTokens
            )
        })
        screen.setJoined(store.visibleChallenges().filter { $0.participantIDs.contains(store.currentUserID) }.map {
            MyProfileViewController.ChallengeItem(
                id: $0.id,
                title: $0.title,
                mediaTokens: $0.mediaTokens
            )
        })
    }
}

private extension DateFormatter {
    static let kinvaDay: DateFormatter = { let value = DateFormatter(); value.locale = Locale(identifier: "en_US_POSIX"); value.dateFormat = "yyyy-MM-dd"; return value }()
    static let chatTime: DateFormatter = {
        let value = DateFormatter()
        value.locale = Locale(identifier: "en_US_POSIX")
        value.dateFormat = "a hh:mm"
        return value
    }()
}

private extension AppCoordinator {
    static let chatTimeFormatter: DateFormatter = .chatTime
}
