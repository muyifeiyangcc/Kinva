import UIKit

final class PostDetailViewController: UIViewController, UIScrollViewDelegate {
    var onBack: (() -> Void)?
    var onMenu: ((UIView) -> Void)?
    var onAuthor: ((SocialAuthorViewModel) -> Void)?
    var onTopic: ((String) -> Void)?
    var onLike: (() -> Void)?
    var onSendComment: ((String) -> Bool)?
    var onCommentMenu: ((SocialCommentViewModel, UIView) -> Void)?
    var onImageTap: (([String], Int) -> Void)?

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let hero = UIView()
    private let heroPager = UIScrollView()
    private let heroMediaStack = UIStackView()
    private let pageLabel = UILabel()
    private let body = UIView()
    private let authorAvatar = AvatarView(name: "?", size: 32)
    private let authorButton = UIButton(type: .system)
    private let captionLabel = UILabel()
    private let topicButton = UIButton(type: .system)
    private let commentsStack = UIStackView()
    private let emptyCommentsLabel = UILabel()
    private let composer = UIView()
    private let commentField = UITextField()
    private let sendButton = UIButton(type: .system)
    private let likeButton = UIButton(type: .system)
    private var post: SocialPostViewModel?
    private var comments: [SocialCommentViewModel] = []
    private var pendingImageIndex = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        applyCurrentState()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard heroPager.bounds.width > 0 else { return }
        let offset = CGFloat(pendingImageIndex) * heroPager.bounds.width
        if abs(heroPager.contentOffset.x - offset) > 0.5 {
            heroPager.setContentOffset(CGPoint(x: offset, y: 0), animated: false)
        }
    }

    func display(post: SocialPostViewModel, comments: [SocialCommentViewModel], imageIndex: Int = 0) {
        self.post = post
        self.comments = comments
        pendingImageIndex = imageIndex
        guard isViewLoaded else { return }
        applyCurrentState()
    }

    private func applyCurrentState() {
        guard let post else { return }
        authorAvatar.setUser(id: post.author.id, name: post.author.name)
        authorButton.setTitle(post.author.name, for: .normal)
        captionLabel.text = post.caption
        topicButton.setTitle(post.topic.isEmpty ? nil : "#\(post.topic)", for: .normal)
        topicButton.isHidden = post.topic.isEmpty
        let currentPage = min(pendingImageIndex + 1, max(post.imageCount, 1))
        pageLabel.text = String(format: "%02d/%02d", currentPage, max(post.imageCount, 1))
        replaceHeroMedia(tokens: post.imageTokens, selectedIndex: pendingImageIndex)
        likeButton.setImage(.symbol(post.isLiked ? "heart.fill" : "heart", size: 23, weight: .bold), for: .normal)
        likeButton.backgroundColor = post.isLiked ? AppTheme.pink : UIColor(hex: 0xA2A2A2)
        likeButton.accessibilityLabel = post.isLiked ? "Unlike post" : "Like post"
        rebuildComments()
    }

    func updateLike(isLiked: Bool, count: Int) {
        post?.isLiked = isLiked
        post?.likeCount = count
        likeButton.setImage(.symbol(isLiked ? "heart.fill" : "heart", size: 23, weight: .bold), for: .normal)
        likeButton.backgroundColor = isLiked ? AppTheme.pink : UIColor(hex: 0xA2A2A2)
    }

    private func buildLayout() {
        view.backgroundColor = AppTheme.background
        navigationController?.setNavigationBarHidden(true, animated: false)
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        scrollView.contentInsetAdjustmentBehavior = .never
        [scrollView, contentView, hero, body, composer].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(hero)
        contentView.addSubview(body)
        view.addSubview(composer)

        heroPager.translatesAutoresizingMaskIntoConstraints = false
        heroPager.isPagingEnabled = true
        heroPager.showsHorizontalScrollIndicator = false
        heroPager.contentInsetAdjustmentBehavior = .never
        heroPager.delegate = self
        heroPager.alwaysBounceHorizontal = false
        heroMediaStack.axis = .horizontal
        heroMediaStack.alignment = .fill
        heroMediaStack.distribution = .fill
        heroMediaStack.spacing = 0
        heroMediaStack.translatesAutoresizingMaskIntoConstraints = false
        heroPager.addSubview(heroMediaStack)
        hero.insertSubview(heroPager, at: 0)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: composer.topAnchor, constant: -6),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            hero.topAnchor.constraint(equalTo: contentView.topAnchor),
            hero.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hero.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hero.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.52),
            heroPager.topAnchor.constraint(equalTo: hero.topAnchor),
            heroPager.leadingAnchor.constraint(equalTo: hero.leadingAnchor),
            heroPager.trailingAnchor.constraint(equalTo: hero.trailingAnchor),
            heroPager.bottomAnchor.constraint(equalTo: hero.bottomAnchor),
            heroMediaStack.topAnchor.constraint(equalTo: heroPager.contentLayoutGuide.topAnchor),
            heroMediaStack.leadingAnchor.constraint(equalTo: heroPager.contentLayoutGuide.leadingAnchor),
            heroMediaStack.trailingAnchor.constraint(equalTo: heroPager.contentLayoutGuide.trailingAnchor),
            heroMediaStack.bottomAnchor.constraint(equalTo: heroPager.contentLayoutGuide.bottomAnchor),
            heroMediaStack.heightAnchor.constraint(equalTo: heroPager.frameLayoutGuide.heightAnchor),
            body.topAnchor.constraint(equalTo: hero.bottomAnchor, constant: -28),
            body.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            body.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            composer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            composer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            composer.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -8),
            composer.heightAnchor.constraint(equalToConstant: 62)
        ])
        body.backgroundColor = .white
        body.layer.cornerRadius = 28
        body.layer.cornerCurve = .continuous
        body.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        let backButton = floatingButton(symbol: "arrow.left")
        let menuButton = floatingButton(symbol: "line.3.horizontal")
        pageLabel.font = AppTheme.font(28, .heavy)
        pageLabel.textColor = .white
        pageLabel.textAlignment = .right
        [backButton, menuButton, pageLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            hero.addSubview($0)
        }
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backButton.leadingAnchor.constraint(equalTo: hero.leadingAnchor, constant: 20),
            backButton.widthAnchor.constraint(equalToConstant: 42),
            backButton.heightAnchor.constraint(equalToConstant: 42),
            menuButton.topAnchor.constraint(equalTo: backButton.topAnchor),
            menuButton.trailingAnchor.constraint(equalTo: hero.trailingAnchor, constant: -16),
            menuButton.widthAnchor.constraint(equalToConstant: 42),
            menuButton.heightAnchor.constraint(equalToConstant: 42),
            pageLabel.trailingAnchor.constraint(equalTo: hero.trailingAnchor, constant: -22),
            pageLabel.bottomAnchor.constraint(equalTo: hero.bottomAnchor, constant: -42)
        ])
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        menuButton.addTarget(self, action: #selector(menuTapped(_:)), for: .touchUpInside)

        authorButton.setTitleColor(AppTheme.text, for: .normal)
        authorButton.titleLabel?.font = AppTheme.font(20, .bold)
        authorButton.contentHorizontalAlignment = .leading
        authorButton.addTarget(self, action: #selector(authorTapped), for: .touchUpInside)
        let authorRow = UIStackView(arrangedSubviews: [authorAvatar, authorButton])
        authorRow.axis = .horizontal
        authorRow.alignment = .center
        authorRow.spacing = 8
        captionLabel.font = AppTheme.font(20, .bold)
        captionLabel.textColor = AppTheme.text
        captionLabel.numberOfLines = 0
        topicButton.setTitleColor(.white, for: .normal)
        topicButton.backgroundColor = AppTheme.blue
        topicButton.titleLabel?.font = AppTheme.font(11, .semibold)
        topicButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        topicButton.round(5)
        topicButton.addTarget(self, action: #selector(topicTapped), for: .touchUpInside)
        let commentsTitle = UILabel()
        commentsTitle.text = "COMMENT"
        commentsTitle.font = AppTheme.font(20, .bold)
        commentsTitle.textColor = AppTheme.text
        commentsStack.axis = .vertical
        commentsStack.spacing = 18
        emptyCommentsLabel.text = "No comments yet. Start the conversation."
        emptyCommentsLabel.font = AppTheme.font(14)
        emptyCommentsLabel.textColor = AppTheme.mutedText
        emptyCommentsLabel.numberOfLines = 0
        let bodyStack = UIStackView(arrangedSubviews: [authorRow, captionLabel, topicButton, commentsTitle, commentsStack, emptyCommentsLabel])
        bodyStack.axis = .vertical
        bodyStack.alignment = .leading
        bodyStack.spacing = 12
        bodyStack.setCustomSpacing(18, after: topicButton)
        bodyStack.translatesAutoresizingMaskIntoConstraints = false
        body.addSubview(bodyStack)
        NSLayoutConstraint.activate([
            bodyStack.topAnchor.constraint(equalTo: body.topAnchor, constant: 18),
            bodyStack.leadingAnchor.constraint(equalTo: body.leadingAnchor, constant: 22),
            bodyStack.trailingAnchor.constraint(equalTo: body.trailingAnchor, constant: -22),
            bodyStack.bottomAnchor.constraint(equalTo: body.bottomAnchor, constant: -24),
            authorRow.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
            commentsStack.widthAnchor.constraint(equalTo: bodyStack.widthAnchor)
        ])

        composer.backgroundColor = .clear
        let input = UIView()
        input.backgroundColor = .white
        input.layer.borderColor = AppTheme.text.cgColor
        input.layer.borderWidth = 2
        input.round(20)
        let inputIcon = UIImageView(image: .symbol("pencil", size: 16, weight: .bold))
        inputIcon.tintColor = AppTheme.secondaryText
        commentField.placeholder = "Say something…"
        commentField.font = AppTheme.font(13, .semibold)
        commentField.returnKeyType = .send
        commentField.delegate = self
        sendButton.setImage(.symbol("paperplane.fill", size: 20), for: .normal)
        sendButton.tintColor = AppTheme.text
        likeButton.tintColor = .white
        likeButton.backgroundColor = post?.isLiked == true ? AppTheme.pink : UIColor(hex: 0xA2A2A2)
        likeButton.layer.borderColor = AppTheme.text.cgColor
        likeButton.layer.borderWidth = 2
        likeButton.round(18)
        [input, likeButton].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; composer.addSubview($0) }
        [inputIcon, commentField, sendButton].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; input.addSubview($0) }
        NSLayoutConstraint.activate([
            input.leadingAnchor.constraint(equalTo: composer.leadingAnchor),
            input.topAnchor.constraint(equalTo: composer.topAnchor),
            input.bottomAnchor.constraint(equalTo: composer.bottomAnchor),
            input.trailingAnchor.constraint(equalTo: likeButton.leadingAnchor, constant: -8),
            inputIcon.leadingAnchor.constraint(equalTo: input.leadingAnchor, constant: 16),
            inputIcon.centerYAnchor.constraint(equalTo: input.centerYAnchor),
            inputIcon.widthAnchor.constraint(equalToConstant: 18),
            inputIcon.heightAnchor.constraint(equalToConstant: 18),
            commentField.leadingAnchor.constraint(equalTo: inputIcon.trailingAnchor, constant: 8),
            commentField.centerYAnchor.constraint(equalTo: input.centerYAnchor),
            sendButton.leadingAnchor.constraint(equalTo: commentField.trailingAnchor, constant: 8),
            sendButton.trailingAnchor.constraint(equalTo: input.trailingAnchor, constant: -8),
            sendButton.centerYAnchor.constraint(equalTo: input.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 32),
            sendButton.heightAnchor.constraint(equalToConstant: 44),
            likeButton.trailingAnchor.constraint(equalTo: composer.trailingAnchor),
            likeButton.centerYAnchor.constraint(equalTo: composer.centerYAnchor),
            likeButton.widthAnchor.constraint(equalToConstant: 62),
            likeButton.heightAnchor.constraint(equalToConstant: 62)
        ])
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        likeButton.addTarget(self, action: #selector(likeTapped), for: .touchUpInside)
    }

    private func replaceHeroMedia(tokens: [String], selectedIndex: Int) {
        pendingImageIndex = selectedIndex
        heroMediaStack.arrangedSubviews.forEach { view in
            heroMediaStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        let visibleTokens = tokens.isEmpty ? [""] : tokens
        for (index, token) in visibleTokens.enumerated() {
            let media = HeroMediaPageView(token: token.isEmpty ? nil : token, index: index)
            media.translatesAutoresizingMaskIntoConstraints = false
            media.onTap = { [weak self] in
                guard let self else { return }
                self.onImageTap?(tokens, index)
            }
            heroMediaStack.addArrangedSubview(media)
            media.widthAnchor.constraint(equalTo: heroPager.frameLayoutGuide.widthAnchor).isActive = true
        }
        let safeIndex = min(max(selectedIndex, 0), max(visibleTokens.count - 1, 0))
        view.layoutIfNeeded()
        heroPager.setContentOffset(CGPoint(x: CGFloat(safeIndex) * heroPager.bounds.width, y: 0), animated: false)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === heroPager else { return }
        updatePageLabel(for: scrollView)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard scrollView === heroPager, !decelerate else { return }
        updatePageLabel(for: scrollView)
    }

    private func updatePageLabel(for scrollView: UIScrollView) {
        let index = Int(round(scrollView.contentOffset.x / max(scrollView.bounds.width, 1)))
        pendingImageIndex = max(0, min(index, max((post?.imageCount ?? 1) - 1, 0)))
        pageLabel.text = String(format: "%02d/%02d", index + 1, max(post?.imageCount ?? 1, 1))
    }

    private func rebuildComments() {
        commentsStack.arrangedSubviews.forEach { view in
            commentsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        emptyCommentsLabel.isHidden = !comments.isEmpty
        for comment in comments {
            let row = CommentRowView(comment: comment)
            row.onMenu = { [weak self, weak row] in
                guard let self, let row else { return }
                self.onCommentMenu?(comment, row.menuButton)
            }
            commentsStack.addArrangedSubview(row)
        }
    }

    private func floatingButton(symbol: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(.symbol(symbol, size: 19, weight: .bold), for: .normal)
        button.tintColor = .white
        button.backgroundColor = .black
        button.round(11)
        return button
    }

    @objc private func backTapped() {
        if let onBack { onBack() } else { navigationController?.popViewController(animated: true) }
    }
    @objc private func menuTapped(_ sender: UIButton) { onMenu?(sender) }
    @objc private func authorTapped() { if let author = post?.author { onAuthor?(author) } }
    @objc private func topicTapped() { if let topic = post?.topic, !topic.isEmpty { onTopic?(topic) } }
    @objc private func likeTapped() { onLike?() }
    @objc private func sendTapped() {
        guard let text = commentField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
        if onSendComment?(text) == true {
            commentField.text = nil
            commentField.resignFirstResponder()
        }
    }
}

extension PostDetailViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendTapped()
        return false
    }
}

private final class CommentRowView: UIView {
    let menuButton = UIButton(type: .system)
    var onMenu: (() -> Void)?

    init(comment: SocialCommentViewModel) {
        super.init(frame: .zero)
        let avatar = AvatarView(name: comment.author.name, size: 38, userID: comment.author.id)
        let name = UILabel()
        name.text = comment.author.name
        name.font = AppTheme.font(14, .bold)
        name.textColor = AppTheme.text
        let time = UILabel()
        time.text = comment.timestamp
        time.font = AppTheme.font(10)
        time.textColor = AppTheme.mutedText
        let body = UILabel()
        body.text = comment.body
        body.font = AppTheme.font(12, .semibold)
        body.textColor = AppTheme.text
        body.numberOfLines = 0
        menuButton.setImage(.symbol("ellipsis", size: 16, weight: .bold), for: .normal)
        menuButton.tintColor = AppTheme.text
        let copy = UIStackView(arrangedSubviews: [name, time, body])
        copy.axis = .vertical
        copy.spacing = 3
        [avatar, copy, menuButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            avatar.topAnchor.constraint(equalTo: topAnchor),
            avatar.leadingAnchor.constraint(equalTo: leadingAnchor),
            copy.topAnchor.constraint(equalTo: topAnchor),
            copy.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 10),
            copy.bottomAnchor.constraint(equalTo: bottomAnchor),
            menuButton.leadingAnchor.constraint(equalTo: copy.trailingAnchor, constant: 8),
            menuButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            menuButton.centerYAnchor.constraint(equalTo: topAnchor, constant: 18),
            menuButton.widthAnchor.constraint(equalToConstant: 34),
            menuButton.heightAnchor.constraint(equalToConstant: 34)
        ])
        menuButton.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError() }
    @objc private func menuTapped() { onMenu?() }
}

private final class HeroMediaPageView: UIControl {
    var onTap: (() -> Void)?

    init(token: String?, index: Int) {
        super.init(frame: .zero)
        isAccessibilityElement = true
        accessibilityLabel = "Post image \(index + 1)"
        let media = SocialPostImageView(token: token, index: index, cornerRadius: 0)
        media.translatesAutoresizingMaskIntoConstraints = false
        addSubview(media)
        NSLayoutConstraint.activate([
            media.topAnchor.constraint(equalTo: topAnchor),
            media.leadingAnchor.constraint(equalTo: leadingAnchor),
            media.trailingAnchor.constraint(equalTo: trailingAnchor),
            media.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapped() { onTap?() }
}
