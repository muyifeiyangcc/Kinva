import UIKit

final class SettingsViewController: BaseScrollViewController {
    enum Item: CaseIterable {
        case privacyPolicy
        case termsOfService
        case editProfile
        case blacklist
        case signOut
        case deleteAccount

        var title: String {
            switch self {
            case .privacyPolicy: return "Privacy Policy"
            case .termsOfService: return "Terms of Service"
            case .editProfile: return "Edit Profile"
            case .blacklist: return "Blacklist"
            case .signOut: return "Log Out"
            case .deleteAccount: return "Delete Account"
            }
        }
    }

    var onBack: (() -> Void)?
    var onSelectItem: ((Item) -> Void)?
    private var menuRows: [(Item, ProfileMenuRow)] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        contentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor).isActive = true
        contentStack.spacing = 0

        let header = AppHeaderView(title: "Edit Profile")
        header.titleLabel.font = settingsRoundedFont(30, weight: .bold)
        header.backButton.setImage(.symbol("arrow.left", size: 23, weight: .bold), for: .normal)
        header.backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(header)

        for item in Item.allCases {
            let row = ProfileMenuRow(title: item.title)
            row.titleLabel.font = settingsRoundedFont(18, weight: .bold)
            row.addTarget(self, action: #selector(menuRowTapped(_:)), for: .touchUpInside)
            menuRows.append((item, row))
            contentStack.addArrangedSubview(row)
        }
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        contentStack.addArrangedSubview(spacer)
    }

    @objc private func backTapped() { onBack?() }

    @objc private func menuRowTapped(_ sender: ProfileMenuRow) {
        guard let item = menuRows.first(where: { $0.1 === sender })?.0 else { return }
        onSelectItem?(item)
    }
}

private func settingsRoundedFont(_ size: CGFloat, weight: UIFont.Weight) -> UIFont {
    let base = UIFont.systemFont(ofSize: size, weight: weight)
    guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
    return UIFont(descriptor: descriptor, size: size)
}
