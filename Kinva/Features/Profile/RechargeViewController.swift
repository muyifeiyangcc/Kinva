import UIKit

final class RechargeTierView: UIView {
    private let gradientLayer = CAGradientLayer()
    let diamondImageView = UIImageView(image: UIImage(named: "diamond")?.withRenderingMode(.alwaysOriginal))
    let amountLabel = kinvaProfileLabel(size: 25, weight: .bold, textStyle: .title2)
    let priceLabel = kinvaProfileLabel(size: 17, weight: .bold, textStyle: .headline)
    let continueButton = UIButton(type: .system)
    var onContinue: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        gradientLayer.colors = [
            UIColor(hex: 0xD7F3FF).cgColor,
            UIColor(hex: 0xCFF8E8).cgColor,
            UIColor(hex: 0xE2EDFF).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradientLayer, at: 0)
        layer.borderColor = AppTheme.blue.cgColor
        layer.borderWidth = 2
        round(15)

        diamondImageView.contentMode = .scaleAspectFit
        amountLabel.font = rechargeRoundedFont(25, weight: .bold)
        amountLabel.textAlignment = .center
        priceLabel.font = rechargeRoundedFont(17, weight: .bold)
        priceLabel.textAlignment = .center
        continueButton.setTitle("Continue", for: .normal)
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.titleLabel?.font = rechargeRoundedFont(16, weight: .bold)
        continueButton.backgroundColor = AppTheme.blue
        continueButton.round(12)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [diamondImageView, amountLabel, priceLabel, continueButton])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 5
        stack.setCustomSpacing(10, after: priceLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 196),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
            diamondImageView.heightAnchor.constraint(equalToConstant: 50),
            continueButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(amount: Int, price: String) {
        amountLabel.text = "\(amount)"
        priceLabel.text = price
        accessibilityLabel = "\(amount) diamonds, \(price)"
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = layer.cornerRadius
    }

    @objc private func continueTapped() { onContinue?() }
}

final class RechargeViewController: BaseScrollViewController {
    struct Tier {
        let id: String
        let diamonds: Int
        let price: String

        init(id: String, diamonds: Int, price: String) {
            self.id = id
            self.diamonds = diamonds
            self.price = price
        }
    }

    var onBack: (() -> Void)?
    var onLoadProducts: (() -> Void)?
    var onSelectTier: ((Tier) -> Void)?

    let balanceLabel = kinvaProfileLabel(size: 50, weight: .bold, textStyle: .largeTitle)
    private let tiersStack = UIStackView()
    private let purchaseOverlay = UIView()
    private let purchaseIndicator = UIActivityIndicatorView(style: .large)
    private let purchaseStatusLabel = UILabel()
    private var tiers: [Tier] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        contentStack.spacing = 0

        let header = AppHeaderView(title: "Recharge")
        header.titleLabel.font = rechargeRoundedFont(30, weight: .bold)
        header.backButton.setImage(.symbol("arrow.left", size: 23, weight: .bold), for: .normal)
        header.backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(header)

        let balanceBlock = makeBalanceBlock()
        contentStack.addArrangedSubview(balanceBlock)

        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 24
        card.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        let title = kinvaProfileLabel(text: "Recharge Tiers", size: 30, weight: .bold, textStyle: .title1)
        title.font = rechargeRoundedFont(30, weight: .bold)
        title.accessibilityTraits = .header
        tiersStack.axis = .vertical
        tiersStack.spacing = 11
        let cardStack = UIStackView(arrangedSubviews: [title, tiersStack])
        cardStack.axis = .vertical
        cardStack.spacing = 15
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 15),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 22),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
        contentStack.addArrangedSubview(card)

        buildPurchaseOverlay()
        if tiers.isEmpty {
            showProductsLoading()
            DispatchQueue.main.async { [weak self] in self?.onLoadProducts?() }
        }
    }

    func setBalance(_ value: Int) {
        balanceLabel.text = "\(value)"
    }

    func setTiers(_ tiers: [Tier]) {
        self.tiers = tiers
        tiersStack.arrangedSubviews.forEach {
            tiersStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        for start in stride(from: 0, to: tiers.count, by: 2) {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.alignment = .fill
            row.spacing = 11
            for index in start..<min(start + 2, tiers.count) {
                let tier = tiers[index]
                let view = RechargeTierView()
                view.configure(amount: tier.diamonds, price: tier.price)
                view.onContinue = { [weak self] in self?.onSelectTier?(tier) }
                row.addArrangedSubview(view)
            }
            if row.arrangedSubviews.count == 1 {
                let placeholder = UIView()
                placeholder.backgroundColor = .clear
                placeholder.isUserInteractionEnabled = false
                row.addArrangedSubview(placeholder)
            }
            tiersStack.addArrangedSubview(row)
        }
        if isViewLoaded { render(state: .content) }
    }

    func showProductsLoading() {
        guard isViewLoaded else { return }
        render(state: .loading)
    }

    func showProductsError(_ message: String) {
        guard isViewLoaded else { return }
        render(state: .parseError(message), retry: onLoadProducts)
    }

    func setPurchaseLoading(_ isLoading: Bool) {
        guard isViewLoaded else { return }
        purchaseOverlay.isHidden = !isLoading
        view.isUserInteractionEnabled = !isLoading
        if isLoading {
            purchaseIndicator.startAnimating()
        } else {
            purchaseIndicator.stopAnimating()
        }
    }

    private func makeBalanceBlock() -> UIView {
        let holder = UIView()
        let diamond = UIImageView(image: UIImage(named: "diamond")?.withRenderingMode(.alwaysOriginal))
        diamond.contentMode = .scaleAspectFit
        if balanceLabel.text == nil { balanceLabel.text = "0" }
        balanceLabel.font = rechargeRoundedFont(50, weight: .bold)
        balanceLabel.textAlignment = .center
        balanceLabel.minimumScaleFactor = 0.65
        balanceLabel.adjustsFontSizeToFitWidth = true
        let caption = kinvaProfileLabel(text: "Current Balance", size: 20, weight: .bold, color: UIColor(hex: 0xC5CDD2), textStyle: .title3)
        caption.font = rechargeRoundedFont(20, weight: .bold)
        caption.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [diamond, balanceLabel, caption])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        holder.addSubview(stack)
        NSLayoutConstraint.activate([
            holder.heightAnchor.constraint(equalToConstant: 181),
            stack.topAnchor.constraint(equalTo: holder.topAnchor, constant: 10),
            stack.centerXAnchor.constraint(equalTo: holder.centerXAnchor),
            stack.bottomAnchor.constraint(equalTo: holder.bottomAnchor, constant: -12),
            diamond.widthAnchor.constraint(equalToConstant: 88),
            diamond.heightAnchor.constraint(equalToConstant: 65),
            balanceLabel.widthAnchor.constraint(lessThanOrEqualTo: holder.widthAnchor, constant: -42)
        ])
        return holder
    }

    private func buildPurchaseOverlay() {
        purchaseOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        purchaseOverlay.isHidden = true
        purchaseOverlay.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = .white
        card.round(18)
        card.translatesAutoresizingMaskIntoConstraints = false
        purchaseIndicator.color = AppTheme.blue
        purchaseStatusLabel.text = "Processing purchase…"
        purchaseStatusLabel.font = rechargeRoundedFont(16, weight: .bold)
        purchaseStatusLabel.textColor = AppTheme.text
        purchaseStatusLabel.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [purchaseIndicator, purchaseStatusLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        purchaseOverlay.addSubview(card)
        view.addSubview(purchaseOverlay)

        NSLayoutConstraint.activate([
            purchaseOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            purchaseOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            purchaseOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            purchaseOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            card.centerXAnchor.constraint(equalTo: purchaseOverlay.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: purchaseOverlay.centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 220),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24)
        ])
    }

    @objc private func backTapped() { onBack?() }
}

private func rechargeRoundedFont(_ size: CGFloat, weight: UIFont.Weight) -> UIFont {
    let base = UIFont.systemFont(ofSize: size, weight: weight)
    guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
    return UIFont(descriptor: descriptor, size: size)
}
