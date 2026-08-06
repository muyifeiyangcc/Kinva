import UIKit

final class SystemNotificationsViewController: BaseScrollViewController {
    var onBack: (() -> Void)?
    var onNotification: ((SystemNotificationViewModel) -> Void)?
    var onRemoveMissingNotification: ((SystemNotificationViewModel) -> Void)?
    var onRetry: (() -> Void)?

    private let notificationStack = UIStackView()
    private var notifications: [SystemNotificationViewModel] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        render(state: .content)
    }

    func display(notifications: [SystemNotificationViewModel]) {
        self.notifications = notifications
        rebuildRows()
        render(state: notifications.isEmpty ? .empty("No notifications yet.") : .content)
    }

    func displayLoading() { render(state: .loading) }

    func displayParseError(_ message: String = "Local notifications could not be read.") {
        render(state: .parseError(message), retry: onRetry)
    }

    func presentMissingContent(for notification: SystemNotificationViewModel) {
        let alert = UIAlertController(title: "Content unavailable",
                                      message: "This content no longer exists.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Keep", style: .cancel))
        alert.addAction(UIAlertAction(title: "Remove notification", style: .destructive) { [weak self] _ in
            self?.onRemoveMissingNotification?(notification)
        })
        present(alert, animated: true)
    }

    private func buildLayout() {
        contentStack.layoutMargins = UIEdgeInsets(top: 8, left: 20, bottom: 30, right: 18)
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.spacing = 12
        let header = AppHeaderView(title: "System")
        header.backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(header)
        notificationStack.axis = .vertical
        notificationStack.spacing = 18
        contentStack.addArrangedSubview(notificationStack)
    }

    private func rebuildRows() {
        notificationStack.arrangedSubviews.forEach { view in
            notificationStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        for (index, notification) in notifications.enumerated() {
            let row = SystemNotificationRowView(model: notification)
            row.tag = index
            row.addTarget(self, action: #selector(notificationTapped(_:)), for: .touchUpInside)
            notificationStack.addArrangedSubview(row)
        }
    }

    @objc private func backTapped() { onBack?() }
    @objc private func notificationTapped(_ sender: SystemNotificationRowView) {
        guard notifications.indices.contains(sender.tag) else { return }
        onNotification?(notifications[sender.tag])
    }
}

private final class SystemNotificationRowView: UIControl {
    init(model: SystemNotificationViewModel) {
        super.init(frame: .zero)
        let avatar = AvatarView(name: model.actor?.name ?? "K", size: 50, userID: model.actor?.id)
        let name = UILabel()
        name.text = model.actor?.name ?? "Kinva"
        name.font = AppTheme.font(18, .bold)
        name.textColor = AppTheme.secondaryText
        let body = UILabel()
        body.text = model.text
        body.font = AppTheme.font(13, .semibold)
        body.textColor = AppTheme.mutedText
        body.numberOfLines = 2
        let copy = UIStackView(arrangedSubviews: [name, body])
        copy.axis = .vertical
        copy.spacing = 3
        [avatar, copy].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0) }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 72),
            avatar.leadingAnchor.constraint(equalTo: leadingAnchor),
            avatar.centerYAnchor.constraint(equalTo: centerYAnchor),
            copy.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 13),
            copy.centerYAnchor.constraint(equalTo: avatar.centerYAnchor)
        ])
        if model.hasThumbnail {
            let thumbnail = UIView()
            thumbnail.backgroundColor = UIColor(hex: 0xF0D9E5)
            thumbnail.round(6)
            let icon = UIImageView(image: .symbol("photo", size: 18, weight: .medium))
            icon.tintColor = AppTheme.pink
            icon.translatesAutoresizingMaskIntoConstraints = false
            thumbnail.addSubview(icon)
            thumbnail.translatesAutoresizingMaskIntoConstraints = false
            addSubview(thumbnail)
            NSLayoutConstraint.activate([
                copy.trailingAnchor.constraint(lessThanOrEqualTo: thumbnail.leadingAnchor, constant: -10),
                thumbnail.trailingAnchor.constraint(equalTo: trailingAnchor),
                thumbnail.centerYAnchor.constraint(equalTo: centerYAnchor),
                thumbnail.widthAnchor.constraint(equalToConstant: 47),
                thumbnail.heightAnchor.constraint(equalToConstant: 68),
                icon.centerXAnchor.constraint(equalTo: thumbnail.centerXAnchor),
                icon.centerYAnchor.constraint(equalTo: thumbnail.centerYAnchor)
            ])
        } else {
            copy.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        }
        accessibilityLabel = "\(name.text ?? "Kinva"), \(model.text), \(model.timestamp)"
    }

    required init?(coder: NSCoder) { fatalError() }
}
