import UIKit

enum AuthLayoutMetrics {
    static let horizontalInset: CGFloat = 21
    static let fieldHeight: CGFloat = 50
    static let buttonHeight: CGFloat = 69
    static let cornerRadius: CGFloat = 15
}

func kinvaAuthFont(_ size: CGFloat,
                   weight: UIFont.Weight = .regular,
                   textStyle: UIFont.TextStyle = .body) -> UIFont {
    UIFontMetrics(forTextStyle: textStyle).scaledFont(for: AppTheme.font(size, weight))
}

func kinvaAuthLabel(text: String? = nil,
                    size: CGFloat,
                    weight: UIFont.Weight = .regular,
                    color: UIColor = AppTheme.text,
                    textStyle: UIFont.TextStyle = .body) -> UILabel {
    let label = UILabel()
    label.text = text
    label.textColor = color
    label.font = kinvaAuthFont(size, weight: weight, textStyle: textStyle)
    label.adjustsFontForContentSizeCategory = true
    return label
}

final class AuthIconTextField: UIView {
    let titleLabel = kinvaAuthLabel(size: 14, weight: .semibold, color: UIColor(hex: 0x45689A), textStyle: .subheadline)
    let textField = UITextField()
    let secureToggleButton = UIButton(type: .system)

    private let fieldContainer = UIView()
    private let iconView = UIImageView()
    private let separator = UIView()
    private var textLeadingConstraint: NSLayoutConstraint?

    init(title: String,
         placeholder: String,
         symbol: String,
         isSecure: Bool = false) {
        super.init(frame: .zero)
        titleLabel.text = title
        iconView.image = UIImage.symbol(symbol, size: 18, weight: .semibold)
        iconView.tintColor = UIColor(hex: 0x2E2D38)
        iconView.contentMode = .scaleAspectFit

        fieldContainer.backgroundColor = .white
        fieldContainer.round(14)
        separator.backgroundColor = AppTheme.background

        textField.placeholder = placeholder
        textField.textColor = AppTheme.text
        textField.tintColor = AppTheme.blue
        textField.font = kinvaAuthFont(14, weight: .semibold, textStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.autocorrectionType = .no
        textField.clearButtonMode = .never
        textField.isSecureTextEntry = isSecure
        textField.accessibilityLabel = title

        secureToggleButton.tintColor = AppTheme.mutedText
        secureToggleButton.setImage(UIImage.symbol(isSecure ? "eye.slash" : "eye", size: 15), for: .normal)
        secureToggleButton.isHidden = !isSecure
        secureToggleButton.accessibilityLabel = "Show or hide password"
        secureToggleButton.addTarget(self, action: #selector(toggleSecureText), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleLabel, fieldContainer])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        [iconView, separator, textField, secureToggleButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            fieldContainer.addSubview($0)
        }

        let textLeading = textField.leadingAnchor.constraint(equalTo: separator.trailingAnchor, constant: 22)
        textLeadingConstraint = textLeading
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),

            fieldContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: AuthLayoutMetrics.fieldHeight),
            iconView.leadingAnchor.constraint(equalTo: fieldContainer.leadingAnchor, constant: 21),
            iconView.centerYAnchor.constraint(equalTo: fieldContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
            separator.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 20),
            separator.topAnchor.constraint(equalTo: fieldContainer.topAnchor),
            separator.bottomAnchor.constraint(equalTo: fieldContainer.bottomAnchor),
            separator.widthAnchor.constraint(equalToConstant: 6),
            textLeading,
            textField.topAnchor.constraint(equalTo: fieldContainer.topAnchor),
            textField.bottomAnchor.constraint(equalTo: fieldContainer.bottomAnchor),
            secureToggleButton.leadingAnchor.constraint(greaterThanOrEqualTo: textField.trailingAnchor, constant: 8),
            secureToggleButton.trailingAnchor.constraint(equalTo: fieldContainer.trailingAnchor, constant: -10),
            secureToggleButton.centerYAnchor.constraint(equalTo: fieldContainer.centerYAnchor),
            secureToggleButton.widthAnchor.constraint(equalToConstant: 36),
            secureToggleButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func applyPlainProfileStyle() {
        iconView.isHidden = true
        separator.isHidden = true
        fieldContainer.backgroundColor = AppTheme.field
        textLeadingConstraint?.isActive = false
        textLeadingConstraint = textField.leadingAnchor.constraint(equalTo: fieldContainer.leadingAnchor, constant: 17)
        textLeadingConstraint?.isActive = true
        titleLabel.font = profileFormRoundedFont(14, weight: .bold)
        textField.font = profileFormRoundedFont(14, weight: .semibold)
        textField.attributedPlaceholder = NSAttributedString(
            string: "Please enter...",
            attributes: [
                .font: profileFormRoundedFont(14, weight: .semibold),
                .foregroundColor: UIColor(hex: 0xB8C5CD)
            ]
        )
    }

    @objc private func toggleSecureText() {
        textField.isSecureTextEntry.toggle()
        let symbol = textField.isSecureTextEntry ? "eye.slash" : "eye"
        secureToggleButton.setImage(UIImage.symbol(symbol, size: 15), for: .normal)
    }
}

final class AuthAvatarPickerView: UIView {
    let imageView = UIImageView()
    let cameraButton = UIButton(type: .system)
    private let avatarSize: CGFloat

    init(size: CGFloat = 100, cameraSize: CGFloat = 38) {
        avatarSize = size
        super.init(frame: .zero)
        imageView.backgroundColor = .white
        imageView.image = kinvaDefaultAvatarImage(size: size)
        imageView.tintColor = kinvaDefaultAvatarColor()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.round(size / 2)

        if let camera = UIImage(named: "camera")?.withRenderingMode(.alwaysOriginal) {
            cameraButton.setImage(camera, for: .normal)
            cameraButton.backgroundColor = .clear
        } else {
            cameraButton.setImage(UIImage.symbol("camera.fill", size: 21, weight: .bold), for: .normal)
            cameraButton.tintColor = .white
            cameraButton.backgroundColor = AppTheme.blue
            cameraButton.layer.borderColor = UIColor.white.cgColor
            cameraButton.layer.borderWidth = 4
            cameraButton.round(cameraSize / 2)
        }
        cameraButton.accessibilityLabel = "Choose profile photo"

        [imageView, cameraButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size + cameraSize * 0.26),
            heightAnchor.constraint(equalToConstant: size),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.widthAnchor.constraint(equalToConstant: size),
            imageView.heightAnchor.constraint(equalToConstant: size),
            cameraButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            cameraButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            cameraButton.widthAnchor.constraint(equalToConstant: cameraSize),
            cameraButton.heightAnchor.constraint(equalToConstant: cameraSize)
        ])
    }

    func setImage(_ image: UIImage?) {
        imageView.image = image ?? kinvaDefaultAvatarImage(size: avatarSize)
        imageView.contentMode = image == nil ? .scaleAspectFit : .scaleAspectFill
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private func profileFormRoundedFont(_ size: CGFloat, weight: UIFont.Weight) -> UIFont {
    let base = UIFont.systemFont(ofSize: size, weight: weight)
    guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
    return UIFont(descriptor: descriptor, size: size)
}

final class KinvaCurvedTopView: UIView {
    private let shapeLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.insertSublayer(shapeLayer, at: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let curveDepth = min(42, bounds.height * 0.16)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: curveDepth))
        path.addQuadCurve(to: CGPoint(x: bounds.width, y: curveDepth),
                          controlPoint: CGPoint(x: bounds.midX, y: -curveDepth))
        path.addLine(to: CGPoint(x: bounds.width, y: bounds.height))
        path.addLine(to: CGPoint(x: 0, y: bounds.height))
        path.close()
        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = backgroundColor?.cgColor ?? UIColor.white.cgColor
        shapeLayer.frame = bounds
    }
}
