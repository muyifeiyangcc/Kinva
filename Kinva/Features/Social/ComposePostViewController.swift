import UIKit

final class ComposePostViewController: BaseScrollViewController {
    struct Draft: Equatable {
        var imageTokens: [String] = []
        var description: String = ""
        var topic: String = ""

        var imageCount: Int { imageTokens.count }

        init(imageTokens: [String] = [], description: String = "", topic: String = "") {
            self.imageTokens = imageTokens
            self.description = description
            self.topic = topic
        }
    }

    var onBack: ((Draft) -> Void)?
    var onAddImages: (() -> Void)?
    var onRemoveImage: ((Int) -> Void)?
    var onPost: ((Draft) -> Void)?

    private let imageScroll = UIScrollView()
    private let imageStrip = UIStackView()
    private let descriptionField = AppTextField(placeholder: "Say something about this…")
    private let topicField = AppTextField(placeholder: "Input your label")
    private let postButton = BrandButton(title: "Post")
    private var imageCount = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        display(draft: Draft())
        render(state: .content)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let horizontalInset = imageCount == 0 ? max(20, (imageScroll.bounds.width - 188) / 2) : 20
        imageScroll.contentInset = UIEdgeInsets(top: 0, left: horizontalInset, bottom: 0, right: horizontalInset)
    }

    func display(draft: Draft) {
        currentTokens = draft.imageTokens
        imageCount = draft.imageTokens.count
        descriptionField.text = draft.description
        topicField.text = draft.topic
        rebuildImageStrip()
        refreshPostAvailability()
    }

    func setSubmitting(_ submitting: Bool) {
        postButton.isEnabled = !submitting
        postButton.alpha = submitting ? 0.55 : 1
        postButton.setTitle(submitting ? "Posting…" : "Post", for: .normal)
    }

    private func buildLayout() {
        contentStack.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 26, right: 0)
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.spacing = 20
        let header = AppHeaderView(title: "Post")
        header.backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(header)

        imageScroll.showsHorizontalScrollIndicator = false
        imageScroll.alwaysBounceHorizontal = true
        imageStrip.axis = .horizontal
        imageStrip.spacing = 10
        imageStrip.translatesAutoresizingMaskIntoConstraints = false
        imageScroll.addSubview(imageStrip)
        NSLayoutConstraint.activate([
            imageScroll.heightAnchor.constraint(equalToConstant: 266),
            imageStrip.topAnchor.constraint(equalTo: imageScroll.contentLayoutGuide.topAnchor),
            imageStrip.leadingAnchor.constraint(equalTo: imageScroll.contentLayoutGuide.leadingAnchor),
            imageStrip.trailingAnchor.constraint(equalTo: imageScroll.contentLayoutGuide.trailingAnchor),
            imageStrip.bottomAnchor.constraint(equalTo: imageScroll.contentLayoutGuide.bottomAnchor),
            imageStrip.heightAnchor.constraint(equalTo: imageScroll.frameLayoutGuide.heightAnchor)
        ])
        contentStack.addArrangedSubview(imageScroll)

        let formCard = UIView()
        formCard.backgroundColor = .white
        formCard.round(20)
        let descriptionLabel = fieldLabel("Description")
        let topicLabel = fieldLabel("Theme")
        let formStack = UIStackView(arrangedSubviews: [descriptionLabel, descriptionField, topicLabel, topicField])
        formStack.axis = .vertical
        formStack.spacing = 12
        formStack.setCustomSpacing(18, after: descriptionField)
        formStack.translatesAutoresizingMaskIntoConstraints = false
        formCard.addSubview(formStack)
        NSLayoutConstraint.activate([
            formStack.topAnchor.constraint(equalTo: formCard.topAnchor, constant: 20),
            formStack.leadingAnchor.constraint(equalTo: formCard.leadingAnchor, constant: 20),
            formStack.trailingAnchor.constraint(equalTo: formCard.trailingAnchor, constant: -20),
            formStack.bottomAnchor.constraint(equalTo: formCard.bottomAnchor, constant: -24)
        ])
        contentStack.addArrangedSubview(formCard)
        contentStack.addSpacer(38)
        let buttonWrap = UIView()
        postButton.round(18)
        postButton.translatesAutoresizingMaskIntoConstraints = false
        buttonWrap.addSubview(postButton)
        NSLayoutConstraint.activate([
            buttonWrap.heightAnchor.constraint(equalToConstant: 70),
            postButton.topAnchor.constraint(equalTo: buttonWrap.topAnchor),
            postButton.leadingAnchor.constraint(equalTo: buttonWrap.leadingAnchor, constant: 20),
            postButton.trailingAnchor.constraint(equalTo: buttonWrap.trailingAnchor, constant: -20),
            postButton.bottomAnchor.constraint(equalTo: buttonWrap.bottomAnchor)
        ])
        contentStack.addArrangedSubview(buttonWrap)

        descriptionField.addTarget(self, action: #selector(fieldChanged), for: .editingChanged)
        topicField.addTarget(self, action: #selector(fieldChanged), for: .editingChanged)
        postButton.addTarget(self, action: #selector(postTapped), for: .touchUpInside)
    }

    private func rebuildImageStrip() {
        imageStrip.arrangedSubviews.forEach { view in
            imageStrip.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        for index in 0..<imageCount {
            let tile = UIView()
            let image: UIView
            if index < currentTokens.count, let localImage = kinvaImage(token: currentTokens[index]) {
                let imageView = UIImageView(image: localImage)
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
                imageView.round(16)
                image = imageView
            } else {
                image = SocialImagePlaceholderView(index: index, cornerRadius: 16)
            }
            let remove = UIButton(type: .system)
            remove.tag = index
            remove.setImage(.symbol("minus", size: 15, weight: .bold), for: .normal)
            remove.tintColor = .white
            remove.backgroundColor = AppTheme.blue
            remove.round(17)
            [image, remove].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; tile.addSubview($0) }
            NSLayoutConstraint.activate([
                tile.widthAnchor.constraint(equalToConstant: 184),
                image.topAnchor.constraint(equalTo: tile.topAnchor),
                image.leadingAnchor.constraint(equalTo: tile.leadingAnchor),
                image.trailingAnchor.constraint(equalTo: tile.trailingAnchor),
                image.bottomAnchor.constraint(equalTo: tile.bottomAnchor),
                remove.topAnchor.constraint(equalTo: tile.topAnchor, constant: -3),
                remove.trailingAnchor.constraint(equalTo: tile.trailingAnchor, constant: 3),
                remove.widthAnchor.constraint(equalToConstant: 34),
                remove.heightAnchor.constraint(equalToConstant: 34)
            ])
            remove.addTarget(self, action: #selector(removeTapped(_:)), for: .touchUpInside)
            imageStrip.addArrangedSubview(tile)
        }

        let add = UIButton(type: .system)
        add.backgroundColor = .white
        add.tintColor = AppTheme.text
        add.round(24)
        // `photo.badge.plus` is not available on every supported system and
        // silently produces a nil image there. Build the same artwork from
        // two long-supported symbols so the upload affordance never vanishes.
        let addIcon = UIImageView(image: .symbol("photo", size: 50, weight: .bold))
        addIcon.tintColor = AppTheme.text
        addIcon.isUserInteractionEnabled = false
        addIcon.contentMode = .scaleAspectFit
        let addBadge = UIImageView(image: .symbol("plus.circle.fill", size: 24, weight: .bold))
        addBadge.tintColor = AppTheme.text
        addBadge.backgroundColor = .white
        addBadge.contentMode = .scaleAspectFit
        addBadge.isUserInteractionEnabled = false
        addBadge.round(12)
        let addLabel = UILabel()
        addLabel.text = "Upload image"
        addLabel.font = AppTheme.font(16, .bold)
        addLabel.textColor = AppTheme.text
        addLabel.isUserInteractionEnabled = false
        [addIcon, addBadge, addLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; add.addSubview($0) }
        NSLayoutConstraint.activate([
            addIcon.centerXAnchor.constraint(equalTo: add.centerXAnchor),
            addIcon.centerYAnchor.constraint(equalTo: add.centerYAnchor, constant: -28),
            addIcon.widthAnchor.constraint(equalToConstant: 56),
            addIcon.heightAnchor.constraint(equalToConstant: 56),
            addBadge.centerXAnchor.constraint(equalTo: addIcon.trailingAnchor, constant: -5),
            addBadge.centerYAnchor.constraint(equalTo: addIcon.topAnchor, constant: 7),
            addBadge.widthAnchor.constraint(equalToConstant: 24),
            addBadge.heightAnchor.constraint(equalToConstant: 24),
            addLabel.centerXAnchor.constraint(equalTo: add.centerXAnchor),
            addLabel.topAnchor.constraint(equalTo: addIcon.bottomAnchor, constant: 24)
        ])
        add.widthAnchor.constraint(equalToConstant: imageCount == 0 ? 188 : 168).isActive = true
        add.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        imageStrip.addArrangedSubview(add)
    }

    private func fieldLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = AppTheme.font(14, .semibold)
        label.textColor = UIColor(hex: 0x49689C)
        return label
    }

    private var currentDraft: Draft {
        Draft(imageTokens: currentTokens,
              description: descriptionField.text ?? "",
              topic: topicField.text ?? "")
    }

    private var currentTokens: [String] = []

    private func refreshPostAvailability() {
        let hasCopy = !(descriptionField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        postButton.isEnabled = imageCount > 0 || hasCopy
        postButton.alpha = 1
    }

    @objc private func backTapped() { onBack?(currentDraft) }
    @objc private func addTapped() { onAddImages?() }
    @objc private func removeTapped(_ sender: UIButton) { onRemoveImage?(sender.tag) }
    @objc private func fieldChanged() { refreshPostAvailability() }
    @objc private func postTapped() { guard postButton.isEnabled else { return }; onPost?(currentDraft) }
}
