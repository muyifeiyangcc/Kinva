import UIKit

final class MessagesListViewController: BaseScrollViewController {
    var onSystemNotifications: (() -> Void)?
    var onConversation: ((MessageConversationViewModel) -> Void)?
    var onRetry: (() -> Void)?

    private let conversationsStack = UIStackView()
    private let emptyLabel = UILabel()
    private var conversations: [MessageConversationViewModel] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        render(state: .content)
    }

    func display(conversations: [MessageConversationViewModel]) {
        self.conversations = conversations
        rebuildRows()
        emptyLabel.isHidden = !conversations.isEmpty
        render(state: .content)
    }

    func displayLoading() { render(state: .loading) }

    func displayParseError(_ message: String = "Local conversations could not be read.") {
        render(state: .parseError(message), retry: onRetry)
    }

    private func buildLayout() {
        contentStack.layoutMargins = UIEdgeInsets(top: 18, left: 20, bottom: 30, right: 20)
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.spacing = 16
        let title = UILabel()
        title.text = "M E S S A G E S"
        title.textAlignment = .center
        title.font = AppTheme.font(25, .heavy)
        title.textColor = AppTheme.text
        title.heightAnchor.constraint(equalToConstant: 48).isActive = true
        contentStack.addArrangedSubview(title)

        let systemRow = UIButton(type: .system)
        systemRow.backgroundColor = .clear
        let bell = UIImageView(image: .symbol("bell", size: 25, weight: .medium))
        bell.tintColor = .white
        bell.backgroundColor = AppTheme.blue
        bell.contentMode = .center
        bell.round(26)
        let systemName = UILabel()
        systemName.text = "System information"
        systemName.font = AppTheme.font(18, .bold)
        systemName.textColor = AppTheme.text
        let systemPreview = UILabel()
        systemPreview.text = "Hello new friend, welcome…"
        systemPreview.font = AppTheme.font(12, .semibold)
        systemPreview.textColor = AppTheme.text
        let copy = UIStackView(arrangedSubviews: [systemName, systemPreview])
        copy.axis = .vertical
        copy.spacing = 3
        let time = UILabel()
        time.text = "Just now"
        time.font = AppTheme.font(11, .semibold)
        time.textColor = AppTheme.text
        // The button owns the complete row hit area. Its decorative children
        // must not become the hit-test result and swallow the button action.
        [bell, copy, time].forEach {
            $0.isUserInteractionEnabled = false
            $0.translatesAutoresizingMaskIntoConstraints = false
            systemRow.addSubview($0)
        }
        NSLayoutConstraint.activate([
            systemRow.heightAnchor.constraint(equalToConstant: 66),
            bell.leadingAnchor.constraint(equalTo: systemRow.leadingAnchor),
            bell.centerYAnchor.constraint(equalTo: systemRow.centerYAnchor),
            bell.widthAnchor.constraint(equalToConstant: 52),
            bell.heightAnchor.constraint(equalToConstant: 52),
            copy.leadingAnchor.constraint(equalTo: bell.trailingAnchor, constant: 12),
            copy.centerYAnchor.constraint(equalTo: bell.centerYAnchor),
            time.trailingAnchor.constraint(equalTo: systemRow.trailingAnchor),
            time.topAnchor.constraint(equalTo: bell.topAnchor, constant: 6),
            copy.trailingAnchor.constraint(lessThanOrEqualTo: time.leadingAnchor, constant: -8)
        ])
        systemRow.addTarget(self, action: #selector(systemTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(systemRow)

        conversationsStack.axis = .vertical
        conversationsStack.spacing = 11
        conversationsStack.alignment = .fill
        contentStack.addArrangedSubview(conversationsStack)
        emptyLabel.text = "No conversations yet."
        emptyLabel.font = AppTheme.font(14)
        emptyLabel.textColor = AppTheme.mutedText
        emptyLabel.textAlignment = .center
        emptyLabel.heightAnchor.constraint(equalToConstant: 120).isActive = true
        emptyLabel.isHidden = true
        contentStack.addArrangedSubview(emptyLabel)
    }

    private func rebuildRows() {
        conversationsStack.arrangedSubviews.forEach { view in
            conversationsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        for (index, conversation) in conversations.enumerated() {
            let row = ConversationRowView(model: conversation)
            row.tag = index
            row.addTarget(self, action: #selector(conversationTapped(_:)), for: .touchUpInside)
            conversationsStack.addArrangedSubview(row)
        }
    }

    @objc private func systemTapped() { onSystemNotifications?() }
    @objc private func conversationTapped(_ sender: ConversationRowView) {
        guard conversations.indices.contains(sender.tag) else { return }
        onConversation?(conversations[sender.tag])
    }
}
