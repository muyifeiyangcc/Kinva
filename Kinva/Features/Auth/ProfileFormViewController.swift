import UIKit

final class ProfileGenderOptionView: UIControl {
    let imageView = UIImageView()
    let titleLabel = kinvaAuthLabel(size: 16, weight: .bold, color: AppTheme.mutedText, textStyle: .headline)

    override var isSelected: Bool {
        didSet { updateAppearance() }
    }

    init(title: String, symbol: String) {
        super.init(frame: .zero)
        titleLabel.text = title
        titleLabel.textAlignment = .center
        let isFemale = title == "Madam"
        imageView.image = UIImage(named: isFemale ? "female" : "male")?.withRenderingMode(.alwaysOriginal)
            ?? UIImage.symbol(symbol, size: 34)
        imageView.contentMode = .scaleAspectFit

        backgroundColor = .white
        round(14)
        let stack = UIStackView(arrangedSubviews: isFemale ? [titleLabel, imageView] : [imageView, titleLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fill
        stack.spacing = 4
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 73),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            imageView.widthAnchor.constraint(equalToConstant: 64)
        ])
        accessibilityTraits = [.button]
        accessibilityLabel = title
        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func updateAppearance() {
        backgroundColor = isSelected ? (titleLabel.text == "Madam" ? AppTheme.pink : UIColor(hex: 0x62A6DE)) : .white
        titleLabel.textColor = isSelected ? .white : AppTheme.mutedText
        accessibilityTraits = isSelected ? [.button, .selected] : [.button]
    }
}

final class ProfileFormViewController: BaseScrollViewController {
    enum Mode {
        case onboarding
        case editing
    }

    var onBack: (() -> Void)?
    var onChoosePhoto: (() -> Void)?
    var onChooseBirthday: (() -> Void)?
    var onSave: (() -> Void)?

    let mode: Mode
    let avatarView: AuthAvatarPickerView
    let nameField = AuthIconTextField(title: "Name", placeholder: "Please Enter", symbol: "person.fill")
    let birthdayField = AuthIconTextField(title: "Birthday", placeholder: "2003-01-01", symbol: "calendar")
    let manOption = ProfileGenderOptionView(title: "Man", symbol: "person.crop.circle.fill")
    let womanOption = ProfileGenderOptionView(title: "Madam", symbol: "person.crop.circle.fill")
    let saveButton: BrandButton
    private(set) var selectedGender: String?
    var selectedAvatarToken: String?

    init(mode: Mode) {
        self.mode = mode
        avatarView = AuthAvatarPickerView(size: mode == .editing ? 145 : 100,
                                          cameraSize: mode == .editing ? 54 : 38)
        saveButton = BrandButton(title: mode == .onboarding ? "Sign up" : "Publish")
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        contentView.heightAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.heightAnchor).isActive = true
        contentStack.spacing = 0
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.layoutMargins = UIEdgeInsets(top: 0,
                                                  left: mode == .onboarding ? AuthLayoutMetrics.horizontalInset : 0,
                                                  bottom: 12,
                                                  right: mode == .onboarding ? AuthLayoutMetrics.horizontalInset : 0)

        avatarView.cameraButton.addTarget(self, action: #selector(photoTapped), for: .touchUpInside)
        avatarView.imageView.isUserInteractionEnabled = true
        avatarView.imageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(photoTapped)))
        birthdayField.textField.isUserInteractionEnabled = false
        addTapRecognizer(to: birthdayField, action: #selector(birthdayTapped))
        manOption.addTarget(self, action: #selector(manTapped), for: .touchUpInside)
        womanOption.addTarget(self, action: #selector(womanTapped), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        switch mode {
        case .onboarding:
            buildOnboardingLayout()
        case .editing:
            buildEditingLayout()
        }
    }

    func selectGender(_ value: String?) {
        selectedGender = value
        manOption.isSelected = value == "Man"
        womanOption.isSelected = value == "Madam" || value == "Woman"
    }

    private func buildOnboardingLayout() {
        let header = UIView()
        header.heightAnchor.constraint(equalToConstant: 144).isActive = true
        let headline = kinvaAuthLabel(text: "IMPROVE YOUR\nPROFILE 📷", size: 24, weight: .bold, textStyle: .title2)
        headline.font = profileEditingRoundedFont(24, weight: .bold)
        headline.numberOfLines = 2
        headline.textAlignment = .center
        headline.accessibilityTraits = .header
        let back = UIButton(type: .system)
        back.setImage(.symbol("arrow.left", size: 23, weight: .bold), for: .normal)
        back.tintColor = .white
        back.backgroundColor = .black
        back.round(11)
        back.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        [back, avatarView, headline].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            header.addSubview($0)
        }
        NSLayoutConstraint.activate([
            back.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            back.topAnchor.constraint(equalTo: header.topAnchor, constant: 4),
            back.widthAnchor.constraint(equalToConstant: 40),
            back.heightAnchor.constraint(equalToConstant: 40),
            avatarView.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 44),
            avatarView.topAnchor.constraint(equalTo: header.topAnchor, constant: 12),
            headline.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 22),
            headline.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            headline.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor)
        ])

        contentStack.addArrangedSubview(header)
        [nameField, birthdayField].forEach {
            $0.titleLabel.font = profileEditingRoundedFont(14, weight: .bold)
            $0.textField.font = profileEditingRoundedFont(14, weight: .semibold)
        }
        manOption.titleLabel.font = profileEditingRoundedFont(16, weight: .bold)
        womanOption.titleLabel.font = profileEditingRoundedFont(16, weight: .bold)
        if selectedGender == nil { selectGender("Madam") }
        [nameField, birthdayField].forEach {
            contentStack.addArrangedSubview($0)
            contentStack.setCustomSpacing(16, after: $0)
        }
        addGenderBlock(to: contentStack)
        let spacer = UIView()
        spacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        spacer.setContentHuggingPriority(UILayoutPriority(1), for: .vertical)
        contentStack.addArrangedSubview(spacer)
        contentStack.addArrangedSubview(saveButton)
        saveButton.titleLabel?.font = profileEditingRoundedFont(30, weight: .bold)
        saveButton.heightAnchor.constraint(greaterThanOrEqualToConstant: AuthLayoutMetrics.buttonHeight).isActive = true
    }

    private func buildEditingLayout() {
        let header = AppHeaderView(title: "Edit Profile")
        header.titleLabel.font = profileEditingRoundedFont(30, weight: .bold)
        header.backButton.setImage(.symbol("arrow.left", size: 23, weight: .bold), for: .normal)
        header.backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(header)

        let avatarHolder = UIView()
        avatarHolder.heightAnchor.constraint(equalToConstant: 190).isActive = true
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarHolder.addSubview(avatarView)
        NSLayoutConstraint.activate([
            avatarView.topAnchor.constraint(equalTo: avatarHolder.topAnchor, constant: 21),
            avatarView.centerXAnchor.constraint(equalTo: avatarHolder.centerXAnchor)
        ])
        contentStack.addArrangedSubview(avatarHolder)

        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 20
        card.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = 16
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)

        let information = kinvaAuthLabel(text: "Information", size: 30, weight: .bold, textStyle: .title1)
        information.font = profileEditingRoundedFont(30, weight: .bold)
        information.accessibilityTraits = .header
        cardStack.addArrangedSubview(information)
        nameField.applyPlainProfileStyle()
        cardStack.addArrangedSubview(nameField)
        let spacer = UIView()
        spacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        cardStack.addArrangedSubview(spacer)
        cardStack.addArrangedSubview(saveButton)
        saveButton.titleLabel?.font = profileEditingRoundedFont(30, weight: .bold)
        saveButton.heightAnchor.constraint(greaterThanOrEqualToConstant: AuthLayoutMetrics.buttonHeight).isActive = true

        contentStack.addArrangedSubview(card)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AuthLayoutMetrics.horizontalInset),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AuthLayoutMetrics.horizontalInset),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            card.heightAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.heightAnchor, constant: -260)
        ])
    }

    private func addGenderBlock(to stack: UIStackView) {
        let title = kinvaAuthLabel(text: "Gender", size: 14, weight: .semibold, color: UIColor(hex: 0x45689A), textStyle: .subheadline)
        title.font = profileEditingRoundedFont(14, weight: .bold)
        let options = UIStackView(arrangedSubviews: [manOption, womanOption])
        options.axis = .horizontal
        options.distribution = .fillEqually
        options.spacing = 30
        let block = UIStackView(arrangedSubviews: [title, options])
        block.axis = .vertical
        block.spacing = 12
        stack.addArrangedSubview(block)
    }

    private func addTapRecognizer(to view: UIView, action: Selector) {
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: action))
    }

    @objc private func photoTapped() { onChoosePhoto?() }
    @objc private func birthdayTapped() { onChooseBirthday?() }
    @objc private func manTapped() { selectGender("Man") }
    @objc private func womanTapped() { selectGender("Madam") }
    @objc private func saveTapped() { onSave?() }
    @objc private func backTapped() { onBack?() }
}

private func profileEditingRoundedFont(_ size: CGFloat, weight: UIFont.Weight) -> UIFont {
    let base = UIFont.systemFont(ofSize: size, weight: weight)
    guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
    return UIFont(descriptor: descriptor, size: size)
}
