import UIKit

func kinvaProfileFont(_ size: CGFloat,
                      weight: UIFont.Weight = .regular,
                      textStyle: UIFont.TextStyle = .body) -> UIFont {
    UIFontMetrics(forTextStyle: textStyle).scaledFont(for: AppTheme.font(size, weight))
}

func kinvaProfileLabel(text: String? = nil,
                       size: CGFloat,
                       weight: UIFont.Weight = .regular,
                       color: UIColor = AppTheme.text,
                       textStyle: UIFont.TextStyle = .body) -> UILabel {
    let label = UILabel()
    label.text = text
    label.textColor = color
    label.font = kinvaProfileFont(size, weight: weight, textStyle: textStyle)
    label.adjustsFontForContentSizeCategory = true
    return label
}

final class ProfileMenuRow: UIControl {
    let titleLabel = kinvaProfileLabel(size: 18, weight: .bold, textStyle: .headline)
    private let chevron = UIImageView(image: UIImage.symbol("chevron.right", size: 16, weight: .bold))

    init(title: String) {
        super.init(frame: .zero)
        titleLabel.text = title
        chevron.tintColor = .black
        chevron.contentMode = .scaleAspectFit
        [titleLabel, chevron].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 56),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 23),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12),
            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -23),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            chevron.heightAnchor.constraint(equalToConstant: 18)
        ])
        accessibilityTraits = .button
        accessibilityLabel = title
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class PersonListCell: UITableViewCell {
    static let reuseIdentifier = "PersonListCell"
    let avatarImageView = AvatarView(name: "?", size: 54)
    let nameLabel = kinvaProfileLabel(size: 24, weight: .bold, textStyle: .title2)
    let actionButton = UIButton(type: .system)
    var onAction: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.72

        actionButton.titleLabel?.font = kinvaProfileFont(30, weight: .bold, textStyle: .title1)
        actionButton.round(9)
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        [avatarImageView, nameLabel, actionButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 54),
            avatarImageView.heightAnchor.constraint(equalToConstant: 54),
            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 16),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            actionButton.leadingAnchor.constraint(greaterThanOrEqualTo: nameLabel.trailingAnchor, constant: 10),
            actionButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -19),
            actionButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            actionButton.widthAnchor.constraint(equalToConstant: 40),
            actionButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(name: String, image: UIImage?, actionSymbol: String, actionColor: UIColor, isEnabled: Bool = true) {
        nameLabel.text = name
        avatarImageView.setName(name)
        avatarImageView.setImage(image)
        actionButton.setTitle(nil, for: .normal)
        actionButton.setImage(UIImage.symbol(actionSymbol, size: 23, weight: .bold), for: .normal)
        actionButton.tintColor = .white
        actionButton.backgroundColor = actionColor
        actionButton.isEnabled = isEnabled
        actionButton.alpha = isEnabled ? 1 : 0.55
        actionButton.accessibilityLabel = actionSymbol == "plus" ? "Follow" : "Remove"
    }

    @objc private func actionTapped() { onAction?() }
}
