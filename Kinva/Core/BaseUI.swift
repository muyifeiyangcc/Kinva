import UIKit

enum LocalViewState: Equatable {
    case loading
    case content
    case empty(String)
    case parseError(String)
}

class BaseScrollViewController: UIViewController {
    let scrollView = UIScrollView()
    let contentView = UIView()
    let contentStack = UIStackView()
    private let stateOverlay = StateOverlayView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background
        view.isOpaque = true
        navigationController?.setNavigationBarHidden(true, animated: false)
        scrollView.backgroundColor = AppTheme.background
        contentView.backgroundColor = AppTheme.background
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(contentStack)
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
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        stateOverlay.translatesAutoresizingMaskIntoConstraints = false
        stateOverlay.isHidden = true
        view.addSubview(stateOverlay)
        NSLayoutConstraint.activate([
            stateOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            stateOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stateOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stateOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func render(state: LocalViewState, retry: (() -> Void)? = nil) {
        switch state {
        case .content:
            stateOverlay.isHidden = true
            scrollView.isHidden = false
        case .loading:
            scrollView.isHidden = true
            stateOverlay.showLoading()
        case .empty(let message):
            scrollView.isHidden = true
            stateOverlay.show(message: message, symbol: "tray", actionTitle: nil, action: nil)
        case .parseError(let message):
            scrollView.isHidden = true
            stateOverlay.show(message: message, symbol: "doc.badge.exclamationmark", actionTitle: "Retry", action: retry)
        }
    }
}

final class StateOverlayView: UIView {
    private let indicator = UIActivityIndicatorView(style: .medium)
    private let icon = UIImageView()
    private let label = UILabel()
    private let button = UIButton(type: .system)
    private var action: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = AppTheme.background
        let stack = UIStackView(arrangedSubviews: [indicator, icon, label, button])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        icon.tintColor = AppTheme.blue
        icon.contentMode = .scaleAspectFit
        icon.heightAnchor.constraint(equalToConstant: 40).isActive = true
        label.font = AppTheme.font(14)
        label.textColor = AppTheme.secondaryText
        label.numberOfLines = 0
        label.textAlignment = .center
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = AppTheme.blue
        button.titleLabel?.font = AppTheme.font(14, .semibold)
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 28, bottom: 12, right: 28)
        button.round(12)
        button.addTarget(self, action: #selector(tap), for: .touchUpInside)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 30),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -30)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    func showLoading() { isHidden = false; icon.isHidden = true; label.text = "Loading data…"; button.isHidden = true; indicator.startAnimating() }
    func show(message: String, symbol: String, actionTitle: String?, action: (() -> Void)?) {
        isHidden = false; indicator.stopAnimating(); icon.isHidden = false
        icon.image = .symbol(symbol, size: 36); label.text = message; self.action = action
        button.setTitle(actionTitle, for: .normal); button.isHidden = actionTitle == nil
    }
    @objc private func tap() { action?() }
}

final class BrandButton: UIButton {
    init(title: String, color: UIColor = AppTheme.blue) {
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        setTitleColor(.white, for: .normal)
        backgroundColor = color
        titleLabel?.font = AppTheme.font(20, .bold)
        heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true
        round(15)
    }
    required init?(coder: NSCoder) { fatalError() }
}

final class AppTextField: UITextField {
    init(placeholder: String, symbol: String? = nil) {
        super.init(frame: .zero)
        self.placeholder = placeholder
        font = AppTheme.font(12)
        textColor = AppTheme.text
        backgroundColor = AppTheme.field
        borderStyle = .none
        round(9)
        heightAnchor.constraint(equalToConstant: 50).isActive = true
        let pad = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 50))
        if let symbol {
            let image = UIImageView(image: .symbol(symbol, size: 14))
            image.tintColor = AppTheme.text
            image.frame = CGRect(x: 15, y: 17, width: 16, height: 16)
            pad.addSubview(image)
        }
        leftView = pad
        leftViewMode = .always
    }
    required init?(coder: NSCoder) { fatalError() }
}

final class AppHeaderView: UIView {
    let backButton = UIButton(type: .system)
    let titleLabel = UILabel()
    let trailingButton = UIButton(type: .system)
    init(title: String, trailingSymbol: String? = nil) {
        super.init(frame: .zero)
        backButton.setImage(.symbol("arrow.left", size: 19, weight: .bold), for: .normal)
        backButton.tintColor = .white
        backButton.backgroundColor = .black
        backButton.round(11)
        titleLabel.text = title
        titleLabel.font = AppTheme.font(24, .bold)
        titleLabel.textColor = AppTheme.text
        titleLabel.textAlignment = .center
        if let trailingSymbol {
            trailingButton.setImage(.symbol(trailingSymbol, size: 18, weight: .bold), for: .normal)
            trailingButton.tintColor = .white
            trailingButton.backgroundColor = .black
        }
        trailingButton.round(11)
        [backButton, titleLabel, trailingButton].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0) }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 70),
            backButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20), backButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 40), backButton.heightAnchor.constraint(equalToConstant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor), titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            trailingButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16), trailingButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            trailingButton.widthAnchor.constraint(equalToConstant: 40), trailingButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

@MainActor
func kinvaImage(token: String?) -> UIImage? {
    guard let token = token?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else { return nil }
    if FileManager.default.fileExists(atPath: token), let image = UIImage(contentsOfFile: token) {
        return image
    }
    if let image = UIImage(named: token) { return image }
    let assetName = (token as NSString).deletingPathExtension
    return assetName == token ? nil : UIImage(named: assetName)
}

@MainActor
func kinvaMediaFilePath(token: String?) -> String? {
    guard let token = token?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else { return nil }
    if FileManager.default.fileExists(atPath: token) { return token }
    let fileName = URL(fileURLWithPath: token).lastPathComponent as NSString
    let resource = fileName.deletingPathExtension
    let fileExtension = fileName.pathExtension.isEmpty ? nil : fileName.pathExtension
    return Bundle.main.url(forResource: resource, withExtension: fileExtension, subdirectory: "File")?.path
        ?? Bundle.main.url(forResource: resource, withExtension: fileExtension)?.path
}

@MainActor
func kinvaAvatarImage(userID: String?) -> UIImage? {
    guard let userID else { return nil }
    if let token = LocalDataStore.shared.avatarToken(userID: userID),
       let image = UIImage(contentsOfFile: token) {
        return image
    }
    return kinvaImage(token: LocalDataStore.shared.user(id: userID)?.avatarAssetName)
}

@MainActor
func kinvaDefaultAvatarImage(size: CGFloat) -> UIImage? {
    UIImage.symbol("person.crop.circle", size: size * 0.92, weight: .regular)?.withRenderingMode(.alwaysTemplate)
}

@MainActor
func kinvaDefaultAvatarColor() -> UIColor {
    UIColor(hex: 0xD8DDE2)
}

final class AvatarView: UIView {
    private let imageView = UIImageView()
    private let avatarSize: CGFloat
    init(name: String, size: CGFloat = 44, image: UIImage? = nil, userID: String? = nil) {
        avatarSize = size
        super.init(frame: .zero)
        backgroundColor = .white
        round(size / 2)
        clipsToBounds = true
        imageView.clipsToBounds = true
        imageView.tintColor = kinvaDefaultAvatarColor()
        let resolvedImage = image ?? kinvaAvatarImage(userID: userID)
        imageView.image = resolvedImage ?? kinvaDefaultAvatarImage(size: size)
        imageView.contentMode = resolvedImage == nil ? .scaleAspectFit : .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size), heightAnchor.constraint(equalToConstant: size),
            imageView.topAnchor.constraint(equalTo: topAnchor), imageView.leadingAnchor.constraint(equalTo: leadingAnchor), imageView.trailingAnchor.constraint(equalTo: trailingAnchor), imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        accessibilityLabel = name
    }
    required init?(coder: NSCoder) { fatalError() }

    func setName(_ name: String) {
        accessibilityLabel = name
    }

    func setImage(_ image: UIImage?) {
        imageView.image = image ?? kinvaDefaultAvatarImage(size: avatarSize)
        imageView.contentMode = image == nil ? .scaleAspectFit : .scaleAspectFill
    }

    func setUser(id: String?, name: String) {
        setName(name)
        setImage(kinvaAvatarImage(userID: id))
    }
}

extension UIStackView {
    func addSpacer(_ value: CGFloat) {
        let spacer = UIView(); spacer.heightAnchor.constraint(equalToConstant: value).isActive = true; addArrangedSubview(spacer)
    }
}
