import UIKit

final class OtherProfileViewController: BaseScrollViewController {
    var onBack: (() -> Void)?
    var onMenu: ((UIView) -> Void)?
    var onFollow: (() -> Void)?
    var onMessage: (() -> Void)?
    var onFollowingList: (() -> Void)?
    var onFollowersList: (() -> Void)?
    var onPost: ((SocialPostViewModel) -> Void)?
    var onPostMenu: ((SocialPostViewModel, UIView) -> Void)?
    var onRetry: (() -> Void)?

    private let nameLabel = UILabel()
    private let followingButton = UIButton(type: .system)
    private let followersButton = UIButton(type: .system)
    private let followButton = SocialPillButton(title: "Follow", filled: false)
    private let messageButton = SocialPillButton(title: "Message", filled: true)
    private let postsStack = UIStackView()
    private let coverImageView = UIImageView()
    private var profile: SocialProfileViewModel?

    override func viewDidLoad() {
        super.viewDidLoad()
        // The profile photo is an immersive header and must continue behind
        // the status bar. The controls inside it still use the safe area.
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        extendedLayoutIncludesOpaqueBars = true
        edgesForExtendedLayout = .all
        buildLayout()
        if profile != nil {
            applyCurrentProfile()
        } else {
            render(state: .loading)
        }
    }

    func display(profile: SocialProfileViewModel) {
        self.profile = profile
        applyCurrentProfile()
    }

    private func applyCurrentProfile() {
        guard let profile else {
            render(state: .loading)
            return
        }
        nameLabel.text = profile.user.name
        followingButton.setTitle("Following \(profile.followingCount)", for: .normal)
        followersButton.setTitle("Followers \(profile.followerCount)", for: .normal)
        updateCoverImage(userID: profile.user.id)
        applyFollowStyle(isFollowing: profile.isFollowing)
        // Keep this action tappable even when messaging is unavailable. The
        // coordinator explains that both users must follow each other.
        messageButton.isEnabled = true
        messageButton.alpha = 1
        messageButton.accessibilityHint = profile.canMessage
            ? "Opens the conversation"
            : "Follow each other to unlock messages"
        rebuildPosts(profile.posts)
        render(state: .content)
    }

    func displayLoading() { render(state: .loading) }
    func displayUnavailable(_ message: String) { render(state: .empty(message)) }
    func displayParseError(_ message: String = "This profile could not be read.") {
        render(state: .parseError(message), retry: onRetry)
    }

    private func buildLayout() {
        contentStack.spacing = 0
        let cover = UIView()
        cover.backgroundColor = UIColor(hex: 0xDADADA)
        cover.clipsToBounds = true
        coverImageView.contentMode = .scaleAspectFill
        coverImageView.clipsToBounds = true
        coverImageView.translatesAutoresizingMaskIntoConstraints = false
        cover.addSubview(coverImageView)
        NSLayoutConstraint.activate([
            coverImageView.topAnchor.constraint(equalTo: cover.topAnchor),
            coverImageView.leadingAnchor.constraint(equalTo: cover.leadingAnchor),
            coverImageView.trailingAnchor.constraint(equalTo: cover.trailingAnchor),
            coverImageView.bottomAnchor.constraint(equalTo: cover.bottomAnchor)
        ])
        // Preserve the original body position while extending the photo upward
        // through the former status-bar gap.
        cover.heightAnchor.constraint(equalToConstant: 424).isActive = true
        let back = floatingButton(symbol: "arrow.left")
        let menu = floatingButton(symbol: "line.3.horizontal")
        [back, menu].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; cover.addSubview($0) }
        NSLayoutConstraint.activate([
            back.topAnchor.constraint(equalTo: cover.safeAreaLayoutGuide.topAnchor, constant: 12),
            back.leadingAnchor.constraint(equalTo: cover.leadingAnchor, constant: 18),
            back.widthAnchor.constraint(equalToConstant: 42),
            back.heightAnchor.constraint(equalToConstant: 42),
            menu.topAnchor.constraint(equalTo: back.topAnchor),
            menu.trailingAnchor.constraint(equalTo: cover.trailingAnchor, constant: -18),
            menu.widthAnchor.constraint(equalToConstant: 42),
            menu.heightAnchor.constraint(equalToConstant: 42)
        ])
        back.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        menu.addTarget(self, action: #selector(menuTapped(_:)), for: .touchUpInside)

        let body = UIView()
        body.backgroundColor = .white
        body.layer.cornerRadius = 30
        body.layer.cornerCurve = .continuous
        body.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        nameLabel.font = AppTheme.font(28, .heavy)
        nameLabel.textColor = AppTheme.secondaryText
        [followingButton, followersButton].forEach {
            $0.setTitleColor(AppTheme.secondaryText, for: .normal)
            $0.titleLabel?.font = AppTheme.font(14, .semibold)
        }
        let stats = UIStackView(arrangedSubviews: [followingButton, followersButton, UIView()])
        stats.axis = .horizontal
        stats.spacing = 26
        let actions = UIStackView(arrangedSubviews: [followButton, messageButton])
        actions.axis = .horizontal
        actions.spacing = 16
        actions.distribution = .fillEqually
        let postTitle = UILabel()
        postTitle.text = "POST"
        postTitle.font = AppTheme.font(18, .bold)
        postTitle.textColor = AppTheme.text
        postsStack.axis = .vertical
        postsStack.spacing = 24
        let bodyStack = UIStackView(arrangedSubviews: [nameLabel, stats, actions, postTitle, postsStack])
        bodyStack.axis = .vertical
        bodyStack.alignment = .fill
        bodyStack.spacing = 12
        bodyStack.setCustomSpacing(24, after: actions)
        bodyStack.translatesAutoresizingMaskIntoConstraints = false
        body.addSubview(bodyStack)
        NSLayoutConstraint.activate([
            bodyStack.topAnchor.constraint(equalTo: body.topAnchor, constant: 16),
            bodyStack.leadingAnchor.constraint(equalTo: body.leadingAnchor, constant: 24),
            bodyStack.trailingAnchor.constraint(equalTo: body.trailingAnchor, constant: -24),
            bodyStack.bottomAnchor.constraint(equalTo: body.bottomAnchor, constant: -30)
        ])
        contentStack.addArrangedSubview(cover)
        contentStack.setCustomSpacing(-30, after: cover)
        contentStack.addArrangedSubview(body)

        followingButton.addTarget(self, action: #selector(followingTapped), for: .touchUpInside)
        followersButton.addTarget(self, action: #selector(followersTapped), for: .touchUpInside)
        followButton.addTarget(self, action: #selector(followTapped), for: .touchUpInside)
        messageButton.addTarget(self, action: #selector(messageTapped), for: .touchUpInside)
    }

    private func updateCoverImage(userID: String) {
        guard let image = kinvaAvatarImage(userID: userID) else {
            coverImageView.image = nil
            coverImageView.backgroundColor = UIColor(hex: 0xDADADA)
            return
        }
        coverImageView.image = image
        coverImageView.backgroundColor = .clear
    }

    private func rebuildPosts(_ posts: [SocialPostViewModel]) {
        postsStack.arrangedSubviews.forEach { view in
            postsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        if posts.isEmpty {
            let empty = UILabel()
            empty.text = "No posts yet."
            empty.font = AppTheme.font(14)
            empty.textColor = AppTheme.mutedText
            empty.textAlignment = .center
            empty.heightAnchor.constraint(equalToConstant: 100).isActive = true
            postsStack.addArrangedSubview(empty)
        } else {
            for post in posts {
                let card = SocialPostCardView()
                card.configure(with: post)
                card.addTarget(self, action: #selector(postTapped(_:)), for: .touchUpInside)
                card.accessibilityIdentifier = post.id
                card.onMore = { [weak self, weak card] in
                    guard let self, let card else { return }
                    self.onPostMenu?(post, card.moreButton)
                }
                postsStack.addArrangedSubview(card)
            }
        }
    }

    private func applyFollowStyle(isFollowing: Bool) {
        followButton.setTitle(isFollowing ? "Followed" : "Follow", for: .normal)
        followButton.setTitleColor(isFollowing ? UIColor(hex: 0xC2CBD0) : AppTheme.blue, for: .normal)
        followButton.layer.borderColor = (isFollowing ? UIColor(hex: 0xC2CBD0) : AppTheme.blue).cgColor
    }

    private func floatingButton(symbol: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(.symbol(symbol, size: 19, weight: .bold), for: .normal)
        button.tintColor = .white
        button.backgroundColor = .black
        button.round(11)
        return button
    }

    @objc private func backTapped() { onBack?() }
    @objc private func menuTapped(_ sender: UIButton) { onMenu?(sender) }
    @objc private func followingTapped() { onFollowingList?() }
    @objc private func followersTapped() { onFollowersList?() }
    @objc private func followTapped() { onFollow?() }
    @objc private func messageTapped() { onMessage?() }
    @objc private func postTapped(_ sender: SocialPostCardView) {
        guard let id = sender.accessibilityIdentifier,
              let post = profile?.posts.first(where: { $0.id == id }) else { return }
        onPost?(post)
    }
}
