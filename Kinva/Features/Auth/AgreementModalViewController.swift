import UIKit

final class AgreementModalViewController: UIViewController {
    var onCancel: (() -> Void)?
    var onAgree: (() -> Void)?

    let titleLabel = kinvaAuthLabel(text: "EULA", size: 26, weight: .bold, textStyle: .title1)
    let bodyLabel = kinvaAuthLabel(size: 16, weight: .semibold, textStyle: .body)
    let cancelButton = UIButton(type: .system)
    let agreeButton = BrandButton(title: "Agree")

    init(body: String) {
        super.init(nibName: nil, bundle: nil)
        bodyLabel.text = body
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
        bodyLabel.numberOfLines = 0
        bodyLabel.textAlignment = .center

        let textScroll = UIScrollView()
        textScroll.alwaysBounceVertical = true
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        textScroll.addSubview(bodyLabel)

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
            bodyLabel.topAnchor.constraint(equalTo: textScroll.contentLayoutGuide.topAnchor),
            bodyLabel.leadingAnchor.constraint(equalTo: textScroll.contentLayoutGuide.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: textScroll.contentLayoutGuide.trailingAnchor),
            bodyLabel.bottomAnchor.constraint(equalTo: textScroll.contentLayoutGuide.bottomAnchor),
            bodyLabel.widthAnchor.constraint(equalTo: textScroll.frameLayoutGuide.widthAnchor),
            buttons.topAnchor.constraint(equalTo: textScroll.bottomAnchor, constant: 12),
            buttons.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            buttons.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            buttons.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22),
            buttons.heightAnchor.constraint(greaterThanOrEqualToConstant: 43)
        ])
    }

    @objc private func cancelTapped() { onCancel?() }
    @objc private func agreeTapped() { onAgree?() }
}
