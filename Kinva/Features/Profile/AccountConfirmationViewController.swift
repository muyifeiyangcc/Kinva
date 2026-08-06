import UIKit

final class AccountConfirmationViewController: UIViewController {
    enum Kind {
        case signOut
        case deleteAccount
        case authenticationRequired

        var title: String {
            switch self {
            case .signOut: return "Sign Out"
            case .deleteAccount: return "Delete Account"
            case .authenticationRequired: return "Hint"
            }
        }
        var message: String {
            switch self {
            case .signOut:
                return "Are you sure you want to log out of your account?"
            case .deleteAccount:
                return "Are you sure you want to delete this account? All data will be cleared after deletion and cannot be recovered."
            case .authenticationRequired:
                return "To ensure the normal operation of the function, please log in to your account first."
            }
        }
        var confirmTitle: String {
            switch self {
            case .signOut: return "Sure"
            case .deleteAccount: return "Delete"
            case .authenticationRequired: return "Sign In"
            }
        }
    }

    var onCancel: (() -> Void)?
    var onConfirm: (() -> Void)?

    let kind: Kind

    init(kind: Kind) {
        self.kind = kind
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.68)

        let card = UIView()
        card.backgroundColor = .white
        card.round(18)
        let title = kinvaProfileLabel(text: kind.title, size: 26, weight: .bold, textStyle: .title1)
        title.textAlignment = .center
        title.accessibilityTraits = .header
        let message = kinvaProfileLabel(text: kind.message, size: 16, weight: .semibold, textStyle: .body)
        message.textAlignment = .center
        message.numberOfLines = 0

        let cancel = UIButton(type: .system)
        cancel.setTitle("Cancel", for: .normal)
        cancel.setTitleColor(.black, for: .normal)
        cancel.titleLabel?.font = kinvaProfileFont(17, weight: .bold, textStyle: .headline)
        cancel.layer.borderColor = UIColor.black.cgColor
        cancel.layer.borderWidth = 3
        cancel.round(11)
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let confirm = UIButton(type: .system)
        confirm.setTitle(kind.confirmTitle, for: .normal)
        confirm.setTitleColor(.white, for: .normal)
        confirm.titleLabel?.font = kinvaProfileFont(17, weight: .bold, textStyle: .headline)
        confirm.backgroundColor = AppTheme.blue
        confirm.round(11)
        confirm.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)

        let buttons = UIStackView(arrangedSubviews: [cancel, confirm])
        buttons.axis = .horizontal
        buttons.distribution = .fillEqually
        buttons.spacing = 16
        let stack = UIStackView(arrangedSubviews: [title, message, buttons])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(18, after: message)
        [card, stack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        view.addSubview(card)
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 29),
            card.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -26),
            card.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            card.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 30),
            card.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            buttons.heightAnchor.constraint(greaterThanOrEqualToConstant: 43)
        ])
    }

    @objc private func cancelTapped() { onCancel?() }
    @objc private func confirmTapped() { onConfirm?() }
}
