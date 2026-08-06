import UIKit

final class MyProfileSegmentControl: UIControl {
    private(set) var selectedIndex = 0
    private var buttons: [UIButton] = []
    private let selectionView = UIView()
    private var selectionLeading: NSLayoutConstraint?

    init(titles: [String]) {
        super.init(frame: .zero)
        backgroundColor = UIColor(hex: 0xE5E8EA)
        round(22)
        selectionView.backgroundColor = .white
        selectionView.round(20)
        selectionView.applyCardShadow()
        selectionView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(selectionView)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        for (index, title) in titles.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.setTitle(title, for: .normal)
            button.setTitleColor(AppTheme.text, for: .normal)
            button.titleLabel?.font = kinvaProfileFont(15, weight: .bold, textStyle: .subheadline)
            button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
            buttons.append(button)
            stack.addArrangedSubview(button)
        }

        let leading = selectionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3)
        selectionLeading = leading
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            selectionView.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            selectionView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            selectionView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 1 / CGFloat(max(titles.count, 1)), constant: -2),
            leading,
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        updateAccessibility()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !buttons.isEmpty else { return }
        selectionLeading?.constant = 3 + CGFloat(selectedIndex) * (bounds.width / CGFloat(buttons.count))
    }

    func setSelectedIndex(_ index: Int, animated: Bool) {
        guard buttons.indices.contains(index) else { return }
        selectedIndex = index
        layoutIfNeeded()
        selectionLeading?.constant = 3 + CGFloat(index) * (bounds.width / CGFloat(buttons.count))
        let changes = { self.layoutIfNeeded() }
        animated ? UIView.animate(withDuration: 0.22, animations: changes) : changes()
        updateAccessibility()
    }

    private func updateAccessibility() {
        for (index, button) in buttons.enumerated() {
            button.accessibilityTraits = index == selectedIndex ? [.button, .selected] : [.button]
        }
    }

    @objc private func buttonTapped(_ sender: UIButton) {
        setSelectedIndex(sender.tag, animated: true)
        sendActions(for: .valueChanged)
    }
}

private final class MyProfilePostCard: UIView {
    var onDelete: (() -> Void)?

    init(item: MyProfileViewController.PostItem) {
        super.init(frame: .zero)
        let authorAvatar = UIImageView(image: item.authorImage ?? kinvaDefaultAvatarImage(size: 40))
        authorAvatar.backgroundColor = .white
        authorAvatar.tintColor = kinvaDefaultAvatarColor()
        authorAvatar.contentMode = item.authorImage == nil ? .scaleAspectFit : .scaleAspectFill
        authorAvatar.clipsToBounds = true
        authorAvatar.round(20)
        let name = kinvaProfileLabel(text: item.authorName, size: 23, weight: .bold, textStyle: .title2)
        let delete = UIButton(type: .system)
        delete.tintColor = .black
        delete.setImage(UIImage(named: "delete_black")?.withRenderingMode(.alwaysOriginal) ?? UIImage.symbol("trash", size: 21, weight: .bold), for: .normal)
        delete.accessibilityLabel = "Delete post"
        delete.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        let heading = UIStackView(arrangedSubviews: [authorAvatar, name, UIView(), delete])
        heading.axis = .horizontal
        heading.alignment = .center
        heading.spacing = 12
        authorAvatar.widthAnchor.constraint(equalToConstant: 40).isActive = true
        authorAvatar.heightAnchor.constraint(equalToConstant: 40).isActive = true
        delete.widthAnchor.constraint(equalToConstant: 44).isActive = true

        let gallery = makeGallery(item: item)
        let caption = kinvaProfileLabel(text: item.caption, size: 16, weight: .semibold, color: AppTheme.secondaryText, textStyle: .body)
        caption.numberOfLines = 0
        let topic = UILabel()
        topic.text = "#\(item.topic)"
        topic.font = kinvaProfileFont(10, weight: .bold, textStyle: .caption2)
        topic.textColor = .white
        topic.backgroundColor = AppTheme.blue
        topic.textAlignment = .center
        topic.round(4)
        topic.heightAnchor.constraint(greaterThanOrEqualToConstant: 20).isActive = true
        topic.widthAnchor.constraint(lessThanOrEqualToConstant: 180).isActive = true

        let stack = UIStackView(arrangedSubviews: [heading, gallery, caption, topic])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        heading.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        gallery.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func makeGallery(item: MyProfileViewController.PostItem) -> UIView {
        let gallery = SocialPostMediaGridView()
        gallery.configure(tokens: item.imageTokens,
                          images: item.images,
                          count: max(1, item.imageCount))
        gallery.heightAnchor.constraint(equalTo: gallery.widthAnchor, multiplier: 0.54).isActive = true
        return gallery
    }

    @objc private func deleteTapped() { onDelete?() }
}

private final class MyProfileChallengeCard: UIView {
    var onDelete: (() -> Void)?

    init(item: MyProfileViewController.ChallengeItem, showsDelete: Bool) {
        super.init(frame: .zero)
        let initialImage = item.image ?? ChallengeVideoThumbnailProvider.cachedImage(tokens: item.mediaTokens)
        let image = UIImageView(image: initialImage)
        image.contentMode = .scaleAspectFill
        image.backgroundColor = .black
        image.clipsToBounds = true
        image.round(14)
        if initialImage == nil {
            ChallengeVideoThumbnailProvider.load(tokens: item.mediaTokens) { [weak image] thumbnail in
                guard let thumbnail else { return }
                image?.image = thumbnail
            }
        }
        let delete = UIButton(type: .system)
        delete.tintColor = .white
        delete.setImage(UIImage(named: "delete_white")?.withRenderingMode(.alwaysOriginal) ?? UIImage.symbol("trash", size: 16, weight: .bold), for: .normal)
        delete.backgroundColor = AppTheme.blue
        delete.round(15)
        delete.isHidden = !showsDelete
        delete.accessibilityLabel = "Delete challenge"
        delete.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        [image, delete].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0) }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalTo: widthAnchor, multiplier: 222.0 / 156.0),
            image.topAnchor.constraint(equalTo: topAnchor),
            image.leadingAnchor.constraint(equalTo: leadingAnchor),
            image.trailingAnchor.constraint(equalTo: trailingAnchor),
            image.bottomAnchor.constraint(equalTo: bottomAnchor),
            delete.topAnchor.constraint(equalTo: topAnchor),
            delete.trailingAnchor.constraint(equalTo: trailingAnchor),
            delete.widthAnchor.constraint(equalToConstant: 32),
            delete.heightAnchor.constraint(equalToConstant: 38)
        ])
        accessibilityLabel = item.title
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func deleteTapped() { onDelete?() }
}

final class MyProfileViewController: BaseScrollViewController {
    enum Segment: Int, CaseIterable {
        case posts
        case challenges
        case joined
    }

    struct PostItem {
        let id: String
        let authorName: String
        let authorImage: UIImage?
        let images: [UIImage]
        let imageTokens: [String]
        let caption: String
        let topic: String

        init(id: String, authorName: String, authorImage: UIImage? = nil, images: [UIImage] = [], imageTokens: [String] = [], caption: String, topic: String) {
            self.id = id
            self.authorName = authorName
            self.authorImage = authorImage
            self.images = images
            self.imageTokens = imageTokens
            self.caption = caption
            self.topic = topic
        }

        var resolvedImages: [UIImage] {
            if !images.isEmpty { return images }
            return imageTokens.prefix(3).compactMap { kinvaImage(token: $0) }
        }

        var imageCount: Int { max(images.count, imageTokens.count) }
    }

    struct ChallengeItem {
        let id: String
        let title: String
        let image: UIImage?
        let mediaTokens: [String]

        init(id: String, title: String, image: UIImage? = nil, mediaTokens: [String] = []) {
            self.id = id
            self.title = title
            self.image = image
            self.mediaTokens = mediaTokens
        }
    }

    var onSettings: (() -> Void)?
    var onEditProfile: (() -> Void)?
    var onFollowing: (() -> Void)?
    var onFollowers: (() -> Void)?
    var onRecharge: (() -> Void)?
    var onSelectPost: ((PostItem) -> Void)?
    var onDeletePost: ((PostItem) -> Void)?
    var onSelectChallenge: ((ChallengeItem) -> Void)?
    var onDeleteChallenge: ((ChallengeItem) -> Void)?

    let avatarImageView = UIImageView()
    let nameLabel = kinvaProfileLabel(size: 26, weight: .bold, textStyle: .title1)
    let followingButton = UIButton(type: .system)
    let followersButton = UIButton(type: .system)
    let balanceLabel = kinvaProfileLabel(size: 25, weight: .bold, color: .white, textStyle: .title2)

    private let segmentControl = MyProfileSegmentControl(titles: ["POSTS", "CHALLENGES", "JOINED"])
    private let itemsStack = UIStackView()
    private var posts: [PostItem] = []
    private var challenges: [ChallengeItem] = []
    private var joined: [ChallengeItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        contentStack.spacing = 0
        contentStack.addArrangedSubview(makeProfileHeader())
        contentStack.addArrangedSubview(makeRechargeBanner())

        let segmentHolder = UIView()
        segmentControl.translatesAutoresizingMaskIntoConstraints = false
        segmentHolder.addSubview(segmentControl)
        NSLayoutConstraint.activate([
            segmentHolder.heightAnchor.constraint(equalToConstant: 78),
            segmentControl.leadingAnchor.constraint(equalTo: segmentHolder.leadingAnchor, constant: 18),
            segmentControl.trailingAnchor.constraint(equalTo: segmentHolder.trailingAnchor, constant: -17),
            segmentControl.centerYAnchor.constraint(equalTo: segmentHolder.centerYAnchor)
        ])
        segmentControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        contentStack.addArrangedSubview(segmentHolder)

        itemsStack.axis = .vertical
        itemsStack.spacing = 12
        itemsStack.isLayoutMarginsRelativeArrangement = true
        itemsStack.layoutMargins = UIEdgeInsets(top: 0, left: 29, bottom: 20, right: 29)
        contentStack.addArrangedSubview(itemsStack)
        renderCurrentSegment()
    }

    func configureProfile(name: String, followingCount: Int, followerCount: Int, balance: Int, avatar: UIImage?) {
        nameLabel.text = name
        followingButton.setAttributedTitle(Self.statTitle(prefix: "Following", count: followingCount), for: .normal)
        followersButton.setAttributedTitle(Self.statTitle(prefix: "Followers", count: followerCount), for: .normal)
        balanceLabel.text = balance.formatted()
        avatarImageView.image = avatar ?? kinvaDefaultAvatarImage(size: 80)
        avatarImageView.contentMode = avatar == nil ? .scaleAspectFit : .scaleAspectFill
    }

    func setPosts(_ posts: [PostItem]) { self.posts = posts; renderIfVisible(.posts) }
    func setChallenges(_ challenges: [ChallengeItem]) { self.challenges = challenges; renderIfVisible(.challenges) }
    func setJoined(_ joined: [ChallengeItem]) { self.joined = joined; renderIfVisible(.joined) }

    func selectSegment(_ segment: Segment, animated: Bool = false) {
        segmentControl.setSelectedIndex(segment.rawValue, animated: animated)
        renderCurrentSegment()
    }

    private func makeProfileHeader() -> UIView {
        let holder = UIView()
        let title = kinvaProfileLabel(text: "M E", size: 28, weight: .bold, textStyle: .title1)
        title.textAlignment = .center
        title.accessibilityTraits = .header
        let settings = UIButton(type: .system)
        settings.setImage(UIImage(named: "setting")?.withRenderingMode(.alwaysOriginal) ?? UIImage.symbol("gearshape", size: 20, weight: .semibold), for: .normal)
        settings.tintColor = AppTheme.blue
        settings.backgroundColor = .clear
        settings.accessibilityLabel = "Settings"
        settings.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)

        avatarImageView.backgroundColor = .white
        avatarImageView.tintColor = kinvaDefaultAvatarColor()
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.round(40)
        avatarImageView.isUserInteractionEnabled = true
        avatarImageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(editProfileTapped)))
        nameLabel.minimumScaleFactor = 0.75
        nameLabel.adjustsFontSizeToFitWidth = true
        followingButton.contentHorizontalAlignment = .leading
        followersButton.contentHorizontalAlignment = .leading
        let stats = UIStackView(arrangedSubviews: [followingButton, followersButton])
        stats.axis = .horizontal
        stats.spacing = 18
        for button in [followingButton, followersButton] {
            button.setTitleColor(AppTheme.mutedText, for: .normal)
            button.titleLabel?.font = kinvaProfileFont(13, weight: .bold, textStyle: .footnote)
        }
        followingButton.addTarget(self, action: #selector(followingTapped), for: .touchUpInside)
        followersButton.addTarget(self, action: #selector(followersTapped), for: .touchUpInside)

        let infoStack = UIStackView(arrangedSubviews: [nameLabel, stats])
        infoStack.axis = .vertical
        infoStack.alignment = .leading
        infoStack.spacing = 7
        [title, settings, avatarImageView, infoStack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; holder.addSubview($0) }
        NSLayoutConstraint.activate([
            holder.heightAnchor.constraint(equalToConstant: 175),
            title.topAnchor.constraint(equalTo: holder.topAnchor, constant: 20),
            title.centerXAnchor.constraint(equalTo: holder.centerXAnchor),
            settings.topAnchor.constraint(equalTo: holder.topAnchor, constant: 17),
            settings.trailingAnchor.constraint(equalTo: holder.trailingAnchor, constant: -17),
            settings.widthAnchor.constraint(equalToConstant: 40),
            settings.heightAnchor.constraint(equalToConstant: 40),
            avatarImageView.leadingAnchor.constraint(equalTo: holder.leadingAnchor, constant: 21),
            avatarImageView.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 13),
            avatarImageView.widthAnchor.constraint(equalToConstant: 80),
            avatarImageView.heightAnchor.constraint(equalToConstant: 80),
            infoStack.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 18),
            infoStack.trailingAnchor.constraint(lessThanOrEqualTo: holder.trailingAnchor, constant: -18),
            infoStack.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor)
        ])
        return holder
    }

    private func makeRechargeBanner() -> UIView {
        let banner = UIControl()
        banner.clipsToBounds = true
        banner.addTarget(self, action: #selector(rechargeTapped), for: .touchUpInside)
        banner.accessibilityTraits = .button
        let background = UIImageView(image: UIImage(named: "me_bg"))
        background.contentMode = .scaleAspectFill
        background.clipsToBounds = true
        let caption = kinvaProfileLabel(text: "My Balance:", size: 14, weight: .bold, color: .white, textStyle: .subheadline)
        [background, caption, balanceLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; banner.addSubview($0) }
        NSLayoutConstraint.activate([
            banner.heightAnchor.constraint(equalToConstant: 100),
            background.topAnchor.constraint(equalTo: banner.topAnchor),
            background.leadingAnchor.constraint(equalTo: banner.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: banner.trailingAnchor),
            background.bottomAnchor.constraint(equalTo: banner.bottomAnchor),
            caption.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 22),
            caption.topAnchor.constraint(equalTo: banner.topAnchor, constant: 68),
            balanceLabel.leadingAnchor.constraint(equalTo: caption.trailingAnchor, constant: 8),
            balanceLabel.centerYAnchor.constraint(equalTo: caption.centerYAnchor)
        ])
        return banner
    }

    private func renderIfVisible(_ segment: Segment) {
        guard isViewLoaded, segmentControl.selectedIndex == segment.rawValue else { return }
        renderCurrentSegment()
    }

    private func renderCurrentSegment() {
        guard isViewLoaded else { return }
        itemsStack.arrangedSubviews.forEach { itemsStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        let segment = Segment(rawValue: segmentControl.selectedIndex) ?? .posts
        switch segment {
        case .posts:
            if posts.isEmpty { addEmptyState("No posts yet.") }
            for item in posts {
                let card = MyProfilePostCard(item: item)
                card.onDelete = { [weak self] in self?.onDeletePost?(item) }
                card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(postCardTapped(_:))))
                card.accessibilityIdentifier = item.id
                itemsStack.addArrangedSubview(card)
            }
        case .challenges:
            renderChallengeGrid(challenges, showsDelete: true)
        case .joined:
            renderChallengeGrid(joined, showsDelete: false)
        }
    }

    private func renderChallengeGrid(_ values: [ChallengeItem], showsDelete: Bool) {
        if values.isEmpty { addEmptyState(showsDelete ? "No challenges created yet." : "No joined challenges yet."); return }
        for start in stride(from: 0, to: values.count, by: 2) {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = 12
            for index in start..<min(start + 2, values.count) {
                let item = values[index]
                let card = MyProfileChallengeCard(item: item, showsDelete: showsDelete)
                card.onDelete = { [weak self] in self?.onDeleteChallenge?(item) }
                card.accessibilityIdentifier = item.id
                card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(challengeCardTapped(_:))))
                row.addArrangedSubview(card)
            }
            if row.arrangedSubviews.count == 1 {
                let placeholder = UIView()
                placeholder.backgroundColor = .clear
                placeholder.isUserInteractionEnabled = false
                placeholder.isAccessibilityElement = false
                row.addArrangedSubview(placeholder)
            }
            itemsStack.addArrangedSubview(row)
        }
    }

    private func addEmptyState(_ text: String) {
        let label = kinvaProfileLabel(text: text, size: 15, color: AppTheme.secondaryText, textStyle: .body)
        label.textAlignment = .center
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        itemsStack.addArrangedSubview(label)
    }

    @objc private func segmentChanged() { renderCurrentSegment() }
    @objc private func settingsTapped() { onSettings?() }
    @objc private func editProfileTapped() { onEditProfile?() }
    @objc private func followingTapped() { onFollowing?() }
    @objc private func followersTapped() { onFollowers?() }
    @objc private func rechargeTapped() { onRecharge?() }
    @objc private func postCardTapped(_ gesture: UITapGestureRecognizer) {
        guard let id = gesture.view?.accessibilityIdentifier, let item = posts.first(where: { $0.id == id }) else { return }
        onSelectPost?(item)
    }
    @objc private func challengeCardTapped(_ gesture: UITapGestureRecognizer) {
        guard let id = gesture.view?.accessibilityIdentifier else { return }
        let values = segmentControl.selectedIndex == Segment.challenges.rawValue ? challenges : joined
        guard let item = values.first(where: { $0.id == id }) else { return }
        onSelectChallenge?(item)
    }

    private static func statTitle(prefix: String, count: Int) -> NSAttributedString {
        let title = NSMutableAttributedString(
            string: "\(prefix) ",
            attributes: [
                .font: kinvaProfileFont(13, weight: .bold, textStyle: .footnote),
                .foregroundColor: AppTheme.mutedText
            ]
        )
        title.append(NSAttributedString(
            string: count.formatted(),
            attributes: [
                .font: kinvaProfileFont(13, weight: .bold, textStyle: .footnote),
                .foregroundColor: AppTheme.text
            ]
        ))
        return title
    }
}
