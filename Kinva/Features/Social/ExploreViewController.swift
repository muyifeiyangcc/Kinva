import UIKit

final class ExploreViewController: BaseScrollViewController {
    enum Feed: Int { case trending, following }

    var onNotifications: (() -> Void)?
    var onCompose: (() -> Void)?
    var onPost: ((SocialPostViewModel) -> Void)?
    var onAuthor: ((SocialAuthorViewModel) -> Void)?
    var onPostMenu: ((SocialPostViewModel, UIView) -> Void)?
    var onFeedChanged: ((Feed) -> Void)?
    var onRetry: (() -> Void)?

    private let notificationButton = UIButton(type: .system)
    private let composeButton = UIButton(type: .system)
    private let feedControl = UISegmentedControl(items: ["TRENDING", "FOLLOWING"])
    private let postsStack = UIStackView()
    private var currentPosts: [SocialPostViewModel] = []
    private var currentFeed: Feed = .trending

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        feedControl.selectedSegmentIndex = currentFeed.rawValue
        rebuildPosts()
        renderCurrentState()
    }

    func display(posts: [SocialPostViewModel], feed: Feed) {
        currentPosts = posts
        currentFeed = feed
        guard isViewLoaded else { return }
        feedControl.selectedSegmentIndex = feed.rawValue
        rebuildPosts()
        renderCurrentState()
    }

    private func renderCurrentState() {
        render(state: .content)
        guard currentPosts.isEmpty else { return }
        let message = currentFeed == .following ? "Follow creators to see their posts here." : "No posts yet."
        let empty = UIView()
        empty.translatesAutoresizingMaskIntoConstraints = false
        let icon = UIImageView(image: .symbol("tray", size: 36, weight: .medium))
        icon.tintColor = AppTheme.blue
        let label = UILabel()
        label.text = message
        label.font = AppTheme.font(14)
        label.textColor = AppTheme.secondaryText
        label.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        empty.addSubview(stack)
        NSLayoutConstraint.activate([
            empty.heightAnchor.constraint(equalToConstant: 420),
            stack.centerXAnchor.constraint(equalTo: empty.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: empty.centerYAnchor)
        ])
        postsStack.addArrangedSubview(empty)
    }

    func displayLoading() { render(state: .loading) }

    func displayParseError(_ message: String = "Posts could not be read.") {
        render(state: .parseError(message), retry: onRetry)
    }

    private func buildLayout() {
        view.backgroundColor = UIColor(hex: 0xF5F7F9)
        scrollView.backgroundColor = view.backgroundColor
        contentView.backgroundColor = view.backgroundColor
        scrollView.showsVerticalScrollIndicator = false
        contentStack.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 36, right: 20)
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.spacing = 18

        let header = UIView()
        notificationButton.setImage(.symbol("bell", size: 19), for: .normal)
        composeButton.setImage(.symbol("plus.circle", size: 20), for: .normal)
        [notificationButton, composeButton].forEach {
            $0.tintColor = AppTheme.text
            $0.backgroundColor = .white
            $0.layer.borderColor = UIColor(hex: 0xD7DDE2).cgColor
            $0.layer.borderWidth = 1
            $0.round(11)
        }
        let title = UILabel()
        title.text = "E X P L O R E"
        title.font = AppTheme.font(24, .bold)
        title.textColor = AppTheme.text
        title.textAlignment = .center
        [notificationButton, title, composeButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            header.addSubview($0)
        }
        NSLayoutConstraint.activate([
            header.heightAnchor.constraint(equalToConstant: 60),
            notificationButton.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            notificationButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            notificationButton.widthAnchor.constraint(equalToConstant: 42),
            notificationButton.heightAnchor.constraint(equalToConstant: 42),
            composeButton.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            composeButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            composeButton.widthAnchor.constraint(equalToConstant: 42),
            composeButton.heightAnchor.constraint(equalToConstant: 42),
            title.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            title.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            title.leadingAnchor.constraint(greaterThanOrEqualTo: notificationButton.trailingAnchor, constant: 8),
            title.trailingAnchor.constraint(lessThanOrEqualTo: composeButton.leadingAnchor, constant: -8)
        ])

        feedControl.selectedSegmentIndex = Feed.trending.rawValue
        feedControl.selectedSegmentTintColor = .white
        feedControl.backgroundColor = UIColor(hex: 0xE8EBED)
        feedControl.layer.cornerRadius = 22
        feedControl.layer.masksToBounds = true
        feedControl.setTitleTextAttributes([.font: AppTheme.font(14, .bold), .foregroundColor: AppTheme.text], for: .normal)
        feedControl.setTitleTextAttributes([.font: AppTheme.font(14, .bold), .foregroundColor: AppTheme.text], for: .selected)
        feedControl.heightAnchor.constraint(equalToConstant: 44).isActive = true

        postsStack.axis = .vertical
        postsStack.spacing = 20
        contentStack.addArrangedSubview(header)
        contentStack.addArrangedSubview(feedControl)
        contentStack.addArrangedSubview(postsStack)

        notificationButton.accessibilityLabel = "System notifications"
        composeButton.accessibilityLabel = "Create post"
        notificationButton.addTarget(self, action: #selector(notificationsTapped), for: .touchUpInside)
        composeButton.addTarget(self, action: #selector(composeTapped), for: .touchUpInside)
        feedControl.addTarget(self, action: #selector(feedChanged), for: .valueChanged)
    }

    private func rebuildPosts() {
        postsStack.arrangedSubviews.forEach { view in
            postsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        for (index, post) in currentPosts.enumerated() {
            let card = SocialPostCardView()
            card.configure(with: post)
            card.tag = index
            card.onTap = { [weak self] in self?.onPost?(post) }
            card.onAuthor = { [weak self] in self?.onAuthor?(post.author) }
            card.onMore = { [weak self, weak card] in
                guard let self, let card else { return }
                self.onPostMenu?(post, card.moreButton)
            }
            postsStack.addArrangedSubview(card)
        }
    }

    @objc private func notificationsTapped() { onNotifications?() }
    @objc private func composeTapped() { onCompose?() }
    @objc private func feedChanged() {
        guard let feed = Feed(rawValue: feedControl.selectedSegmentIndex) else { return }
        onFeedChanged?(feed)
    }
}
