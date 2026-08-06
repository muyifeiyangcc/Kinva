import UIKit

final class WelcomeViewController: UIViewController, UITextViewDelegate {
    var onSignUp: (() -> Void)?
    var onSignIn: (() -> Void)?
    var onContinueAsGuest: (() -> Void)?
    var onAppleIdentity: (() -> Void)?
    var onOpenTerms: (() -> Void)?
    var onOpenPrivacy: (() -> Void)?

    let backgroundImageView = UIImageView()
    let newUserButton = UIButton(type: .system)
    let emailSignInButton = UIButton(type: .system)
    let appleButton = UIButton(type: .system)
    let agreementButton = UIButton(type: .system)
    private let agreementTextView = UITextView()

    var isAgreementAccepted = false {
        didSet { updateAgreementState() }
    }

    init(backgroundImage: UIImage? = nil) {
        super.init(nibName: nil, bundle: nil)
        backgroundImageView.image = backgroundImage
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background

        let scrollView = UIScrollView()
        let contentView = UIView()
        scrollView.alwaysBounceVertical = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.contentInsetAdjustmentBehavior = .never
        backgroundImageView.image = backgroundImageView.image ?? UIImage(named: "lau_banner")
        backgroundImageView.backgroundColor = UIColor(hex: 0xD8D2C8)
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true

        let panel = WelcomeCurvedPanelView()
        panel.backgroundColor = UIColor(hex: 0xF8FAFF)

        let brandLabel = kinvaAuthLabel(size: 72, weight: .black, color: .white, textStyle: .largeTitle)
        brandLabel.textAlignment = .center
        brandLabel.attributedText = NSAttributedString(
            string: "KINVA",
            attributes: [
                .font: roundedWelcomeFont(72, weight: .black),
                .foregroundColor: UIColor.white,
                .strokeColor: UIColor.black,
                .strokeWidth: -10
            ]
        )
        brandLabel.minimumScaleFactor = 0.62
        brandLabel.adjustsFontSizeToFitWidth = true
        brandLabel.numberOfLines = 1

        configureBlackButton(newUserButton, title: "I'M NEW", action: #selector(guestTapped))
        configureBlackButton(emailSignInButton, title: "SIGN IN BY EMAIL", action: #selector(signInTapped))

        let accountPrompt = makeAccountPrompt()
        let agreementRow = makeAgreementRow()

        [scrollView].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; view.addSubview($0) }
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        [backgroundImageView, panel, brandLabel, newUserButton, emailSignInButton, accountPrompt, agreementRow].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        let contentHeight = contentView.heightAnchor.constraint(greaterThanOrEqualTo: view.heightAnchor)
        contentHeight.priority = .required
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            contentHeight,

            backgroundImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            // Tie the hero to the available screen height instead of width.
            // A width-based 1.36 ratio consumes almost the entire viewport on
            // 4.7-inch devices and pushes Sign up / legal copy off screen.
            backgroundImageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.58),
            panel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            panel.topAnchor.constraint(equalTo: backgroundImageView.bottomAnchor, constant: -54),
            panel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            brandLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 155),
            brandLabel.heightAnchor.constraint(equalToConstant: 96),
            brandLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            brandLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 34),
            brandLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -34),

            newUserButton.topAnchor.constraint(equalTo: panel.topAnchor, constant: 42),
            newUserButton.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 39),
            newUserButton.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -39),
            newUserButton.heightAnchor.constraint(equalToConstant: 54),
            emailSignInButton.topAnchor.constraint(equalTo: newUserButton.bottomAnchor, constant: 16),
            emailSignInButton.leadingAnchor.constraint(equalTo: newUserButton.leadingAnchor),
            emailSignInButton.trailingAnchor.constraint(equalTo: newUserButton.trailingAnchor),
            emailSignInButton.heightAnchor.constraint(equalToConstant: 54),
            accountPrompt.topAnchor.constraint(equalTo: emailSignInButton.bottomAnchor, constant: 14),
            accountPrompt.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            agreementRow.topAnchor.constraint(greaterThanOrEqualTo: accountPrompt.bottomAnchor, constant: 12),
            agreementRow.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 31),
            agreementRow.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -31),
            agreementRow.bottomAnchor.constraint(equalTo: panel.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            agreementRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
        ])
        updateAgreementState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    private func configureBlackButton(_ button: UIButton, title: String, action: Selector) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .black
        button.titleLabel?.font = roundedWelcomeFont(23, weight: .heavy)
        button.round(27)
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func makeAccountPrompt() -> UIView {
        let label = kinvaAuthLabel(text: "Don't have an account?", size: 15, weight: .bold, textStyle: .subheadline)
        label.font = roundedWelcomeFont(15, weight: .bold)
        let button = UIButton(type: .system)
        button.setAttributedTitle(NSAttributedString(
            string: "Sign up",
            attributes: [
                .font: roundedWelcomeFont(15, weight: .bold),
                .foregroundColor: AppTheme.blue,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        ), for: .normal)
        button.addTarget(self, action: #selector(signUpTapped), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [label, button])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 4
        return stack
    }

    private func makeOrDivider() -> UIView {
        let left = UIView(); left.backgroundColor = UIColor(hex: 0xAEB0B4)
        let right = UIView(); right.backgroundColor = UIColor(hex: 0xAEB0B4)
        let label = kinvaAuthLabel(text: "OR", size: 15, weight: .bold, textStyle: .subheadline)
        let stack = UIStackView(arrangedSubviews: [left, label, right])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 13
        left.heightAnchor.constraint(equalToConstant: 1).isActive = true
        right.heightAnchor.constraint(equalToConstant: 1).isActive = true
        left.widthAnchor.constraint(equalTo: right.widthAnchor).isActive = true
        return stack
    }

    private func makeAgreementRow() -> UIView {
        agreementButton.setTitleColor(.black, for: .normal)
        agreementButton.titleLabel?.font = roundedWelcomeFont(18, weight: .bold)
        agreementButton.addTarget(self, action: #selector(agreementTapped), for: .touchUpInside)
        agreementButton.accessibilityLabel = "Accept terms and privacy policy"

        let text = "By continuing you agree to our Terms of Service and Privacy Policy"
        let attributed = NSMutableAttributedString(string: text,
                                                   attributes: [
                                                    .font: roundedWelcomeFont(14, weight: .bold),
                                                    .foregroundColor: UIColor.black
                                                   ])
        attributed.addAttribute(.link,
                                value: "kinva://terms",
                                range: (text as NSString).range(of: "Terms of Service"))
        attributed.addAttribute(.link,
                                value: "kinva://privacy",
                                range: (text as NSString).range(of: "Privacy Policy"))
        agreementTextView.attributedText = attributed
        agreementTextView.backgroundColor = .clear
        agreementTextView.isEditable = false
        agreementTextView.isScrollEnabled = false
        agreementTextView.textContainerInset = .zero
        agreementTextView.textContainer.lineFragmentPadding = 0
        agreementTextView.delegate = self
        agreementTextView.textAlignment = .left
        agreementTextView.linkTextAttributes = [
            .foregroundColor: AppTheme.blue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        let row = UIView()
        [agreementButton, agreementTextView].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; row.addSubview($0) }
        NSLayoutConstraint.activate([
            agreementButton.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            agreementButton.widthAnchor.constraint(equalToConstant: 24),
            agreementButton.heightAnchor.constraint(equalToConstant: 24),
            agreementButton.firstBaselineAnchor.constraint(equalTo: agreementTextView.firstBaselineAnchor),
            agreementTextView.leadingAnchor.constraint(equalTo: agreementButton.trailingAnchor, constant: 3),
            agreementTextView.topAnchor.constraint(equalTo: row.topAnchor),
            agreementTextView.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            agreementTextView.bottomAnchor.constraint(equalTo: row.bottomAnchor)
        ])
        return row
    }

    private func updateAgreementState() {
        let mark = isAgreementAccepted ? "◉" : "○"
        agreementButton.setTitle(mark, for: .normal)
        // Keep both actions tappable. Sign in explains the missing consent at
        // tap time, while guest browsing intentionally does not require it.
        newUserButton.isEnabled = true
        newUserButton.alpha = 1
        emailSignInButton.isEnabled = true
        emailSignInButton.alpha = 1
    }

    @objc private func signUpTapped() { onSignUp?() }
    @objc private func signInTapped() {
        guard isAgreementAccepted else {
            showKinvaNotice(title: "Hint",
                            message: "Please agree to the Terms of Service and Privacy Policy first.")
            return
        }
        onSignIn?()
    }
    @objc private func guestTapped() { onContinueAsGuest?() }
    @objc private func appleTapped() { onAppleIdentity?() }
    @objc private func agreementTapped() { isAgreementAccepted.toggle() }

    func textView(_ textView: UITextView,
                  shouldInteractWith URL: URL,
                  in characterRange: NSRange,
                  interaction: UITextItemInteraction) -> Bool {
        switch URL.host {
        case "terms": onOpenTerms?()
        case "privacy": onOpenPrivacy?()
        default: return false
        }
        return false
    }
}

private func roundedWelcomeFont(_ size: CGFloat, weight: UIFont.Weight) -> UIFont {
    let base = UIFont.systemFont(ofSize: size, weight: weight)
    guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
    return UIFont(descriptor: descriptor, size: size)
}

private final class WelcomeCurvedPanelView: UIView {
    private let maskLayer = CAShapeLayer()

    override func layoutSubviews() {
        super.layoutSubviews()
        let depth = min(62, bounds.height * 0.18)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: depth))
        path.addQuadCurve(
            to: CGPoint(x: bounds.width, y: depth),
            controlPoint: CGPoint(x: bounds.midX, y: -depth)
        )
        path.addLine(to: CGPoint(x: bounds.width, y: bounds.height))
        path.addLine(to: CGPoint(x: 0, y: bounds.height))
        path.close()
        maskLayer.frame = bounds
        maskLayer.path = path.cgPath
        layer.mask = maskLayer
    }
}
