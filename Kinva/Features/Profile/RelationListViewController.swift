import UIKit

class RelationListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    enum Kind {
        case following
        case followers
        case blacklist

        var title: String {
            switch self {
            case .following: return "Following"
            case .followers: return "Followers"
            case .blacklist: return "Blocklist"
            }
        }
    }

    struct Item {
        let id: String
        var displayName: String
        var avatarImage: UIImage?
        var isConnected: Bool

        init(id: String, displayName: String, avatarImage: UIImage? = nil, isConnected: Bool = false) {
            self.id = id
            self.displayName = displayName
            self.avatarImage = avatarImage
            self.isConnected = isConnected
        }
    }

    var onBack: (() -> Void)?
    var onSelectPerson: ((Item) -> Void)?
    var onAction: ((Item) -> Void)?

    let kind: Kind
    let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = kinvaProfileLabel(size: 15, color: AppTheme.secondaryText, textStyle: .body)
    private(set) var items: [Item] = []

    init(kind: Kind) {
        self.kind = kind
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background
        navigationController?.setNavigationBarHidden(true, animated: false)

        let header = AppHeaderView(title: kind.title)
        header.backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.alwaysBounceVertical = true
        tableView.keyboardDismissMode = .interactive
        tableView.rowHeight = 78
        tableView.estimatedRowHeight = 78
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(PersonListCell.self, forCellReuseIdentifier: PersonListCell.reuseIdentifier)
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)

        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden = true

        [header, tableView, emptyLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: header.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor, constant: -35),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 30),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -30)
        ])
        updateEmptyState()
    }

    func setItems(_ items: [Item], emptyMessage: String? = nil) {
        self.items = items
        if let emptyMessage { emptyLabel.text = emptyMessage }
        tableView.reloadData()
        updateEmptyState()
    }

    func numberOfSections(in tableView: UITableView) -> Int { 1 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: PersonListCell.reuseIdentifier,
                                                       for: indexPath) as? PersonListCell else {
            return UITableViewCell()
        }
        let item = items[indexPath.row]
        let appearance = actionAppearance(for: item)
        cell.configure(name: item.displayName,
                       image: item.avatarImage,
                       actionSymbol: appearance.symbol,
                       actionColor: appearance.color)
        cell.onAction = { [weak self] in self?.onAction?(item) }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onSelectPerson?(items[indexPath.row])
    }

    private func actionAppearance(for item: Item) -> (symbol: String, color: UIColor) {
        switch kind {
        case .followers where !item.isConnected:
            return ("plus", AppTheme.blue)
        case .followers, .following, .blacklist:
            return ("minus", UIColor(hex: 0xC8D0D6))
        }
    }

    private func updateEmptyState() {
        if emptyLabel.text == nil {
            switch kind {
            case .following: emptyLabel.text = "No users followed yet."
            case .followers: emptyLabel.text = "No followers yet."
            case .blacklist: emptyLabel.text = "No blocked users."
            }
        }
        emptyLabel.isHidden = !items.isEmpty
        tableView.isHidden = items.isEmpty
    }

    @objc private func backTapped() { onBack?() }
}

final class BlacklistViewController: RelationListViewController {
    init() { super.init(kind: .blacklist) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
