import UIKit

final class AgreementModalViewController: UIViewController {
    var onCancel: (() -> Void)?
    var onAgree: (() -> Void)?

    let titleLabel = kinvaAuthLabel(text: "EULA", size: 26, weight: .bold, textStyle: .title1)
    let cancelButton = UIButton(type: .system)
    let agreeButton = BrandButton(title: "Agree")
    private let body: String

    init(body: String) {
        self.body = body
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    convenience init() {
        self.init(body: "Welcome to Kinva. To create a positive, safe and respectful space for dance, creativity and sharing, harmful, exploitative, violent, discriminatory or unlawful content is prohibited. Please review the complete local privacy policy and user agreement before continuing.")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.68)

        let card = UIView()
        card.backgroundColor = .white
        card.round(22)
        titleLabel.textAlignment = .center
        titleLabel.accessibilityTraits = .header

        let textScroll = UIScrollView()
        textScroll.alwaysBounceVertical = true
        textScroll.showsVerticalScrollIndicator = true

        let bodyStack = makeBodyStack()
        bodyStack.translatesAutoresizingMaskIntoConstraints = false
        textScroll.addSubview(bodyStack)

        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.black, for: .normal)
        cancelButton.titleLabel?.font = kinvaAuthFont(17, weight: .bold, textStyle: .headline)
        cancelButton.layer.borderWidth = 3
        cancelButton.layer.borderColor = UIColor.black.cgColor
        cancelButton.round(12)
        agreeButton.titleLabel?.font = kinvaAuthFont(17, weight: .bold, textStyle: .headline)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        agreeButton.addTarget(self, action: #selector(agreeTapped), for: .touchUpInside)
        let buttons = UIStackView(arrangedSubviews: [cancelButton, agreeButton])
        buttons.axis = .horizontal
        buttons.distribution = .fillEqually
        buttons.spacing = 16

        [card, titleLabel, textScroll, buttons].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        view.addSubview(card)
        [titleLabel, textScroll, buttons].forEach { card.addSubview($0) }

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 30),
            card.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -25),
            card.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            card.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 45),
            card.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -45),

            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            textScroll.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            textScroll.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            textScroll.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            textScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 260),
            textScroll.heightAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.heightAnchor, multiplier: 0.63),
            bodyStack.topAnchor.constraint(equalTo: textScroll.contentLayoutGuide.topAnchor),
            bodyStack.leadingAnchor.constraint(equalTo: textScroll.contentLayoutGuide.leadingAnchor),
            bodyStack.trailingAnchor.constraint(equalTo: textScroll.contentLayoutGuide.trailingAnchor),
            bodyStack.bottomAnchor.constraint(equalTo: textScroll.contentLayoutGuide.bottomAnchor),
            bodyStack.widthAnchor.constraint(equalTo: textScroll.frameLayoutGuide.widthAnchor),
            buttons.topAnchor.constraint(equalTo: textScroll.bottomAnchor, constant: 12),
            buttons.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            buttons.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            buttons.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22),
            buttons.heightAnchor.constraint(greaterThanOrEqualToConstant: 43)
        ])
    }

    private func makeBodyStack() -> UIStackView {
        let paragraphs = body
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let views = paragraphs.map { paragraph -> UIView in
            guard let numbered = numberedParagraph(from: paragraph) else {
                return makeParagraphLabel(text: paragraph)
            }

            let numberLabel = makeParagraphLabel(text: numbered.number)
            numberLabel.numberOfLines = 1
            numberLabel.textAlignment = .right
            numberLabel.setContentHuggingPriority(.required, for: .horizontal)
            numberLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            numberLabel.widthAnchor.constraint(equalToConstant: 28).isActive = true

            let textLabel = makeParagraphLabel(text: numbered.text)
            let row = UIStackView(arrangedSubviews: [numberLabel, textLabel])
            row.axis = .horizontal
            row.alignment = .top
            row.spacing = 7
            return row
        }

        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 14
        return stack
    }

    private func makeParagraphLabel(text: String) -> UILabel {
        let label = kinvaAuthLabel(text: text, size: 15, weight: .semibold, textStyle: .body)
        label.numberOfLines = 0
        label.textAlignment = .left

        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.lineSpacing = 2
        label.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: label.font as Any,
                .foregroundColor: label.textColor as Any,
                .paragraphStyle: style
            ]
        )
        return label
    }

    private func numberedParagraph(from paragraph: String) -> (number: String, text: String)? {
        guard let dotIndex = paragraph.firstIndex(of: ".") else { return nil }
        let numberPart = String(paragraph[..<dotIndex])
        guard !numberPart.isEmpty, numberPart.allSatisfy(\.isNumber) else { return nil }

        let textStart = paragraph.index(after: dotIndex)
        let text = paragraph[textStart...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return (numberPart + ".", text)
    }

    @objc private func cancelTapped() { onCancel?() }
    @objc private func agreeTapped() { onAgree?() }
}
