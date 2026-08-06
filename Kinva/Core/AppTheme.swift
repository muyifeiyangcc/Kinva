import UIKit

enum AppTheme {
    static let blue = UIColor(hex: 0x0B3FFF)
    static let pink = UIColor(hex: 0xFF4D9A)
    static let background = UIColor(hex: 0xF7F9FA)
    static let text = UIColor(hex: 0x141414)
    static let secondaryText = UIColor(hex: 0x4D4D4E)
    static let mutedText = UIColor(hex: 0xA2A3A4)
    static let paleBlue = UIColor(hex: 0xE7EBFF)
    static let field = UIColor(hex: 0xF4F6F8)

    static func font(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: weight)
    }
}

extension UIColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xff) / 255,
                  green: CGFloat((hex >> 8) & 0xff) / 255,
                  blue: CGFloat(hex & 0xff) / 255,
                  alpha: alpha)
    }
}

extension UIView {
    func round(_ radius: CGFloat) {
        layer.cornerRadius = radius
        layer.cornerCurve = .continuous
        clipsToBounds = true
    }

    func applyCardShadow() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 7)
        layer.masksToBounds = false
    }
}

extension UIImage {
    static func symbol(_ name: String, size: CGFloat = 18, weight: UIImage.SymbolWeight = .semibold) -> UIImage? {
        UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: weight))
    }
}
