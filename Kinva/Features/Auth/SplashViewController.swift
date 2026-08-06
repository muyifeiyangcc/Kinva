import UIKit

final class SplashViewController: UIViewController {
    let backgroundImageView = UIImageView()
    let brandLabel = kinvaAuthLabel(text: "KINVA", size: 54, weight: .bold, textStyle: .largeTitle)
    let taglineLabel = kinvaAuthLabel(text: "EXPRESS, CREATE & CONNECT", size: 18, weight: .bold, textStyle: .headline)

    init(backgroundImage: UIImage? = nil) {
        super.init(nibName: nil, bundle: nil)
        backgroundImageView.image = backgroundImage
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background
        backgroundImageView.backgroundColor = UIColor(hex: 0xD8D2C8)
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true

        let panel = KinvaCurvedTopView()
        panel.backgroundColor = AppTheme.background
        brandLabel.textAlignment = .center
        brandLabel.minimumScaleFactor = 0.7
        brandLabel.adjustsFontSizeToFitWidth = true
        taglineLabel.textAlignment = .center
        taglineLabel.minimumScaleFactor = 0.75
        taglineLabel.adjustsFontSizeToFitWidth = true

        [backgroundImageView, panel, brandLabel, taglineLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.68),

            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panel.topAnchor.constraint(equalTo: backgroundImageView.bottomAnchor, constant: -50),
            panel.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            brandLabel.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            brandLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 92),
            brandLabel.leadingAnchor.constraint(greaterThanOrEqualTo: panel.leadingAnchor, constant: 24),
            brandLabel.trailingAnchor.constraint(lessThanOrEqualTo: panel.trailingAnchor, constant: -24),
            taglineLabel.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            taglineLabel.topAnchor.constraint(equalTo: brandLabel.bottomAnchor, constant: 34),
            taglineLabel.leadingAnchor.constraint(greaterThanOrEqualTo: panel.leadingAnchor, constant: 20),
            taglineLabel.trailingAnchor.constraint(lessThanOrEqualTo: panel.trailingAnchor, constant: -20)
        ])

        brandLabel.accessibilityTraits = .header
        taglineLabel.accessibilityLabel = "Express, create and connect"
    }
}
