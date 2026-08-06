import UIKit

/// A deterministic local artwork placeholder. It keeps every media slot at its design size
/// until final bundled artwork replaces it; it never downloads remote content.
final class DanceArtworkView: UIView {
    private let gradient = CAGradientLayer()
    private let figure = UIImageView()
    private let caption = UILabel()

    init(style: Int = 0, caption: String? = nil) {
        super.init(frame: .zero)
        let palettes: [[UIColor]] = [
            [UIColor(hex: 0xC9E5F4), UIColor(hex: 0xF0C4C0), UIColor(hex: 0xB7C5D4)],
            [UIColor(hex: 0x342724), UIColor(hex: 0x8B5A49), UIColor(hex: 0xD2A685)],
            [UIColor(hex: 0xB8D8FC), UIColor(hex: 0xE9F0FA), UIColor(hex: 0x365E99)],
            [UIColor(hex: 0xE9CBBE), UIColor(hex: 0xC786A6), UIColor(hex: 0x694A72)]
        ]
        gradient.colors = palettes[abs(style) % palettes.count].map(\.cgColor)
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(gradient)
        figure.image = .symbol("figure.dance", size: 80, weight: .regular)
        figure.tintColor = UIColor.white.withAlphaComponent(0.78)
        figure.contentMode = .scaleAspectFit
        figure.translatesAutoresizingMaskIntoConstraints = false
        addSubview(figure)
        self.caption.text = caption
        self.caption.font = AppTheme.font(12, .semibold)
        self.caption.textColor = .white
        self.caption.numberOfLines = 2
        self.caption.translatesAutoresizingMaskIntoConstraints = false
        addSubview(self.caption)
        NSLayoutConstraint.activate([
            figure.centerXAnchor.constraint(equalTo: centerXAnchor),
            figure.centerYAnchor.constraint(equalTo: centerYAnchor),
            figure.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.55),
            figure.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.55),
            self.caption.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            self.caption.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            self.caption.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
        clipsToBounds = true
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() { super.layoutSubviews(); gradient.frame = bounds }
}

final class PillButton: UIButton {
    var isPillSelected: Bool = false { didSet { refresh() } }
    init(title: String) {
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        titleLabel?.font = AppTheme.font(12, .semibold)
        contentEdgeInsets = UIEdgeInsets(top: 9, left: 16, bottom: 9, right: 16)
        round(18)
        refresh()
    }
    required init?(coder: NSCoder) { fatalError() }
    private func refresh() {
        backgroundColor = isPillSelected ? AppTheme.blue : AppTheme.paleBlue
        setTitleColor(isPillSelected ? .white : AppTheme.text, for: .normal)
    }
}
