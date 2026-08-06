import UIKit

struct KinvaActionSheetItem {
    enum Style {
        case normal
        case destructive
        case cancel
    }

    let title: String
    let style: Style
    let handler: () -> Void

    init(title: String, style: Style = .normal, handler: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.handler = handler
    }
}

final class KinvaActionSheetViewController: UIViewController {
    private let items: [KinvaActionSheetItem]
    private let sheetView = UIView()
    private let stack = UIStackView()
    private let backgroundButton = UIButton(type: .custom)

    init(items: [KinvaActionSheetItem]) {
        self.items = items
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        backgroundButton.translatesAutoresizingMaskIntoConstraints = false
        backgroundButton.backgroundColor = UIColor.black.withAlphaComponent(0.48)
        backgroundButton.alpha = 0
        backgroundButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        view.addSubview(backgroundButton)

        sheetView.translatesAutoresizingMaskIntoConstraints = false
        sheetView.backgroundColor = .white
        sheetView.clipsToBounds = true
        sheetView.round(24)
        sheetView.alpha = 0
        view.addSubview(sheetView)

        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        sheetView.addSubview(stack)

        NSLayoutConstraint.activate([
            backgroundButton.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundButton.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            sheetView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            sheetView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            sheetView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),

            stack.topAnchor.constraint(equalTo: sheetView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: sheetView.bottomAnchor)
        ])

        for (index, item) in items.enumerated() {
            let row = makeRow(title: item.title, style: item.style, index: index)
            stack.addArrangedSubview(row)
            if index < items.count - 1 {
                let separator = UIView()
                separator.translatesAutoresizingMaskIntoConstraints = false
                separator.backgroundColor = UIColor(hex: 0xE8E8E8)
                separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
                stack.addArrangedSubview(separator)
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.layoutIfNeeded()
        sheetView.transform = CGAffineTransform(translationX: 0, y: sheetView.bounds.height + 24)
        backgroundButton.alpha = 0
        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut]) {
            self.sheetView.transform = .identity
            self.sheetView.alpha = 1
            self.backgroundButton.alpha = 1
        }
    }

    private func dismissSheet(completion: (() -> Void)? = nil) {
        view.layoutIfNeeded()
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseIn]) {
            self.sheetView.transform = CGAffineTransform(translationX: 0, y: self.sheetView.bounds.height + 24)
            self.sheetView.alpha = 0
            self.backgroundButton.alpha = 0
        } completion: { _ in
            self.dismiss(animated: false, completion: completion)
        }
    }

    private func makeRow(title: String, style: KinvaActionSheetItem.Style, index: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = AppTheme.font(16, .bold)
        button.setTitleColor(actionColor(style), for: .normal)
        button.backgroundColor = .clear
        button.tag = index
        button.addTarget(self, action: #selector(actionTapped(_:)), for: .touchUpInside)
        button.heightAnchor.constraint(equalToConstant: 52).isActive = true
        return button
    }

    private func actionColor(_ style: KinvaActionSheetItem.Style) -> UIColor {
        switch style {
        case .normal, .destructive, .cancel:
            return AppTheme.text
        }
    }

    @objc private func actionTapped(_ sender: UIButton) {
        let item = items[sender.tag]
        dismissSheet {
            item.handler()
        }
    }

    @objc private func dismissTapped() {
        dismissSheet()
    }
}

final class KinvaNoticeViewController: UIViewController {
    private let noticeTitle: String
    private let noticeMessage: String

    init(title: String, message: String) {
        noticeTitle = title
        noticeMessage = message
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.58)

        let card = UIView()
        card.backgroundColor = .white
        card.round(20)

        let titleLabel = UILabel()
        titleLabel.text = noticeTitle
        titleLabel.textColor = AppTheme.text
        titleLabel.font = AppTheme.font(23, .heavy)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let messageLabel = UILabel()
        messageLabel.text = noticeMessage
        messageLabel.textColor = AppTheme.text
        messageLabel.font = AppTheme.font(15, .bold)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let okButton = UIButton(type: .system)
        okButton.setTitle("OK", for: .normal)
        okButton.setTitleColor(.white, for: .normal)
        okButton.titleLabel?.font = AppTheme.font(17, .bold)
        okButton.backgroundColor = AppTheme.blue
        okButton.round(11)
        okButton.addTarget(self, action: #selector(okTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, okButton])
        stack.axis = .vertical
        stack.spacing = 9
        stack.setCustomSpacing(18, after: messageLabel)
        [card, stack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        view.addSubview(card)
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 25),
            card.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -25),
            card.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -13),
            okButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    @objc private func okTapped() {
        dismiss(animated: true)
    }
}

final class KinvaConfirmationViewController: UIViewController {
    private let confirmationTitle: String
    private let confirmationMessage: String
    private let confirmTitle: String
    private let action: () -> Void

    init(title: String, message: String, confirmTitle: String, action: @escaping () -> Void) {
        confirmationTitle = title
        confirmationMessage = message
        self.confirmTitle = confirmTitle
        self.action = action
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.58)

        let card = UIView()
        card.backgroundColor = .white
        card.round(22)

        let titleLabel = UILabel()
        titleLabel.text = confirmationTitle
        titleLabel.textColor = AppTheme.text
        titleLabel.font = AppTheme.font(30, .heavy)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let messageLabel = UILabel()
        messageLabel.text = confirmationMessage
        messageLabel.textColor = AppTheme.text
        messageLabel.font = AppTheme.font(19, .bold)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(AppTheme.text, for: .normal)
        cancelButton.titleLabel?.font = AppTheme.font(20, .bold)
        cancelButton.backgroundColor = .white
        cancelButton.layer.borderColor = UIColor.black.cgColor
        cancelButton.layer.borderWidth = 3
        cancelButton.round(13)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let confirmButton = UIButton(type: .system)
        confirmButton.setTitle(confirmTitle, for: .normal)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.titleLabel?.font = AppTheme.font(20, .bold)
        confirmButton.backgroundColor = AppTheme.blue
        confirmButton.round(13)
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)

        let buttons = UIStackView(arrangedSubviews: [cancelButton, confirmButton])
        buttons.axis = .horizontal
        buttons.distribution = .fillEqually
        buttons.spacing = 20
        let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, buttons])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(24, after: messageLabel)

        [card, stack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        view.addSubview(card)
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            card.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            card.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 30),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
            buttons.heightAnchor.constraint(equalToConstant: 58)
        ])
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func confirmTapped() {
        dismiss(animated: true, completion: action)
    }
}

extension UIViewController {
    func showLocalAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func showConfirmation(title: String, message: String, confirm: String, action: @escaping () -> Void) {
        present(KinvaConfirmationViewController(title: title,
                                                message: message,
                                                confirmTitle: confirm,
                                                action: action),
                animated: true)
    }

    func showKinvaNotice(title: String, message: String) {
        present(KinvaNoticeViewController(title: title, message: message), animated: true)
    }

    func showKinvaActionSheet(items: [KinvaActionSheetItem]) {
        guard !items.isEmpty else { return }
        present(KinvaActionSheetViewController(items: items), animated: false)
    }

    func presentUserActions(targetID: String, targetType: String) {
        showKinvaActionSheet(items: [
            KinvaActionSheetItem(title: "Report") { [weak self] in
                let report = ReportViewController(targetID: targetID, targetType: targetType)
                self?.navigationController?.pushSecondLevel(report, animated: true)
            },
            KinvaActionSheetItem(title: "Block", style: .destructive) { [weak self] in
                self?.showConfirmation(title: "Block User", message: "Their posts, challenges, comments, conversations and notifications will be hidden everywhere.", confirm: "Block") {
                    do { try LocalDataStore.shared.block(userID: targetID); self?.navigationController?.popViewController(animated: true) } catch { self?.showLocalAlert(title: "Could not block", message: error.localizedDescription) }
                }
            },
            KinvaActionSheetItem(title: "Cancel", style: .cancel, handler: {})
        ])
    }
}

extension UINavigationController {
    func pushSecondLevel(_ viewController: UIViewController, animated: Bool = true) {
        viewController.hidesBottomBarWhenPushed = true
        pushViewController(viewController, animated: animated)
    }
}
