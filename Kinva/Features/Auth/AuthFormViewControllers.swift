import UIKit

class AuthCredentialsViewController: BaseScrollViewController {
    let backButton = UIButton(type: .system)
    let alternateActionButton = UIButton(type: .system)
    let titleLabel = kinvaAuthLabel(size: 32, weight: .bold, textStyle: .largeTitle)
    let submitButton: BrandButton
    let fields: [AuthIconTextField]
    let auxiliaryButton = UIButton(type: .system)

    var onBack: (() -> Void)?
    var onAlternateAction: (() -> Void)?
    var onSubmit: (() -> Void)?
    var onAuxiliaryAction: (() -> Void)?

    init(title: String,
         alternateTitle: String?,
         submitTitle: String,
         auxiliaryTitle: String?,
         fields: [AuthIconTextField]) {
        self.submitButton = BrandButton(title: submitTitle)
        self.fields = fields
        super.init(nibName: nil, bundle: nil)
        titleLabel.text = title
        alternateActionButton.setTitle(alternateTitle, for: .normal)
        auxiliaryButton.setTitle(auxiliaryTitle, for: .normal)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        contentView.heightAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.heightAnchor).isActive = true
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.layoutMargins = UIEdgeInsets(top: 0,
                                                  left: AuthLayoutMetrics.horizontalInset,
                                                  bottom: 12,
                                                  right: AuthLayoutMetrics.horizontalInset)
        contentStack.spacing = 0

        let topBar = makeTopBar()
        contentStack.addArrangedSubview(topBar)
        contentStack.addArrangedSubview(titleLabel)
        titleLabel.numberOfLines = 2
        titleLabel.accessibilityTraits = .header
        contentStack.setCustomSpacing(25, after: titleLabel)

        for field in fields {
            contentStack.addArrangedSubview(field)
            contentStack.setCustomSpacing(16, after: field)
        }

        if auxiliaryButton.title(for: .normal) != nil {
            auxiliaryButton.contentHorizontalAlignment = .leading
            auxiliaryButton.titleLabel?.font = kinvaAuthFont(14, weight: .bold, textStyle: .subheadline)
            auxiliaryButton.setTitleColor(AppTheme.blue, for: .normal)
            auxiliaryButton.addTarget(self, action: #selector(auxiliaryTapped), for: .touchUpInside)

            // Do not use the button itself as an arranged subview: a vertical
            // stack stretches arranged views across the entire row, making
            // blank space beside the title tappable. The wrapper keeps only
            // the intrinsic-width "Forgot password?" control interactive.
            let auxiliaryRow = UIView()
            auxiliaryRow.heightAnchor.constraint(equalToConstant: 44).isActive = true
            auxiliaryButton.translatesAutoresizingMaskIntoConstraints = false
            auxiliaryRow.addSubview(auxiliaryButton)
            NSLayoutConstraint.activate([
                auxiliaryButton.leadingAnchor.constraint(equalTo: auxiliaryRow.leadingAnchor),
                auxiliaryButton.topAnchor.constraint(equalTo: auxiliaryRow.topAnchor),
                auxiliaryButton.bottomAnchor.constraint(equalTo: auxiliaryRow.bottomAnchor),
                auxiliaryButton.trailingAnchor.constraint(lessThanOrEqualTo: auxiliaryRow.trailingAnchor)
            ])
            contentStack.addArrangedSubview(auxiliaryRow)
        }

        let flexibleSpacer = UIView()
        flexibleSpacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        flexibleSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        contentStack.addArrangedSubview(flexibleSpacer)
        contentStack.addArrangedSubview(submitButton)
        submitButton.heightAnchor.constraint(greaterThanOrEqualToConstant: AuthLayoutMetrics.buttonHeight).isActive = true
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
    }

    private func makeTopBar() -> UIView {
        let container = UIView()
        container.heightAnchor.constraint(equalToConstant: 70).isActive = true

        backButton.setImage(UIImage.symbol("arrow.left", size: 20, weight: .bold), for: .normal)
        backButton.tintColor = .white
        backButton.backgroundColor = .black
        backButton.round(11)
        backButton.accessibilityLabel = "Back"
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        alternateActionButton.setTitleColor(.white, for: .normal)
        alternateActionButton.backgroundColor = AppTheme.blue
        alternateActionButton.titleLabel?.font = kinvaAuthFont(20, weight: .bold, textStyle: .title3)
        alternateActionButton.round(10)
        alternateActionButton.addTarget(self, action: #selector(alternateTapped), for: .touchUpInside)
        alternateActionButton.isHidden = alternateActionButton.title(for: .normal) == nil

        [backButton, alternateActionButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview($0)
        }
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            backButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 40),
            backButton.heightAnchor.constraint(equalToConstant: 40),
            alternateActionButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            alternateActionButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            alternateActionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 106),
            alternateActionButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
        return container
    }

    @objc private func backTapped() { onBack?() }
    @objc private func alternateTapped() { onAlternateAction?() }
    @objc private func submitTapped() { onSubmit?() }
    @objc private func auxiliaryTapped() { onAuxiliaryAction?() }
}

final class SignInViewController: AuthCredentialsViewController {
    let emailField: AuthIconTextField
    let passwordField: AuthIconTextField

    init() {
        emailField = AuthIconTextField(title: "Email", placeholder: "Enter Email Address", symbol: "envelope.fill")
        passwordField = AuthIconTextField(title: "Password", placeholder: "Enter Password", symbol: "lock.fill", isSecure: true)
        super.init(title: "Welcome to\nKINVA 👏",
                   alternateTitle: "Sign up",
                   submitTitle: "Sign in",
                   auxiliaryTitle: "Forgot password?",
                   fields: [emailField, passwordField])
        emailField.textField.keyboardType = .emailAddress
        emailField.textField.textContentType = .username
        emailField.textField.autocapitalizationType = .none
        passwordField.textField.textContentType = .password
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class SignUpViewController: AuthCredentialsViewController {
    let emailField: AuthIconTextField
    let passwordField: AuthIconTextField
    let confirmationField: AuthIconTextField

    init() {
        emailField = AuthIconTextField(title: "Email", placeholder: "Enter Email Address", symbol: "envelope.fill")
        passwordField = AuthIconTextField(title: "Password", placeholder: "Enter Password", symbol: "lock.fill", isSecure: true)
        confirmationField = AuthIconTextField(title: "Password", placeholder: "Enter The Password Again", symbol: "lock.fill", isSecure: true)
        super.init(title: "Welcome to\nKINVA 👏",
                   alternateTitle: "Sign in",
                   submitTitle: "Sign up",
                   auxiliaryTitle: nil,
                   fields: [emailField, passwordField, confirmationField])
        emailField.textField.keyboardType = .emailAddress
        emailField.textField.textContentType = .username
        emailField.textField.autocapitalizationType = .none
        passwordField.textField.textContentType = .newPassword
        confirmationField.textField.textContentType = .newPassword
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class ResetPasswordViewController: AuthCredentialsViewController {
    let emailField: AuthIconTextField
    let passwordField: AuthIconTextField
    let confirmationField: AuthIconTextField

    init() {
        emailField = AuthIconTextField(title: "Email", placeholder: "Enter Email Address", symbol: "envelope.fill")
        passwordField = AuthIconTextField(title: "Password", placeholder: "Enter Password", symbol: "lock.fill", isSecure: true)
        confirmationField = AuthIconTextField(title: "Password", placeholder: "Enter The Password Again", symbol: "lock.fill", isSecure: true)
        super.init(title: "Forgot\nPassword 🤔",
                   alternateTitle: nil,
                   submitTitle: "Save",
                   auxiliaryTitle: nil,
                   fields: [emailField, passwordField, confirmationField])
        emailField.textField.keyboardType = .emailAddress
        emailField.textField.textContentType = .username
        emailField.textField.autocapitalizationType = .none
        passwordField.textField.textContentType = .newPassword
        confirmationField.textField.textContentType = .newPassword
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
