import UIKit

final class ImageBrowserViewController: UIViewController, UIScrollViewDelegate {
    private let tokens: [String]
    private let startIndex: Int
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let closeButton = UIButton(type: .system)
    private let pageLabel = UILabel()
    private var currentIndex: Int = 0
    private var didSetInitialOffset = false

    init(tokens: [String], startIndex: Int = 0) {
        self.tokens = tokens.isEmpty ? [""] : tokens
        self.startIndex = max(0, min(startIndex, max(tokens.count - 1, 0)))
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .black
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.alwaysBounceHorizontal = tokens.count > 1
        view.addSubview(scrollView)

        stack.axis = .horizontal
        stack.distribution = .fill
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        closeButton.setImage(.symbol("xmark", size: 18, weight: .bold), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        closeButton.round(15)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)

        pageLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .bold)
        pageLabel.textColor = .white
        pageLabel.textAlignment = .right
        pageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),
            pageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            pageLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -22)
        ])

        buildPages()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard scrollView.bounds.width > 0 else { return }
        if !didSetInitialOffset {
            let offset = CGFloat(startIndex) * scrollView.bounds.width
            scrollView.setContentOffset(CGPoint(x: offset, y: 0), animated: false)
            didSetInitialOffset = true
        }
        updateLabel()
    }

    private func buildPages() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, token) in tokens.enumerated() {
            let page = ImageBrowserPageView(token: token.isEmpty ? nil : token, index: index)
            page.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(page)
            page.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor).isActive = true
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { updateLabel() }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) { if !decelerate { updateLabel() } }

    private func updateLabel() {
        let width = max(scrollView.bounds.width, 1)
        currentIndex = max(0, min(Int(round(scrollView.contentOffset.x / width)), max(tokens.count - 1, 0)))
        pageLabel.text = String(format: "%02d/%02d", currentIndex + 1, max(tokens.count, 1))
    }

    @objc private func closeTapped() {
        navigationController?.popViewController(animated: true)
    }
}

private final class ImageBrowserPageView: UIView {
    init(token: String?, index: Int) {
        super.init(frame: .zero)
        backgroundColor = .black
        let imageView = SocialPostImageView(token: token, index: index, cornerRadius: 0)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}
