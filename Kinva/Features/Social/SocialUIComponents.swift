import UIKit

struct SocialAuthorViewModel: Hashable {
    let id: String
    let name: String
    var subtitle: String?
}

struct SocialPostViewModel: Hashable {
    let id: String
    let author: SocialAuthorViewModel
    var caption: String
    var topic: String
    var imageTokens: [String]
    var imageCount: Int
    var likeCount: Int
    var isLiked: Bool
}

struct SocialCommentViewModel: Hashable {
    let id: String
    let author: SocialAuthorViewModel
    let timestamp: String
    let body: String
    var canDelete: Bool
}

struct SocialProfileViewModel: Hashable {
    let user: SocialAuthorViewModel
    var followingCount: String
    var followerCount: String
    var isFollowing: Bool
    var canMessage: Bool
    var posts: [SocialPostViewModel]
}

enum SocialPlaceholderPalette {
    static let colors: [UIColor] = [
        UIColor(hex: 0xDCE7FF), UIColor(hex: 0xF5D5E4),
        UIColor(hex: 0xD6EEE6), UIColor(hex: 0xE7DDF7)
    ]
}

final class SocialImagePlaceholderView: UIView {
    private let icon = UIImageView(image: .symbol("figure.dance", size: 29, weight: .medium))

    init(index: Int = 0, cornerRadius: CGFloat = 16) {
        super.init(frame: .zero)
        backgroundColor = SocialPlaceholderPalette.colors[index % SocialPlaceholderPalette.colors.count]
        round(cornerRadius)
        icon.tintColor = AppTheme.blue.withAlphaComponent(0.45)
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        isAccessibilityElement = true
        accessibilityLabel = "Post image placeholder"
    }

    required init?(coder: NSCoder) { fatalError() }
}

final class SocialPostImageView: UIView {
    init(token: String?, image: UIImage? = nil, index: Int, cornerRadius: CGFloat) {
        super.init(frame: .zero)
        clipsToBounds = true
        round(cornerRadius)
        if let image = image ?? kinvaImage(token: token) {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: topAnchor),
                imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
                imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        } else {
            backgroundColor = SocialPlaceholderPalette.colors[index % SocialPlaceholderPalette.colors.count]
            let symbolName = index.isMultiple(of: 2) ? "figure.dance" : "figure.flexibility"
            let symbol = UIImageView(image: .symbol(symbolName, size: 34, weight: .medium))
            symbol.tintColor = AppTheme.blue.withAlphaComponent(0.42)
            symbol.translatesAutoresizingMaskIntoConstraints = false
            addSubview(symbol)
            NSLayoutConstraint.activate([
                symbol.centerXAnchor.constraint(equalTo: centerXAnchor),
                symbol.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
        }
    }

    required init?(coder: NSCoder) { fatalError() }
}

/// Shared Explore/Profile post gallery. Keeping the layout in one view ensures
/// one, two, three and multi-image posts render identically everywhere.
final class SocialPostMediaGridView: UIView {
    func configure(tokens: [String], images: [UIImage] = [], count: Int) {
        subviews.forEach { $0.removeFromSuperview() }
        let visibleCount = min(max(count, 1), 3)
        var mediaViews: [UIView] = []
        for index in 0..<visibleCount {
            let media = SocialPostImageView(token: tokens.indices.contains(index) ? tokens[index] : nil,
                                            image: images.indices.contains(index) ? images[index] : nil,
                                            index: index,
                                            cornerRadius: index == 0 ? 16 : 10)
            media.translatesAutoresizingMaskIntoConstraints = false
            addSubview(media)
            mediaViews.append(media)
        }

        guard let primary = mediaViews.first else { return }
        if visibleCount == 1 {
            NSLayoutConstraint.activate([
                primary.topAnchor.constraint(equalTo: topAnchor),
                primary.leadingAnchor.constraint(equalTo: leadingAnchor),
                primary.trailingAnchor.constraint(equalTo: trailingAnchor),
                primary.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
            return
        }

        let primaryMultiplier: CGFloat = visibleCount == 2 ? 0.5 : 0.68
        NSLayoutConstraint.activate([
            primary.topAnchor.constraint(equalTo: topAnchor),
            primary.leadingAnchor.constraint(equalTo: leadingAnchor),
            primary.bottomAnchor.constraint(equalTo: bottomAnchor),
            primary.widthAnchor.constraint(equalTo: widthAnchor, multiplier: primaryMultiplier, constant: -2.5)
        ])

        let secondary = mediaViews[1]
        NSLayoutConstraint.activate([
            secondary.topAnchor.constraint(equalTo: topAnchor),
            secondary.leadingAnchor.constraint(equalTo: primary.trailingAnchor, constant: 5),
            secondary.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        if visibleCount == 2 {
            secondary.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
            return
        }

        let third = mediaViews[2]
        NSLayoutConstraint.activate([
            secondary.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.5, constant: -2.5),
            third.topAnchor.constraint(equalTo: secondary.bottomAnchor, constant: 5),
            third.leadingAnchor.constraint(equalTo: secondary.leadingAnchor),
            third.trailingAnchor.constraint(equalTo: trailingAnchor),
            third.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        if count > 3 {
            let countLabel = UILabel()
            countLabel.text = "+\(count - 2)"
            countLabel.font = AppTheme.font(20, .bold)
            countLabel.textColor = .white
            countLabel.textAlignment = .center
            countLabel.backgroundColor = UIColor.black.withAlphaComponent(0.25)
            countLabel.translatesAutoresizingMaskIntoConstraints = false
            third.addSubview(countLabel)
            NSLayoutConstraint.activate([
                countLabel.topAnchor.constraint(equalTo: third.topAnchor),
                countLabel.leadingAnchor.constraint(equalTo: third.leadingAnchor),
                countLabel.trailingAnchor.constraint(equalTo: third.trailingAnchor),
                countLabel.bottomAnchor.constraint(equalTo: third.bottomAnchor)
            ])
        }
    }
}

final class SocialPostCardView: UIControl, UIGestureRecognizerDelegate {
    let moreButton = UIButton(type: .system)
    private let authorAvatar = AvatarView(name: "?", size: 30)
    private let authorButton = UIButton(type: .system)
    private let imageGrid = SocialPostMediaGridView()
    private let captionLabel = UILabel()
    private let topicLabel = UILabel()

    var onAuthor: (() -> Void)?
    var onMore: (() -> Void)?
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        authorAvatar.isUserInteractionEnabled = false
        authorButton.setTitleColor(AppTheme.text, for: .normal)
        authorButton.titleLabel?.font = AppTheme.font(20, .bold)
        authorButton.contentHorizontalAlignment = .leading
        moreButton.setImage(.symbol("ellipsis", size: 21, weight: .bold), for: .normal)
        moreButton.tintColor = AppTheme.text
        imageGrid.round(16)
        captionLabel.font = AppTheme.font(16, .semibold)
        captionLabel.textColor = AppTheme.secondaryText
        captionLabel.numberOfLines = 0
        topicLabel.font = AppTheme.font(10, .semibold)
        topicLabel.textColor = .white
        topicLabel.backgroundColor = AppTheme.blue
        topicLabel.textAlignment = .center
        topicLabel.round(4)

        let header = UIView()
        [authorAvatar, authorButton, moreButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            header.addSubview($0)
        }
        NSLayoutConstraint.activate([
            authorAvatar.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            authorAvatar.topAnchor.constraint(equalTo: header.topAnchor),
            authorAvatar.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            authorButton.leadingAnchor.constraint(equalTo: authorAvatar.trailingAnchor, constant: 10),
            authorButton.centerYAnchor.constraint(equalTo: authorAvatar.centerYAnchor),
            moreButton.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            moreButton.centerYAnchor.constraint(equalTo: authorAvatar.centerYAnchor),
            moreButton.widthAnchor.constraint(equalToConstant: 42),
            moreButton.heightAnchor.constraint(equalToConstant: 42),
            authorButton.trailingAnchor.constraint(lessThanOrEqualTo: moreButton.leadingAnchor, constant: -8)
        ])

        let stack = UIStackView(arrangedSubviews: [header, imageGrid, captionLabel, topicLabel])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.setCustomSpacing(8, after: imageGrid)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        imageGrid.translatesAutoresizingMaskIntoConstraints = false
        let tap = UITapGestureRecognizer(target: self, action: #selector(cardTapped))
        tap.delegate = self
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            imageGrid.widthAnchor.constraint(equalTo: stack.widthAnchor),
            imageGrid.heightAnchor.constraint(equalTo: imageGrid.widthAnchor, multiplier: 0.54),
            topicLabel.heightAnchor.constraint(equalToConstant: 24)
        ])
        authorButton.addTarget(self, action: #selector(authorTapped), for: .touchUpInside)
        moreButton.addTarget(self, action: #selector(moreTapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with model: SocialPostViewModel) {
        authorAvatar.setUser(id: model.author.id, name: model.author.name)
        authorButton.setTitle(model.author.name, for: .normal)
        captionLabel.text = model.caption
        topicLabel.text = model.topic.isEmpty ? nil : "  #\(model.topic)  "
        topicLabel.isHidden = model.topic.isEmpty
        imageGrid.configure(tokens: model.imageTokens, count: max(1, model.imageCount))
        accessibilityLabel = "Post by \(model.author.name). \(model.caption)"
    }

    @objc private func authorTapped() { onAuthor?() }
    @objc private func moreTapped() { onMore?() }
    @objc private func cardTapped() { onTap?() }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let touchedView = touch.view else { return true }
        return !(touchedView is UIButton)
    }
}

final class SocialPillButton: UIButton {
    init(title: String, filled: Bool) {
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        titleLabel?.font = AppTheme.font(16, .bold)
        layer.borderWidth = 2
        layer.borderColor = (filled ? AppTheme.blue : AppTheme.blue).cgColor
        backgroundColor = filled ? AppTheme.blue : .white
        setTitleColor(filled ? .white : AppTheme.blue, for: .normal)
        round(13)
        heightAnchor.constraint(equalToConstant: 48).isActive = true
    }

    required init?(coder: NSCoder) { fatalError() }
}
