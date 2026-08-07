import AVFoundation
import AVKit
import UIKit

final class ChallengeHomeViewController: BaseScrollViewController {
    var onCreateChallenge: (() -> Void)?
    var onInspiration: (() -> Void)?
    var onChallenge: ((KinvaChallenge) -> Void)?
    private let store = LocalDataStore.shared
    private let carousel = ChallengeCardCarouselView()

    override func viewDidLoad() {
        super.viewDidLoad()
        // The home artwork is designed to continue behind the status bar.
        // Disable UIKit's automatic safe-area inset only for this screen.
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        extendedLayoutIncludesOpaqueBars = true
        edgesForExtendedLayout = .all
        contentStack.spacing = 0
        buildHero()
        buildAICard()
        contentStack.addSpacer(7)
        carousel.translatesAutoresizingMaskIntoConstraints = false
        carousel.heightAnchor.constraint(equalTo: carousel.widthAnchor, multiplier: 1.024).isActive = true
        contentStack.addArrangedSubview(carousel)
        // Keep enough scroll range to lift the final card clear of the floating
        // tab bar on compact-height and zoomed-display configurations.
        contentStack.addSpacer(80)
        reloadChallenges()
        NotificationCenter.default.addObserver(self, selector: #selector(dataChanged), name: LocalDataStore.didChangeNotification, object: nil)
    }

    private func buildHero() {
        let hero = UIImageView(image: UIImage(named: "home_banner"))
        hero.contentMode = .scaleAspectFill
        hero.clipsToBounds = true
        hero.isUserInteractionEnabled = true
        hero.isAccessibilityElement = true
        hero.accessibilityLabel = "Start the challenge"
        hero.accessibilityTraits = .button
        hero.translatesAutoresizingMaskIntoConstraints = false
        hero.heightAnchor.constraint(equalTo: hero.widthAnchor, multiplier: 0.544).isActive = true
        hero.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(createTapped)))
        contentStack.addArrangedSubview(hero)
    }

    private func buildAICard() {
        let wrapper = UIView()
        wrapper.heightAnchor.constraint(equalTo: wrapper.widthAnchor, multiplier: 0.333).isActive = true
        let card = UIImageView(image: UIImage(named: "home_ai_bg"))
        card.contentMode = .scaleToFill
        card.translatesAutoresizingMaskIntoConstraints = false
        let title = UILabel(); title.text = "KINVA AI"; title.font = roundedFont(27, .heavy); title.textColor = .white
        let subtitle = UILabel(); subtitle.text = "Your smart coach for movement, stretch, \n and creative expression."; subtitle.numberOfLines = 2; subtitle.font = roundedFont(13, .bold); subtitle.textColor = .white
        let get = UIButton(type: .system); get.setTitle("Get", for: .normal); get.setTitleColor(.black, for: .normal); get.backgroundColor = .white; get.titleLabel?.font = roundedFont(14, .bold); get.round(14)
        [title, subtitle, get].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; wrapper.addSubview($0) }
        get.isUserInteractionEnabled = false
        wrapper.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(aiTapped)))
        card.translatesAutoresizingMaskIntoConstraints = false
        wrapper.insertSubview(card, at: 0)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 2),
            card.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -1),
            card.topAnchor.constraint(equalTo: wrapper.topAnchor),
            card.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            title.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 31),
            title.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 22),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 1),
            get.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -29),
            get.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 69),
            get.widthAnchor.constraint(equalToConstant: 64),
            get.heightAnchor.constraint(equalToConstant: 28)
        ])
        contentStack.addArrangedSubview(wrapper)
    }

    @objc private func dataChanged() { reloadChallenges() }
    private func reloadChallenges() {
        guard store.parseFailure == nil else { render(state: .parseError("Challenge data could not be parsed.")) { [weak self] in self?.store.resetMockData(); self?.reloadChallenges() }; return }
        let values = store.visibleChallenges()
        guard !values.isEmpty else { render(state: .empty("No challenges yet. Create the first one.")); return }
        render(state: .content)
        // Home and detail must expose the exact same challenge collection.
        // The carousel handles stacking visually, so there is no need to pad
        // or truncate the underlying data to three items.
        carousel.setChallenges(values) { [weak self] challenge in self?.onChallenge?(challenge) }
    }
    @objc private func createTapped() { onCreateChallenge?() }
    @objc private func aiTapped() { onInspiration?() }
}

final class ChallengeCardView: UIView {
    var onTap: (() -> Void)?
    let tapGesture = UITapGestureRecognizer()
    private let content = UIView()
    private let thumbnail = UIImageView()
    private let stackIndicator = UIView()
    private let shade = CAGradientLayer()
    private let representedID: String

    init(challenge: KinvaChallenge, style _: Int) {
        representedID = challenge.id
        super.init(frame: .zero)
        layer.cornerRadius = 34
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor(hex: 0x234B9A).cgColor
        layer.shadowOpacity = 0.19
        layer.shadowRadius = 15
        layer.shadowOffset = CGSize(width: 0, height: 10)
        content.round(34)
        content.backgroundColor = .black
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        thumbnail.contentMode = .scaleAspectFill
        thumbnail.clipsToBounds = true
        thumbnail.image = ChallengeVideoThumbnailProvider.cachedImage(tokens: challenge.mediaTokens)
        thumbnail.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(thumbnail)
        let imageWash = UIView()
        imageWash.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        imageWash.isUserInteractionEnabled = false
        imageWash.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(imageWash)
        shade.colors = [UIColor.white.withAlphaComponent(0.05).cgColor, UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.46).cgColor]
        shade.locations = [0, 0.52, 1]
        content.layer.addSublayer(shade)
        let title = UILabel(); title.text = challenge.title; title.font = roundedFont(30, .heavy); title.textColor = .white; title.numberOfLines = 2
        let button = UIButton(type: .system); button.setTitle("Join Challenge", for: .normal); button.setTitleColor(.white, for: .normal); button.backgroundColor = AppTheme.blue; button.titleLabel?.font = roundedFont(21, .bold); button.round(27); button.isUserInteractionEnabled = false
        stackIndicator.backgroundColor = .white
        stackIndicator.round(4)
        stackIndicator.alpha = 0
        stackIndicator.isUserInteractionEnabled = false
        [title, button, stackIndicator].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; content.addSubview($0) }
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor), content.leadingAnchor.constraint(equalTo: leadingAnchor), content.trailingAnchor.constraint(equalTo: trailingAnchor), content.bottomAnchor.constraint(equalTo: bottomAnchor),
            thumbnail.topAnchor.constraint(equalTo: content.topAnchor), thumbnail.leadingAnchor.constraint(equalTo: content.leadingAnchor), thumbnail.trailingAnchor.constraint(equalTo: content.trailingAnchor), thumbnail.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            imageWash.topAnchor.constraint(equalTo: content.topAnchor), imageWash.leadingAnchor.constraint(equalTo: content.leadingAnchor), imageWash.trailingAnchor.constraint(equalTo: content.trailingAnchor), imageWash.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            title.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 30), title.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18), title.topAnchor.constraint(equalTo: content.topAnchor, constant: 34),
            button.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 39), button.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -39), button.heightAnchor.constraint(equalToConstant: 54), button.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -42),
            stackIndicator.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 17),
            stackIndicator.centerYAnchor.constraint(equalTo: content.centerYAnchor, constant: 8),
            stackIndicator.widthAnchor.constraint(equalToConstant: 8),
            stackIndicator.heightAnchor.constraint(equalToConstant: 66)
        ])
        tapGesture.addTarget(self, action: #selector(tap))
        addGestureRecognizer(tapGesture)
        ChallengeVideoThumbnailProvider.load(tokens: challenge.mediaTokens) { [weak self] image in
            guard let self, self.representedID == challenge.id else { return }
            self.thumbnail.image = image
        }
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() { super.layoutSubviews(); shade.frame = content.bounds }
    func setStackIndicatorAlpha(_ alpha: CGFloat) { stackIndicator.alpha = alpha }
    @objc private func tap() { onTap?() }
}

private final class ChallengeCardCarouselView: UIView, UIGestureRecognizerDelegate {
    private let visibleCardCount = 3
    private var cards: [ChallengeCardView] = []
    private var challenges: [KinvaChallenge] = []
    private var selection: ((KinvaChallenge) -> Void)?
    private var isInteracting = false
    private weak var owningScrollView: UIScrollView?
    private lazy var pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        pan.delegate = self
        pan.cancelsTouchesInView = false
        pan.delaysTouchesBegan = false
        pan.maximumNumberOfTouches = 1
        addGestureRecognizer(pan)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        var ancestor = superview
        while let view = ancestor {
            if let scrollView = view as? UIScrollView {
                guard owningScrollView !== scrollView else { return }
                owningScrollView = scrollView
                // This is the same gesture arbitration used by established
                // card stacks: horizontal card dragging gets first refusal.
                // When our delegate rejects a vertical gesture, the page
                // scroll view immediately takes over.
                scrollView.panGestureRecognizer.require(toFail: pan)
                return
            }
            ancestor = view.superview
        }
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === pan else { return true }
        let velocity = pan.velocity(in: self)
        // Only a deliberate right swipe belongs to the deck. Vertical and
        // leftward motion fails early so the page remains naturally scrollable.
        return velocity.x > 0 && abs(velocity.x) > abs(velocity.y) * 1.08
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Simultaneous recognition with the owning scroll view was resetting
        // the card transforms on every scroll-layout pass.
        guard otherGestureRecognizer !== owningScrollView?.panGestureRecognizer else { return false }
        return false
    }

    func setChallenges(_ values: [KinvaChallenge], selection: @escaping (KinvaChallenge) -> Void) {
        guard values.map(\.id) != challenges.map(\.id) || cards.isEmpty else { self.selection = selection; return }
        cards.forEach { $0.removeFromSuperview() }
        challenges = values
        self.selection = selection
        cards = values.enumerated().map { index, challenge in
            let card = ChallengeCardView(challenge: challenge, style: index)
            card.tapGesture.require(toFail: pan)
            card.onTap = { [weak self, weak card] in
                guard let self, let card, card === self.cards.first, let challenge = self.challenges.first else { return }
                self.selection?(challenge)
            }
            return card
        }
        cards.reversed().forEach(addSubview)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !bounds.isEmpty else { return }
        // Never overwrite presentation transforms while the user's finger or
        // the completion animator is driving the stack.
        guard !isInteracting else { return }
        cards.forEach { $0.bounds = CGRect(origin: .zero, size: CGSize(width: bounds.width * 0.78, height: bounds.height * 0.995)); $0.center = CGPoint(x: bounds.width * 0.61, y: bounds.height * 0.5) }
        applyRestingState()
    }

    private func restingTransform(depth: Int) -> CGAffineTransform {
        // Match the stepped silhouette in the design: the front card reaches
        // lowest, while every rear card is both smaller and ends higher. Keep
        // their centers nearly aligned vertically so promotion still reads as
        // an upward/right expansion instead of a vertical card translation.
        let scales: [CGFloat] = [1, 0.84, 0.72, 0.64]
        let horizontalOffsets: [CGFloat] = [0, -0.16, -0.27, -0.36]
        let verticalOffsets: [CGFloat] = [0, -0.005, -0.01, -0.015]
        let visibleDepth = min(depth, scales.count - 1)
        let scale = scales[visibleDepth]
        let tx = bounds.width * horizontalOffsets[visibleDepth]
        let ty = bounds.height * verticalOffsets[visibleDepth]
        return CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: tx, ty: ty)
    }

    private func applyRestingState() {
        for (depth, card) in cards.enumerated() {
            card.transform = restingTransform(depth: depth)
            card.alpha = depth < visibleCardCount ? 1 : 0
            card.setStackIndicatorAlpha((1..<visibleCardCount).contains(depth) ? 1 : 0)
            card.layer.zPosition = CGFloat(cards.count - depth)
            card.isUserInteractionEnabled = depth == 0
        }
    }

    @objc private func panned(_ gesture: UIPanGestureRecognizer) {
        guard cards.count > 1 else { return }
        let point = gesture.translation(in: self)
        let translation = max(0, point.x)
        let progress = min(1, translation / max(1, bounds.width * 0.55))
        switch gesture.state {
        case .began:
            isInteracting = true
            fallthrough
        case .changed:
            let front = cards[0]
            let verticalFollow = min(0, point.y) * 0.12 - 8 * progress
            front.transform = CGAffineTransform(translationX: translation, y: verticalFollow)
                .rotated(by: 0.035 * progress)
            front.alpha = 1 - progress * 0.18

            // Include one currently hidden card so it fades into the third
            // layer while every visible layer advances from its own position.
            let advancingCount = min(cards.count, visibleCardCount + 1)
            for depth in 1..<advancingCount {
                let start = restingTransform(depth: depth)
                let end = restingTransform(depth: depth - 1)
                cards[depth].transform = interpolate(from: start, to: end, progress: progress)
                cards[depth].alpha = depth == visibleCardCount ? progress : 1
                let startIndicator: CGFloat = (1..<visibleCardCount).contains(depth) ? 1 : 0
                let promotedDepth = depth - 1
                let endIndicator: CGFloat = (1..<visibleCardCount).contains(promotedDepth) ? 1 : 0
                cards[depth].setStackIndicatorAlpha(startIndicator + (endIndicator - startIndicator) * progress)
            }
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: self).x
            let projectedProgress = progress + max(0, velocity) / 2_400
            if gesture.state == .ended && projectedProgress > 0.34 {
                completeAdvance(initialVelocity: velocity)
            } else {
                let animator = UIViewPropertyAnimator(duration: 0.34, dampingRatio: 0.84) {
                    self.applyRestingState()
                }
                animator.addCompletion { _ in
                    self.isInteracting = false
                    self.setNeedsLayout()
                }
                animator.startAnimation()
            }
        default: break
        }
    }

    private func completeAdvance(initialVelocity: CGFloat) {
        guard let outgoing = cards.first, let outgoingChallenge = challenges.first else { return }
        let speed = max(0, initialVelocity)
        let duration = max(0.18, min(0.34, 0.32 - TimeInterval(speed / 8_000)))
        UIView.animate(withDuration: duration,
                       delay: 0,
                       options: [.curveEaseOut, .beginFromCurrentState],
                       animations: {
            outgoing.transform = CGAffineTransform(translationX: self.bounds.width * 1.15, y: -12)
                .rotated(by: 0.05)
            outgoing.alpha = 0
            let advancingCount = min(self.cards.count, self.visibleCardCount + 1)
            for depth in 1..<advancingCount {
                self.cards[depth].transform = self.restingTransform(depth: depth - 1)
                self.cards[depth].alpha = depth - 1 < self.visibleCardCount ? 1 : 0
                self.cards[depth].setStackIndicatorAlpha((1..<self.visibleCardCount).contains(depth - 1) ? 1 : 0)
            }
        }, completion: { _ in
            self.cards.removeFirst(); self.cards.append(outgoing)
            self.challenges.removeFirst(); self.challenges.append(outgoingChallenge)
            self.sendSubviewToBack(outgoing)
            self.isInteracting = false
            self.applyRestingState()
            self.setNeedsLayout()
        })
    }

    private func interpolate(from: CGAffineTransform, to: CGAffineTransform, progress: CGFloat) -> CGAffineTransform {
        CGAffineTransform(a: from.a + (to.a - from.a) * progress,
                          b: from.b + (to.b - from.b) * progress,
                          c: from.c + (to.c - from.c) * progress,
                          d: from.d + (to.d - from.d) * progress,
                          tx: from.tx + (to.tx - from.tx) * progress,
                          ty: from.ty + (to.ty - from.ty) * progress)
    }
}

enum ChallengeVideoThumbnailProvider {
    private static let cache = NSCache<NSString, UIImage>()

    static func cachedImage(tokens: [String]) -> UIImage? {
        guard let key = cacheKey(tokens: tokens) else { return nil }
        return cache.object(forKey: key)
    }

    static func load(tokens: [String], completion: @escaping (UIImage?) -> Void) {
        guard let path = tokens.lazy.compactMap({ kinvaMediaFilePath(token: $0) }).first else { completion(nil); return }
        let key = path as NSString
        if let image = cache.object(forKey: key) {
            completion(image)
            return
        }
        let url = URL(fileURLWithPath: path)
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 900, height: 1200)
            let image = try? generator.copyCGImage(at: CMTime(seconds: 0.08, preferredTimescale: 600), actualTime: nil)
            let thumbnail = image.map(UIImage.init(cgImage:))
            if let thumbnail { cache.setObject(thumbnail, forKey: key) }
            DispatchQueue.main.async { completion(thumbnail) }
        }
    }

    private static func cacheKey(tokens: [String]) -> NSString? {
        guard let path = tokens.lazy.compactMap({ kinvaMediaFilePath(token: $0) }).first else { return nil }
        return path as NSString
    }
}

private func roundedFont(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
    let base = UIFont.systemFont(ofSize: size, weight: weight)
    guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
    return UIFont(descriptor: descriptor, size: size)
}

private func configureLabel(_ label: UILabel, size: CGFloat, weight: UIFont.Weight, lines: Int = 1) {
    label.font = roundedFont(size, weight)
    label.textColor = .white
    label.numberOfLines = lines
    label.adjustsFontSizeToFitWidth = false
}

private func detailButton(_ symbol: String) -> UIButton {
    let button = UIButton(type: .system)
    button.setImage(.symbol(symbol, size: 20, weight: .bold), for: .normal)
    button.tintColor = .white
    button.backgroundColor = .black
    button.round(12)
    return button
}

final class CreateChallengeViewController: BaseScrollViewController, UITextViewDelegate {
    var onPublished: ((KinvaChallenge) -> Void)?
    var onChooseVideo: (() -> Void)?
    var onRecordVideo: (() -> Void)?
    private let descriptionView = UITextView()
    private let priceField = UITextField()
    private var hasMedia = false
    private var mediaTokens: [String] = []
    private let media = UIView()
    private let mediaPreview = UIImageView()
    private let uploadSymbol = UIImageView(image: UIImage(named: "video"))
    private let uploadText = UILabel()
    private let removeButton = UIButton(type: .system)
    private let categories = ["Stretch Performance", "Freestyle Movement", "Dance Flow"]
    private var selectedCategory = "Stretch Performance"

    override func viewDidLoad() {
        super.viewDidLoad()
        contentStack.spacing = 0
        let header = AppHeaderView(title: "Challenge")
        header.backButton.addTarget(self, action: #selector(back), for: .touchUpInside)
        contentStack.addArrangedSubview(header)
        buildMedia()
        buildForm()
    }

    private func buildMedia() {
        let wrap = UIView(); wrap.heightAnchor.constraint(equalToConstant: 288).isActive = true
        media.backgroundColor = .white; media.round(22); media.translatesAutoresizingMaskIntoConstraints = false; media.clipsToBounds = true; wrap.addSubview(media)
        mediaPreview.contentMode = .scaleAspectFill; mediaPreview.clipsToBounds = true; mediaPreview.translatesAutoresizingMaskIntoConstraints = false; media.addSubview(mediaPreview)
        uploadSymbol.contentMode = .scaleAspectFit; uploadSymbol.translatesAutoresizingMaskIntoConstraints = false; media.addSubview(uploadSymbol)
        uploadText.text = "Upload or record a\nvideo"; uploadText.numberOfLines = 2; uploadText.textAlignment = .center; uploadText.font = roundedFont(14, .bold); uploadText.translatesAutoresizingMaskIntoConstraints = false; media.addSubview(uploadText)
        removeButton.setImage(.symbol("minus", size: 15, weight: .bold), for: .normal); removeButton.tintColor = .white; removeButton.backgroundColor = AppTheme.blue; removeButton.round(18); removeButton.translatesAutoresizingMaskIntoConstraints = false; removeButton.isHidden = true; removeButton.addTarget(self, action: #selector(removeMedia), for: .touchUpInside); media.addSubview(removeButton)
        NSLayoutConstraint.activate([
            media.widthAnchor.constraint(equalToConstant: 186), media.heightAnchor.constraint(equalToConstant: 263), media.centerXAnchor.constraint(equalTo: wrap.centerXAnchor), media.centerYAnchor.constraint(equalTo: wrap.centerYAnchor),
            mediaPreview.topAnchor.constraint(equalTo: media.topAnchor), mediaPreview.leadingAnchor.constraint(equalTo: media.leadingAnchor), mediaPreview.trailingAnchor.constraint(equalTo: media.trailingAnchor), mediaPreview.bottomAnchor.constraint(equalTo: media.bottomAnchor),
            uploadSymbol.centerXAnchor.constraint(equalTo: media.centerXAnchor), uploadSymbol.centerYAnchor.constraint(equalTo: media.centerYAnchor, constant: -29), uploadSymbol.widthAnchor.constraint(equalToConstant: 62), uploadSymbol.heightAnchor.constraint(equalToConstant: 62),
            uploadText.centerXAnchor.constraint(equalTo: media.centerXAnchor), uploadText.topAnchor.constraint(equalTo: uploadSymbol.bottomAnchor, constant: 18), uploadText.leadingAnchor.constraint(greaterThanOrEqualTo: media.leadingAnchor, constant: 12), uploadText.trailingAnchor.constraint(lessThanOrEqualTo: media.trailingAnchor, constant: -12),
            removeButton.topAnchor.constraint(equalTo: media.topAnchor, constant: -1), removeButton.trailingAnchor.constraint(equalTo: media.trailingAnchor, constant: 1), removeButton.widthAnchor.constraint(equalToConstant: 38), removeButton.heightAnchor.constraint(equalToConstant: 38)
        ])
        media.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(selectMedia)))
        contentStack.addArrangedSubview(wrap)
    }

    private func buildForm() {
        let form = UIView(); form.backgroundColor = .white; form.layer.cornerRadius = 24; form.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 14; stack.translatesAutoresizingMaskIntoConstraints = false; form.addSubview(stack)
        let title = UILabel(); title.text = "Information"; title.font = roundedFont(28, .heavy)
        let pills = UIStackView(); pills.axis = .horizontal; pills.spacing = 9
        for (i, category) in categories.enumerated() { let p = PillButton(title: category); p.tag = i; p.isPillSelected = i == 0; p.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside); pills.addArrangedSubview(p) }
        let horizontal = UIScrollView(); horizontal.showsHorizontalScrollIndicator = false; pills.translatesAutoresizingMaskIntoConstraints = false; horizontal.addSubview(pills)
        NSLayoutConstraint.activate([pills.topAnchor.constraint(equalTo: horizontal.contentLayoutGuide.topAnchor), pills.bottomAnchor.constraint(equalTo: horizontal.contentLayoutGuide.bottomAnchor), pills.leadingAnchor.constraint(equalTo: horizontal.contentLayoutGuide.leadingAnchor), pills.trailingAnchor.constraint(equalTo: horizontal.contentLayoutGuide.trailingAnchor), pills.heightAnchor.constraint(equalTo: horizontal.frameLayoutGuide.heightAnchor), horizontal.heightAnchor.constraint(equalToConstant: 38)])
        descriptionView.text = "Please enter…"; descriptionView.textColor = AppTheme.mutedText; descriptionView.font = roundedFont(14, .semibold); descriptionView.backgroundColor = AppTheme.field; descriptionView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 15, right: 12); descriptionView.round(14); descriptionView.heightAnchor.constraint(equalToConstant: 52).isActive = true; descriptionView.delegate = self
        priceField.placeholder = "Example 300"; priceField.keyboardType = .numberPad; priceField.font = roundedFont(14, .semibold); priceField.backgroundColor = AppTheme.field; priceField.round(14); priceField.heightAnchor.constraint(equalToConstant: 52).isActive = true; priceField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 52)); priceField.leftViewMode = .always
        let publish = BrandButton(title: "Publish"); publish.addTarget(self, action: #selector(publishTapped), for: .touchUpInside)
        [title, horizontal, fieldTitle("Description"), descriptionView, fieldTitle("Set Diamond Lock  (Optional)"), priceField, publish].forEach(stack.addArrangedSubview)
        NSLayoutConstraint.activate([stack.topAnchor.constraint(equalTo: form.topAnchor, constant: 18), stack.leadingAnchor.constraint(equalTo: form.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: form.trailingAnchor, constant: -20), stack.bottomAnchor.constraint(equalTo: form.bottomAnchor, constant: -25)])
        contentStack.addArrangedSubview(form)
    }

    private func fieldTitle(_ text: String) -> UILabel { let l = UILabel(); l.text = text; l.textColor = UIColor(hex: 0x435D88); l.font = AppTheme.font(14, .semibold); return l }
    func textViewDidBeginEditing(_ textView: UITextView) { if textView.text == "Please enter…" { textView.text = ""; textView.textColor = AppTheme.text } }
    @objc private func categoryTapped(_ sender: PillButton) { selectedCategory = categories[sender.tag]; sender.superview?.subviews.compactMap { $0 as? PillButton }.forEach { $0.isPillSelected = $0 === sender } }
    func setMediaTokens(_ tokens: [String]) {
        mediaTokens = tokens
        hasMedia = !tokens.isEmpty
        mediaPreview.image = nil
        mediaPreview.isHidden = !hasMedia
        uploadSymbol.isHidden = hasMedia
        uploadText.isHidden = hasMedia
        removeButton.isHidden = !hasMedia
        guard hasMedia else { return }
        let selectedToken = tokens[0]
        ChallengeVideoThumbnailProvider.load(tokens: tokens) { [weak self] image in
            guard self?.mediaTokens.first == selectedToken else { return }
            self?.mediaPreview.image = image
        }
    }
    @objc private func selectMedia() {
        guard !hasMedia else { return }
        showKinvaActionSheet(items: [
            KinvaActionSheetItem(title: "Choose from Photo Library") { [weak self] in self?.onChooseVideo?() },
            KinvaActionSheetItem(title: "Record with Camera") { [weak self] in self?.onRecordVideo?() },
            KinvaActionSheetItem(title: "Cancel", style: .cancel, handler: {})
        ])
    }
    @objc private func removeMedia() { setMediaTokens([]) }
    @objc private func publishTapped() {
        guard hasMedia else { showLocalAlert(title: "Select a video", message: "Choose a local video before publishing."); return }
        let detail = descriptionView.text == "Please enter…" ? "" : descriptionView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !detail.isEmpty else { showLocalAlert(title: "Add a description", message: "Describe the challenge before publishing."); return }
        do { let item = try LocalDataStore.shared.createChallenge(title: selectedCategory, detail: detail, category: selectedCategory, price: max(0, Int(priceField.text ?? "") ?? 0), mediaTokens: mediaTokens); onPublished?(item) } catch { showLocalAlert(title: "Could not publish", message: error.localizedDescription) }
    }
    @objc private func back() { navigationController?.popViewController(animated: true) }
}

final class ChallengeDetailViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var onAuthor: ((String) -> Void)?
    var onAccess: ((KinvaChallenge) -> Void)?
    var challenge: KinvaChallenge
    private let store = LocalDataStore.shared
    private let frameView: ChallengeVideoFrameView
    private let titleLabel = UILabel()
    private let participantsLabel = UILabel()
    private let detailLabel = UILabel()
    private let authorAvatar = AvatarView(name: "", size: 44)
    private let authorButton = UIButton(type: .system)
    private let joinedAvatarsView = ChallengeJoinedAvatarsView()
    private let likePill = ChallengeLikePillView()
    private let joinButton = UIButton(type: .system)
    private let thumbnailCollectionView: UICollectionView
    private let infoStack = UIStackView()
    private var thumbnailChallenges: [KinvaChallenge] = []

    init(challenge: KinvaChallenge) {
        self.challenge = challenge
        let initialStyle = LocalDataStore.shared.visibleChallenges().firstIndex(where: { $0.id == challenge.id }) ?? 0
        self.frameView = ChallengeVideoFrameView(tokens: challenge.mediaTokens, style: initialStyle)
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 12
        layout.minimumInteritemSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        self.thumbnailCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        frameView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(frameView)
        let overlay = UIView(); overlay.translatesAutoresizingMaskIntoConstraints = false; overlay.isUserInteractionEnabled = false
        let gradient = CAGradientLayer(); gradient.colors = [UIColor.black.withAlphaComponent(0.18).cgColor, UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.5).cgColor]; gradient.locations = [0, 0.45, 1]; overlay.layer.addSublayer(gradient); view.addSubview(overlay)
        let back = detailButton("arrow.left"); back.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        let more = detailButton("line.3.horizontal"); more.addTarget(self, action: #selector(moreTapped), for: .touchUpInside)
        [back, more].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; view.addSubview($0) }
        authorAvatar.translatesAutoresizingMaskIntoConstraints = false
        authorAvatar.isUserInteractionEnabled = false
        authorButton.setTitleColor(.white, for: .normal)
        authorButton.titleLabel?.font = roundedFont(20, .heavy)
        authorButton.isUserInteractionEnabled = false
        authorButton.translatesAutoresizingMaskIntoConstraints = false
        let authorRow = UIStackView(arrangedSubviews: [authorAvatar, authorButton]); authorRow.axis = .horizontal; authorRow.spacing = 12; authorRow.alignment = .center; authorRow.translatesAutoresizingMaskIntoConstraints = false
        authorRow.isUserInteractionEnabled = true
        authorRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(authorTapped)))
        // The centered author row must be part of the same hierarchy before
        // activating constraints that reference the root view.
        view.addSubview(authorRow)
        configureLabel(titleLabel, size: 34, weight: .heavy, lines: 2)
        configureLabel(participantsLabel, size: 16, weight: .bold)
        configureLabel(detailLabel, size: 17, weight: .semibold, lines: 3)
        let joinedRow = UIStackView(arrangedSubviews: [joinedAvatarsView, participantsLabel]); joinedRow.axis = .horizontal; joinedRow.spacing = 14; joinedRow.alignment = .center
        infoStack.axis = .vertical; infoStack.spacing = 12; infoStack.translatesAutoresizingMaskIntoConstraints = false
        [titleLabel, joinedRow, detailLabel].forEach(infoStack.addArrangedSubview)
        view.addSubview(infoStack)
        likePill.addTarget(self, action: #selector(likeTapped), for: .touchUpInside)
        likePill.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(likePill)
        joinButton.setTitleColor(.white, for: .normal); joinButton.titleLabel?.font = roundedFont(20, .bold); joinButton.backgroundColor = AppTheme.blue; joinButton.layer.borderColor = UIColor.white.cgColor; joinButton.layer.borderWidth = 2; joinButton.round(28); joinButton.addTarget(self, action: #selector(joinTapped), for: .touchUpInside); joinButton.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(joinButton)
        thumbnailCollectionView.backgroundColor = .clear
        thumbnailCollectionView.showsHorizontalScrollIndicator = false
        thumbnailCollectionView.alwaysBounceHorizontal = true
        thumbnailCollectionView.isDirectionalLockEnabled = true
        thumbnailCollectionView.dataSource = self
        thumbnailCollectionView.delegate = self
        thumbnailCollectionView.register(ChallengeThumbnailCell.self, forCellWithReuseIdentifier: ChallengeThumbnailCell.reuseIdentifier)
        thumbnailCollectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(thumbnailCollectionView)
        NSLayoutConstraint.activate([
            frameView.topAnchor.constraint(equalTo: view.topAnchor), frameView.leadingAnchor.constraint(equalTo: view.leadingAnchor), frameView.trailingAnchor.constraint(equalTo: view.trailingAnchor), frameView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor), overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor), overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor), overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            back.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12), back.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), back.widthAnchor.constraint(equalToConstant: 42), back.heightAnchor.constraint(equalToConstant: 42),
            more.topAnchor.constraint(equalTo: back.topAnchor), more.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18), more.widthAnchor.constraint(equalToConstant: 42), more.heightAnchor.constraint(equalToConstant: 42),
            authorRow.centerXAnchor.constraint(equalTo: view.centerXAnchor), authorRow.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            infoStack.topAnchor.constraint(equalTo: authorRow.bottomAnchor, constant: 26), infoStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 21), infoStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            likePill.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 21), likePill.topAnchor.constraint(equalTo: infoStack.bottomAnchor, constant: 18),
            joinButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), joinButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20), joinButton.heightAnchor.constraint(equalToConstant: 55), joinButton.bottomAnchor.constraint(equalTo: thumbnailCollectionView.topAnchor, constant: -28),
            thumbnailCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor), thumbnailCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor), thumbnailCollectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -15), thumbnailCollectionView.heightAnchor.constraint(equalToConstant: 166)
        ])
        view.layoutIfNeeded(); gradient.frame = overlay.bounds
        refreshUI()
        rebuildThumbnails()
        NotificationCenter.default.addObserver(self, selector: #selector(storeChanged), name: LocalDataStore.didChangeNotification, object: nil)
    }

    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); (view.subviews.first { $0 !== frameView && $0.layer.sublayers?.first is CAGradientLayer })?.layer.sublayers?.first?.frame = view.bounds }
    private func refreshUI() {
        if let updated = store.visibleChallenges().first(where: { $0.id == challenge.id }) { challenge = updated }
        titleLabel.text = challenge.title
        let author = store.user(id: challenge.authorID)?.name ?? "Dancer"
        authorAvatar.setUser(id: challenge.authorID, name: author)
        authorButton.setTitle(author, for: .normal)
        let participantCount = challenge.participantIDs.count
        participantsLabel.text = participantCount == 1 ? "1 Person Joined" : "\(participantCount) People Joined"
        detailLabel.text = challenge.detail
        joinedAvatarsView.configure(participantIDs: challenge.participantIDs, store: store)
        joinedAvatarsView.isHidden = challenge.participantIDs.isEmpty
        likePill.configure(count: challenge.likedBy.count, isLiked: challenge.likedBy.contains(store.currentUserID))
        joinButton.setTitle(challenge.participantIDs.contains(store.currentUserID) ? "Joined  ✓" : "Join Challenge   →", for: .normal)
    }
    private func rebuildThumbnails() {
        let currentCategory = normalizedCategory(challenge.category)
        thumbnailChallenges = store.visibleChallenges().filter {
            normalizedCategory($0.category) == currentCategory
        }
        thumbnailCollectionView.reloadData()
    }
    private func selectChallenge(id: String) {
        guard let index = thumbnailChallenges.firstIndex(where: { $0.id == id }) else { return }
        challenge = thumbnailChallenges[index]
        frameView.setTokens(challenge.mediaTokens, style: index)
        refreshUI()
        rebuildThumbnails()
        guard let selectedIndex = thumbnailChallenges.firstIndex(where: { $0.id == challenge.id }) else { return }
        thumbnailCollectionView.scrollToItem(
            at: IndexPath(item: selectedIndex, section: 0),
            at: .centeredHorizontally,
            animated: true
        )
    }

    private func normalizedCategory(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        thumbnailChallenges.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ChallengeThumbnailCell.reuseIdentifier,
            for: indexPath
        ) as? ChallengeThumbnailCell else { return UICollectionViewCell() }
        let item = thumbnailChallenges[indexPath.item]
        cell.configure(challenge: item, style: indexPath.item, isCurrent: item.id == challenge.id)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard thumbnailChallenges.indices.contains(indexPath.item) else { return }
        selectChallenge(id: thumbnailChallenges[indexPath.item].id)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: 128, height: 166)
    }
    @objc private func storeChanged() { refreshUI(); rebuildThumbnails() }
    @objc private func joinTapped() { onAccess?(challenge) }
    @objc private func likeTapped() { try? store.toggleChallengeLike(id: challenge.id); refreshUI() }
    @objc private func authorTapped() { onAuthor?(challenge.authorID) }
    @objc private func moreTapped() { presentUserActions(targetID: challenge.authorID, targetType: "challenge") }
    @objc private func backTapped() { navigationController?.popViewController(animated: true) }
}

final class ChallengeAccessViewController: UIViewController {
    var onUnlocked: (() -> Void)?
    var onFinished: (() -> Void)?
    var onPlay: ((KinvaChallenge) -> Void)?
    var onAuthor: ((String) -> Void)?
    var onRecharge: (() -> Void)?
    var challenge: KinvaChallenge
    private let store = LocalDataStore.shared
    private let frameView: ChallengeVideoFrameView
    private let lockBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let unlockControl = UIControl()
    private let lockImageView = UIImageView(image: UIImage(named: "lock")?.withRenderingMode(.alwaysOriginal))
    private let unlockTextLabel = UILabel()
    private let unlockDiamondView = UIImageView(image: UIImage(named: "diamond")?.withRenderingMode(.alwaysOriginal))
    private let unlockPriceLabel = UILabel()
    private let joinButton = UIButton(type: .system)
    private let playButton = UIButton(type: .system)
    private let likeButton = UIButton(type: .system)
    private let followButton = UIButton(type: .system)
    private let authorControl = UIControl()
    init(challenge: KinvaChallenge) { self.challenge = challenge; frameView = ChallengeVideoFrameView(tokens: challenge.mediaTokens, style: 1); super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .black
        frameView.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(frameView)
        frameView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(playTapped)))
        lockBlur.alpha = 0.58; lockBlur.isUserInteractionEnabled = false; lockBlur.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(lockBlur)
        playButton.setImage(.symbol("play.fill", size: 30, weight: .bold), for: .normal)
        playButton.tintColor = .black
        playButton.backgroundColor = UIColor.white.withAlphaComponent(0.92)
        playButton.round(36)
        playButton.accessibilityLabel = "Play challenge video"
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        playButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playButton)
        let back = detailButton("arrow.left"); back.addTarget(self, action: #selector(backTapped), for: .touchUpInside); back.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(back)
        let more = detailButton("line.3.horizontal"); more.addTarget(self, action: #selector(moreTapped), for: .touchUpInside); more.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(more)
        configureUnlockControl(); view.addSubview(unlockControl)
        let bottom = UIView(); bottom.backgroundColor = .white; bottom.round(26); bottom.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(bottom)
        let author = store.user(id: challenge.authorID)?.name ?? "Dancer"
        authorControl.accessibilityLabel = "View \(author)'s profile"
        authorControl.addTarget(self, action: #selector(authorTapped), for: .touchUpInside)
        authorControl.translatesAutoresizingMaskIntoConstraints = false
        bottom.addSubview(authorControl)
        let avatar = AvatarView(name: author, size: 42, userID: challenge.authorID); avatar.isUserInteractionEnabled = false; avatar.translatesAutoresizingMaskIntoConstraints = false; authorControl.addSubview(avatar)
        let name = UILabel(); name.text = author; name.font = roundedFont(20, .heavy); name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal); name.isUserInteractionEnabled = false; name.translatesAutoresizingMaskIntoConstraints = false; authorControl.addSubview(name)
        followButton.tintColor = .white; followButton.backgroundColor = AppTheme.pink; followButton.round(11); followButton.addTarget(self, action: #selector(followTapped), for: .touchUpInside); followButton.translatesAutoresizingMaskIntoConstraints = false; bottom.addSubview(followButton)
        likeButton.tintColor = .white; likeButton.setTitleColor(.white, for: .normal); likeButton.titleLabel?.font = roundedFont(15, .bold); likeButton.round(18); likeButton.addTarget(self, action: #selector(likeTapped), for: .touchUpInside); likeButton.translatesAutoresizingMaskIntoConstraints = false; bottom.addSubview(likeButton)
        joinButton.setTitleColor(.white, for: .normal); joinButton.backgroundColor = AppTheme.blue; joinButton.titleLabel?.font = roundedFont(18, .bold); joinButton.round(25); joinButton.addTarget(self, action: #selector(joinTapped), for: .touchUpInside); joinButton.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(joinButton)
        NSLayoutConstraint.activate([
            frameView.topAnchor.constraint(equalTo: view.topAnchor), frameView.leadingAnchor.constraint(equalTo: view.leadingAnchor), frameView.trailingAnchor.constraint(equalTo: view.trailingAnchor), frameView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            lockBlur.topAnchor.constraint(equalTo: frameView.topAnchor), lockBlur.leadingAnchor.constraint(equalTo: frameView.leadingAnchor), lockBlur.trailingAnchor.constraint(equalTo: frameView.trailingAnchor), lockBlur.bottomAnchor.constraint(equalTo: frameView.bottomAnchor),
            playButton.centerXAnchor.constraint(equalTo: view.centerXAnchor), playButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -35), playButton.widthAnchor.constraint(equalToConstant: 72), playButton.heightAnchor.constraint(equalToConstant: 72),
            back.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12), back.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), back.widthAnchor.constraint(equalToConstant: 42), back.heightAnchor.constraint(equalToConstant: 42),
            more.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12), more.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18), more.widthAnchor.constraint(equalToConstant: 42), more.heightAnchor.constraint(equalToConstant: 42),
            unlockControl.centerXAnchor.constraint(equalTo: view.centerXAnchor), unlockControl.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -75),
            bottom.leadingAnchor.constraint(equalTo: view.leadingAnchor), bottom.trailingAnchor.constraint(equalTo: view.trailingAnchor), bottom.bottomAnchor.constraint(equalTo: view.bottomAnchor), bottom.heightAnchor.constraint(equalToConstant: 100),
            authorControl.leadingAnchor.constraint(equalTo: bottom.leadingAnchor, constant: 12), authorControl.centerYAnchor.constraint(equalTo: bottom.centerYAnchor), authorControl.heightAnchor.constraint(equalToConstant: 64),
            avatar.leadingAnchor.constraint(equalTo: authorControl.leadingAnchor, constant: 6), avatar.centerYAnchor.constraint(equalTo: authorControl.centerYAnchor), name.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 10), name.centerYAnchor.constraint(equalTo: avatar.centerYAnchor), name.trailingAnchor.constraint(equalTo: authorControl.trailingAnchor), followButton.leadingAnchor.constraint(equalTo: authorControl.trailingAnchor, constant: 6),
            followButton.centerYAnchor.constraint(equalTo: avatar.centerYAnchor), followButton.widthAnchor.constraint(equalToConstant: 22), followButton.heightAnchor.constraint(equalToConstant: 22), followButton.trailingAnchor.constraint(lessThanOrEqualTo: likeButton.leadingAnchor, constant: -12),
            likeButton.trailingAnchor.constraint(equalTo: bottom.trailingAnchor, constant: -17), likeButton.centerYAnchor.constraint(equalTo: bottom.centerYAnchor), likeButton.widthAnchor.constraint(equalToConstant: 84), likeButton.heightAnchor.constraint(equalToConstant: 36),
            joinButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 47), joinButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -47), joinButton.bottomAnchor.constraint(equalTo: bottom.topAnchor, constant: -27), joinButton.heightAnchor.constraint(equalToConstant: 52)
        ])
        refreshUI()
    }

    private func configureUnlockControl() {
        lockImageView.contentMode = .scaleAspectFit
        unlockDiamondView.contentMode = .scaleAspectFit
        unlockTextLabel.text = "Unlock with"
        unlockTextLabel.textColor = .white
        unlockTextLabel.font = roundedFont(17, .bold)
        unlockPriceLabel.textColor = .white
        unlockPriceLabel.font = roundedFont(17, .bold)
        let priceRow = UIStackView(arrangedSubviews: [unlockTextLabel, unlockDiamondView, unlockPriceLabel])
        priceRow.axis = .horizontal
        priceRow.alignment = .center
        priceRow.spacing = 6
        let stack = UIStackView(arrangedSubviews: [lockImageView, priceRow])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        unlockControl.translatesAutoresizingMaskIntoConstraints = false
        unlockControl.addSubview(stack)
        unlockControl.addTarget(self, action: #selector(unlockTapped), for: .touchUpInside)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: unlockControl.topAnchor), stack.leadingAnchor.constraint(equalTo: unlockControl.leadingAnchor), stack.trailingAnchor.constraint(equalTo: unlockControl.trailingAnchor), stack.bottomAnchor.constraint(equalTo: unlockControl.bottomAnchor),
            lockImageView.widthAnchor.constraint(equalToConstant: 54), lockImageView.heightAnchor.constraint(equalToConstant: 54),
            unlockDiamondView.widthAnchor.constraint(equalToConstant: 19), unlockDiamondView.heightAnchor.constraint(equalToConstant: 19)
        ])
    }

    private var isUnlocked: Bool {
        challenge.authorID == store.currentUserID ||
        store.account.unlockedChallengeIDs.contains(challenge.id) ||
        challenge.diamondPrice == 0
    }
    private func refreshUI() {
        if let value = store.visibleChallenges().first(where: { $0.id == challenge.id }) { challenge = value }
        let joined = challenge.participantIDs.contains(store.currentUserID)
        let liked = challenge.likedBy.contains(store.currentUserID)
        let following = store.account.user.followingIDs.contains(challenge.authorID)
        lockBlur.isHidden = isUnlocked
        unlockControl.isHidden = isUnlocked
        playButton.isHidden = !isUnlocked
        unlockPriceLabel.text = "×\(challenge.diamondPrice)"
        joinButton.isHidden = !isUnlocked
        joinButton.setTitle(joined ? "Joined" : "Join Challenge", for: .normal)
        likeButton.setImage(.symbol(liked ? "heart.fill" : "heart", size: 15, weight: .bold), for: .normal)
        likeButton.setTitle("  \(challenge.likedBy.count)", for: .normal)
        likeButton.backgroundColor = liked ? AppTheme.pink : UIColor(hex: 0xC8CFE6)
        likeButton.accessibilityLabel = liked ? "Unlike challenge" : "Like challenge"
        followButton.isHidden = challenge.authorID == store.currentUserID
        followButton.setImage(.symbol(following ? "minus" : "plus", size: 11, weight: .bold), for: .normal)
        followButton.backgroundColor = following ? UIColor(hex: 0xA9ADB5) : AppTheme.pink
        followButton.accessibilityLabel = following ? "Unfollow" : "Follow"
    }
    @objc private func playTapped() { guard isUnlocked else { return }; onPlay?(challenge) }
    @objc private func unlockTapped() {
        guard !isUnlocked else { refreshUI(); return }
        guard store.account.diamondBalance >= challenge.diamondPrice else {
            showInsufficientDiamonds()
            return
        }
        showConfirmation(title: "Unlock Challenge",
                         message: "Are you sure you want to spend \(challenge.diamondPrice) Diamonds to unlock this challenge?",
                         confirm: "Sure") { [weak self] in
            guard let self else { return }
            do {
                try self.store.unlockChallenge(id: self.challenge.id)
                self.refreshUI()
                self.onUnlocked?()
            } catch LocalStoreError.insufficientDiamonds {
                self.showInsufficientDiamonds()
            } catch {
                self.showKinvaNotice(title: "Could not unlock",
                                     message: error.localizedDescription)
            }
        }
    }
    private func showInsufficientDiamonds() {
        showConfirmation(title: "Not Enough Diamond",
                         message: "You don’t have enough Diamonds to continue. Would you like to recharge now?",
                         confirm: "Confirm") { [weak self] in
            self?.onRecharge?()
        }
    }
    @objc private func joinTapped() {
        guard isUnlocked else { unlockTapped(); return }
        do {
            if !challenge.participantIDs.contains(store.currentUserID) {
                try store.joinChallenge(id: challenge.id)
            }
            refreshUI()
            onFinished?()
        } catch {
            showKinvaNotice(title: "Could not join", message: error.localizedDescription)
        }
    }
    @objc private func likeTapped() { try? store.toggleChallengeLike(id: challenge.id); refreshUI() }
    @objc private func followTapped() { _ = try? store.toggleFollow(userID: challenge.authorID); refreshUI() }
    @objc private func authorTapped() { onAuthor?(challenge.authorID) }
    @objc private func moreTapped() { presentUserActions(targetID: challenge.authorID, targetType: "challenge") }
    @objc private func backTapped() { navigationController?.popViewController(animated: true) }
}

final class ChallengePlaybackViewController: AVPlayerViewController {
    private let challenge: KinvaChallenge
    init(challenge: KinvaChallenge) { self.challenge = challenge; super.init(nibName: nil, bundle: nil); if let path = challenge.mediaTokens.lazy.compactMap({ kinvaMediaFilePath(token: $0) }).first { player = AVPlayer(url: URL(fileURLWithPath: path)) } }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); player?.play() }
}

final class ChallengeJoinedAvatarsView: UIView {
    private let avatarSize: CGFloat = 34
    private let overlap: CGFloat = 11
    private var avatarViews: [UIView] = []

    func configure(participantIDs: Set<String>, store: LocalDataStore) {
        avatarViews.forEach { $0.removeFromSuperview() }
        avatarViews.removeAll()
        let ids = participantIDs.sorted().prefix(5)
        for id in ids {
            let name = store.user(id: id)?.name ?? "K"
            let avatar = AvatarView(name: name, size: avatarSize, userID: id)
            avatar.layer.borderColor = UIColor.white.cgColor
            avatar.layer.borderWidth = 2
            avatar.translatesAutoresizingMaskIntoConstraints = false
            addSubview(avatar)
            avatarViews.append(avatar)
        }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override var intrinsicContentSize: CGSize {
        guard !avatarViews.isEmpty else { return .zero }
        let width = avatarSize + CGFloat(max(0, avatarViews.count - 1)) * (avatarSize - overlap)
        return CGSize(width: width, height: avatarSize)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !avatarViews.isEmpty else { return }
        var x: CGFloat = 0
        for avatar in avatarViews {
            avatar.frame = CGRect(x: x, y: 0, width: avatarSize, height: avatarSize)
            x += avatarSize - overlap
        }
    }
}

final class ChallengeLikePillView: UIControl {
    private let iconView = UIImageView()
    private let countLabel = UILabel()
    private let stack = UIStackView()
    private var count = 0
    private var liked = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .white
        iconView.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = roundedFont(17, .heavy)
        countLabel.textColor = .white
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(countLabel)

        backgroundColor = UIColor.white.withAlphaComponent(0.42)
        round(18)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 38).isActive = true
        widthAnchor.constraint(equalToConstant: 92).isActive = true

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(count: Int, isLiked: Bool) {
        self.count = count
        liked = isLiked
        countLabel.text = "\(count)"
        iconView.image = .symbol(isLiked ? "heart.fill" : "heart", size: 16, weight: .bold)
        backgroundColor = isLiked ? AppTheme.pink : UIColor.white.withAlphaComponent(0.42)
        setNeedsLayout()
    }
}

final class ChallengeVideoFrameView: UIView {
    private let imageView = UIImageView()
    private var tokens: [String]
    private var loadVersion = 0
    init(tokens: [String], style _: Int) { self.tokens = tokens; super.init(frame: .zero); clipsToBounds = true; backgroundColor = .black; imageView.image = ChallengeVideoThumbnailProvider.cachedImage(tokens: tokens); imageView.translatesAutoresizingMaskIntoConstraints = false; imageView.contentMode = .scaleAspectFill; imageView.clipsToBounds = true; addSubview(imageView); NSLayoutConstraint.activate([imageView.topAnchor.constraint(equalTo: topAnchor), imageView.leadingAnchor.constraint(equalTo: leadingAnchor), imageView.trailingAnchor.constraint(equalTo: trailingAnchor), imageView.bottomAnchor.constraint(equalTo: bottomAnchor)]); if imageView.image == nil { load() } }
    required init?(coder: NSCoder) { fatalError() }
    func setTokens(_ values: [String], style _: Int) {
        if tokens == values, imageView.image != nil { return }
        tokens = values
        if let cached = ChallengeVideoThumbnailProvider.cachedImage(tokens: values) {
            loadVersion += 1
            imageView.image = cached
            return
        }
        load()
    }
    private func load() {
        loadVersion += 1
        let expectedVersion = loadVersion
        imageView.image = nil
        ChallengeVideoThumbnailProvider.load(tokens: tokens) { [weak self] image in
            guard let self, self.loadVersion == expectedVersion else { return }
            self.imageView.image = image
        }
    }
}

final class ChallengeThumbnailCell: UICollectionViewCell {
    static let reuseIdentifier = "ChallengeThumbnailCell"

    private var frameView: ChallengeVideoFrameView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        clipsToBounds = true
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        frameView?.removeFromSuperview()
        frameView = nil
        layer.borderWidth = 0
        accessibilityLabel = nil
    }

    func configure(challenge: KinvaChallenge, style: Int, isCurrent: Bool) {
        frameView?.removeFromSuperview()
        let preview = ChallengeVideoFrameView(tokens: challenge.mediaTokens, style: style)
        preview.isUserInteractionEnabled = false
        preview.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(preview)
        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: contentView.topAnchor),
            preview.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            preview.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        frameView = preview
        layer.borderColor = (isCurrent ? UIColor.white : UIColor.clear).cgColor
        layer.borderWidth = isCurrent ? 3 : 0
        accessibilityLabel = "Show \(challenge.title)"
        accessibilityTraits = isCurrent ? [.button, .selected] : .button
    }
}

final class InspirationSelectionViewController: BaseScrollViewController {
    var onGenerated: ((InspirationResult) -> Void)?
    var onRecharge: (() -> Void)?
    private let groups: [(String, [String])] = [("Core Direction", ["Dance Flow", "Freestyle Movement", "Stretch Performance"]), ("Movement Texture", ["Liquid & Flowy", "Sharp & Robotic", "Heavy & Grounded", "Ethereal & Airy", "Dramatic & Emotional"]), ("Body Focus", ["Floor Work", "Upper Body", "Spine Wave", "Wall-Assisted Flow", "Balance & Lines"])]
    private var selected = Set<String>()

    override func viewDidLoad() {
        super.viewDidLoad(); contentStack.spacing = 0; scrollView.contentInsetAdjustmentBehavior = .never
        let hero = AIHeroView(); hero.backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside); hero.heightAnchor.constraint(equalToConstant: 240).isActive = true
        contentStack.addArrangedSubview(hero)
        let sheet = UIView(); sheet.backgroundColor = .white; sheet.layer.cornerRadius = 25; sheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 17; stack.translatesAutoresizingMaskIntoConstraints = false; sheet.addSubview(stack)
        for (groupIndex, group) in groups.enumerated() {
            let label = UILabel(); label.text = group.0; label.font = roundedFont(24, .heavy); stack.addArrangedSubview(label)
            let wrap = PillWrapView(); for (itemIndex, item) in group.1.enumerated() { let pill = PillButton(title: item); pill.tag = groupIndex * 100 + itemIndex; pill.addTarget(self, action: #selector(tagTapped(_:)), for: .touchUpInside); wrap.add(pill) }; stack.addArrangedSubview(wrap)
        }
        let cost = UIView(); cost.backgroundColor = AppTheme.blue; cost.layer.borderColor = UIColor(hex: 0x42D5FF).cgColor; cost.layer.borderWidth = 1.5; cost.round(9); cost.heightAnchor.constraint(equalToConstant: 34).isActive = true; cost.widthAnchor.constraint(equalToConstant: 86).isActive = true
        let costDiamond = UIImageView(image: UIImage(named: "diamond")?.withRenderingMode(.alwaysOriginal)); costDiamond.contentMode = .scaleAspectFit
        let costLabel = UILabel(); costLabel.text = "×300"; costLabel.textColor = .white; costLabel.font = roundedFont(15, .bold)
        let costStack = UIStackView(arrangedSubviews: [costDiamond, costLabel]); costStack.axis = .horizontal; costStack.alignment = .center; costStack.spacing = 4; costStack.isUserInteractionEnabled = false; costStack.translatesAutoresizingMaskIntoConstraints = false; cost.addSubview(costStack)
        NSLayoutConstraint.activate([costStack.centerXAnchor.constraint(equalTo: cost.centerXAnchor), costStack.centerYAnchor.constraint(equalTo: cost.centerYAnchor), costDiamond.widthAnchor.constraint(equalToConstant: 19), costDiamond.heightAnchor.constraint(equalToConstant: 19)])
        let button = BrandButton(title: "Generate"); button.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)
        let buttonWrap = UIView(); buttonWrap.heightAnchor.constraint(equalToConstant: 70).isActive = true; [button, cost].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; buttonWrap.addSubview($0) }
        NSLayoutConstraint.activate([button.leadingAnchor.constraint(equalTo: buttonWrap.leadingAnchor), button.trailingAnchor.constraint(equalTo: buttonWrap.trailingAnchor), button.bottomAnchor.constraint(equalTo: buttonWrap.bottomAnchor), button.heightAnchor.constraint(equalToConstant: 58), cost.trailingAnchor.constraint(equalTo: buttonWrap.trailingAnchor, constant: 2), cost.topAnchor.constraint(equalTo: buttonWrap.topAnchor)])
        stack.addArrangedSubview(buttonWrap)
        NSLayoutConstraint.activate([stack.topAnchor.constraint(equalTo: sheet.topAnchor, constant: 22), stack.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 25), stack.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -25), stack.bottomAnchor.constraint(equalTo: sheet.bottomAnchor, constant: -22)])
        contentStack.addArrangedSubview(sheet)
    }
    @objc private func tagTapped(_ sender: PillButton) { guard let text = sender.title(for: .normal) else { return }; if selected.contains(text) { selected.remove(text); sender.isPillSelected = false } else { selected.insert(text); sender.isPillSelected = true } }
    @objc private func generateTapped() {
        let core = Set(groups[0].1); guard !selected.isDisjoint(with: core) else { showLocalAlert(title: "Choose a direction", message: "Select at least one core direction."); return }
        guard LocalDataStore.shared.account.diamondBalance >= 300 else { showInsufficientDiamonds(); return }
        let tags = Array(selected)
        showConfirmation(title: "Generate Inspiration",
                         message: "Are you sure you want to spend 300 Diamonds to generate this content?",
                         confirm: "Confirm") { [weak self] in
            self?.generate(tags: tags)
        }
    }
    private func generate(tags: [String]) {
        do { onGenerated?(try LocalDataStore.shared.generateInspiration(tags: tags)) } catch LocalStoreError.insufficientDiamonds { showInsufficientDiamonds() } catch { showLocalAlert(title: "Could not generate", message: error.localizedDescription) }
    }
    private func showInsufficientDiamonds() {
        showConfirmation(title: "Not Enough Diamond",
                         message: "You don’t have enough Diamonds to continue. Would you like to recharge now?",
                         confirm: "Confirm") { [weak self] in
            self?.onRecharge?()
        }
    }
    @objc private func backTapped() { navigationController?.popViewController(animated: true) }
}

private final class AIHeroView: UIView {
    let backButton = detailButton("arrow.left")
    override init(frame: CGRect) {
        super.init(frame: frame)
        let background = UIImageView(image: UIImage(named: "ai_bg")); background.contentMode = .scaleAspectFill; background.clipsToBounds = true; background.translatesAutoresizingMaskIntoConstraints = false; addSubview(background)
        let title = UILabel(); title.text = "KINVA AI"; title.font = roundedFont(32, .heavy); title.textColor = UIColor(hex: 0x005AFF)
        let sub = UILabel(); sub.text = "Get personalized tips for\nyour movement step-by-step"; sub.numberOfLines = 2; sub.font = roundedFont(18, .bold); sub.textColor = UIColor(hex: 0x008DFF)
        let textStack = UIStackView(arrangedSubviews: [title, sub]); textStack.axis = .vertical; textStack.spacing = 1; textStack.translatesAutoresizingMaskIntoConstraints = false; addSubview(textStack)
        backButton.translatesAutoresizingMaskIntoConstraints = false; addSubview(backButton)
        NSLayoutConstraint.activate([
            background.topAnchor.constraint(equalTo: topAnchor), background.leadingAnchor.constraint(equalTo: leadingAnchor), background.trailingAnchor.constraint(equalTo: trailingAnchor), background.bottomAnchor.constraint(equalTo: bottomAnchor),
            backButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20), backButton.topAnchor.constraint(equalTo: topAnchor, constant: 55), backButton.widthAnchor.constraint(equalToConstant: 40), backButton.heightAnchor.constraint(equalToConstant: 40),
            textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 25), textStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20), textStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -38)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

final class PillWrapView: UIView {
    private var buttons: [UIButton] = []
    func add(_ button: UIButton) { buttons.append(button); addSubview(button) }
    override func layoutSubviews() {
        super.layoutSubviews(); var x: CGFloat = 0; var y: CGFloat = 0; let gap: CGFloat = 9
        for button in buttons { let size = button.sizeThatFits(CGSize(width: bounds.width, height: 34)); let width = min(size.width, bounds.width); if x + width > bounds.width { x = 0; y += 43 }; button.frame = CGRect(x: x, y: y, width: width, height: 34); x += width + gap }
        invalidateIntrinsicContentSize()
    }
    override var intrinsicContentSize: CGSize { let bottom = buttons.map(\.frame.maxY).max() ?? 34; return CGSize(width: UIView.noIntrinsicMetric, height: max(34, bottom)) }
}

final class InspirationResultViewController: BaseScrollViewController {
    let result: InspirationResult
    var onSaved: (() -> Void)?
    init(result: InspirationResult) { self.result = result; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad(); contentStack.spacing = 0; scrollView.contentInsetAdjustmentBehavior = .never
        let hero = AIHeroView(); hero.backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside); hero.heightAnchor.constraint(equalToConstant: 240).isActive = true
        contentStack.addArrangedSubview(hero)
        let sheet = UIView(); sheet.backgroundColor = .white; sheet.layer.cornerRadius = 25; sheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        let theme = resultLabel(title: "Recommended Theme:", body: "「\(result.title)」")
        let breakdown = resultLabel(title: "Transition Breakdown:", body: result.breakdown)
        let tips = resultLabel(title: "Shooting & BGM Tips:", body: result.shootingTip)
        let save = BrandButton(title: "Save"); save.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        let textStack = UIStackView(arrangedSubviews: [theme, breakdown, tips]); textStack.axis = .vertical; textStack.spacing = 22
        let spacer = UIView(); spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        let stack = UIStackView(arrangedSubviews: [textStack, spacer, save]); stack.axis = .vertical; stack.spacing = 20; stack.translatesAutoresizingMaskIntoConstraints = false; sheet.addSubview(stack)
        contentStack.addArrangedSubview(sheet)
        NSLayoutConstraint.activate([sheet.heightAnchor.constraint(greaterThanOrEqualTo: view.heightAnchor, constant: -240), stack.topAnchor.constraint(equalTo: sheet.topAnchor, constant: 23), stack.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 25), stack.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -25), stack.bottomAnchor.constraint(equalTo: sheet.bottomAnchor, constant: -22), save.heightAnchor.constraint(equalToConstant: 58)])
    }
    private func resultLabel(title: String, body: String) -> UILabel {
        let label = UILabel(); label.numberOfLines = 0; label.textColor = AppTheme.text
        let text = NSMutableAttributedString(string: title + "\n", attributes: [.font: roundedFont(16, .heavy)])
        text.append(NSAttributedString(string: body, attributes: [.font: roundedFont(16, .bold)]))
        let style = NSMutableParagraphStyle(); style.lineSpacing = 1; text.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: text.length)); label.attributedText = text
        return label
    }
    @objc private func saveTapped() { do { try LocalDataStore.shared.saveInspiration(result); onSaved?() } catch { showLocalAlert(title: "Could not save", message: error.localizedDescription) } }
    @objc private func backTapped() { navigationController?.popViewController(animated: true) }
}
