import UIKit
import AVFoundation

final class ChatViewController: UIViewController {
    enum InputMode { case text, voice }

    var onBack: (() -> Void)?
    var onMenu: ((UIView) -> Void)?
    var onAuthor: ((String) -> Void)?
    var onSendText: ((String) -> Void)?
    var onVoiceModeChanged: ((InputMode) -> Void)?
    var onVoicePressBegan: (() -> Void)?
    var onVoicePressEnded: ((Bool) -> Void)?
    var onPlayVoice: ((ChatMessageViewModel) -> Bool)?
    var onVideoCall: (() -> Void)?
    var onRetry: (() -> Void)?

    private let header = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let headerAvatar = AvatarView(name: "?", size: 58)
    private let authorControl = UIControl()
    private let menuButton = UIButton(type: .system)
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let messagesStack = UIStackView()
    private let emptyLabel = UILabel()
    private let inputContainer = UIView()
    private let relationLabel = UILabel()
    private let inputRow = UIStackView()
    private let modeButton = UIButton(type: .system)
    private let textField = UITextField()
    private let sendButton = UIButton(type: .system)
    private let holdButton = UIButton(type: .system)
    private let videoCallButton = UIButton(type: .system)
    private let stateView = ChatStateView()
    private var didReceiveDisplay = false
    private var participant: MessageParticipantViewModel?
    private var timestamp: String?
    private var messages: [ChatMessageViewModel] = []
    private var bubbleViews: [String: ChatBubbleView] = [:]
    private var playingVoiceMessageID: String?
    private var mode: InputMode = .text
    private var canSend = true

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        LocalVoicePlayer.shared.onPlaybackStateChanged = { [weak self] token, isPlaying in
            self?.syncVoicePlayback(token: token, isPlaying: isPlaying)
        }
        if didReceiveDisplay {
            applyCurrentState()
        } else {
            displayLoading()
        }
    }

    func display(participant: MessageParticipantViewModel,
                 timestamp: String?,
                 messages: [ChatMessageViewModel],
                 canSend: Bool,
                 inputMode: InputMode = .text) {
        didReceiveDisplay = true
        self.participant = participant
        self.timestamp = timestamp
        self.messages = messages
        self.canSend = canSend
        mode = inputMode
        guard isViewLoaded else { return }
        applyCurrentState()
    }

    private func applyCurrentState() {
        titleLabel.text = participant?.name
        headerAvatar.setUser(id: participant?.id, name: participant?.name ?? "?")
        authorControl.accessibilityLabel = participant.map { "View \($0.name)'s profile" }
        subtitleLabel.text = timestamp
        rebuildMessages()
        updateInputMode()
        relationLabel.isHidden = canSend
        relationLabel.text = canSend ? nil : "Follow each other to unlock messages."
        inputRow.isUserInteractionEnabled = canSend
        inputRow.alpha = canSend ? 1 : 0.45
        videoCallButton.isEnabled = canSend
        videoCallButton.alpha = canSend ? 1 : 0.45
        emptyLabel.isHidden = !messages.isEmpty
        stateView.isHidden = true
        scrollView.isHidden = false
        inputContainer.isHidden = false
        DispatchQueue.main.async { [weak self] in self?.scrollToBottom(animated: false) }
    }

    func displayLoading() {
        scrollView.isHidden = true
        inputContainer.isHidden = true
        stateView.showLoading()
    }

    func displayEmpty(participant: MessageParticipantViewModel, canSend: Bool) {
        display(participant: participant, timestamp: nil, messages: [], canSend: canSend)
    }

    func displayParseError(_ message: String = "This conversation could not be read.") {
        scrollView.isHidden = true
        inputContainer.isHidden = true
        stateView.show(message: message, retry: onRetry)
    }

    func setSending(_ sending: Bool) {
        sendButton.isEnabled = !sending && canSend
        holdButton.isEnabled = !sending && canSend
        inputRow.alpha = sending ? 0.55 : (canSend ? 1 : 0.45)
    }

    func updateVoiceProgress(messageID: String, progress: Float) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        guard case .voice(let duration, _) = messages[index].kind else { return }
        messages[index].kind = .voice(duration: duration, progress: CGFloat(max(0, min(1, progress))))
        rebuildMessages()
    }

    private func buildLayout() {
        view.backgroundColor = AppTheme.background
        navigationController?.setNavigationBarHidden(true, animated: false)
        header.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        messagesStack.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        stateView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(messagesStack)
        view.addSubview(inputContainer)
        view.addSubview(stateView)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 168),
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: inputContainer.topAnchor, constant: -8),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            messagesStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            messagesStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            messagesStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            messagesStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
            inputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            inputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            inputContainer.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -14),
            stateView.topAnchor.constraint(equalTo: header.bottomAnchor),
            stateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stateView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        messagesStack.axis = .vertical
        messagesStack.spacing = 20

        buildHeader()
        buildInput()
    }

    private func buildHeader() {
        let backButton = UIButton(type: .system)
        backButton.setImage(.symbol("arrow.left", size: 19, weight: .bold), for: .normal)
        menuButton.setImage(.symbol("line.3.horizontal", size: 18, weight: .bold), for: .normal)
        [backButton, menuButton].forEach {
            $0.tintColor = .white
            $0.backgroundColor = .black
            $0.round(11)
        }
        titleLabel.font = AppTheme.font(19, .bold)
        titleLabel.textColor = AppTheme.text
        titleLabel.textAlignment = .center
        subtitleLabel.font = AppTheme.font(14, .semibold)
        subtitleLabel.textColor = AppTheme.mutedText
        subtitleLabel.textAlignment = .center
        [backButton, headerAvatar, titleLabel, subtitleLabel, menuButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            header.addSubview($0)
        }
        authorControl.accessibilityLabel = "View profile"
        authorControl.addTarget(self, action: #selector(authorTapped), for: .touchUpInside)
        authorControl.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(authorControl)
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            backButton.topAnchor.constraint(equalTo: header.topAnchor, constant: 9),
            backButton.widthAnchor.constraint(equalToConstant: 42),
            backButton.heightAnchor.constraint(equalToConstant: 42),
            menuButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -17),
            menuButton.topAnchor.constraint(equalTo: backButton.topAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 42),
            menuButton.heightAnchor.constraint(equalToConstant: 42),
            headerAvatar.topAnchor.constraint(equalTo: header.topAnchor, constant: 0),
            headerAvatar.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: headerAvatar.bottomAnchor, constant: 10),
            titleLabel.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 9),
            subtitleLabel.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            authorControl.topAnchor.constraint(equalTo: header.topAnchor),
            authorControl.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            authorControl.widthAnchor.constraint(equalToConstant: 170),
            authorControl.heightAnchor.constraint(equalToConstant: 100)
        ])
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        menuButton.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)
    }

    private func buildInput() {
        relationLabel.font = AppTheme.font(12, .semibold)
        relationLabel.textColor = AppTheme.secondaryText
        relationLabel.textAlignment = .center
        relationLabel.numberOfLines = 0
        relationLabel.backgroundColor = AppTheme.paleBlue
        relationLabel.round(10)
        relationLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 38).isActive = true

        inputRow.axis = .horizontal
        inputRow.alignment = .center
        inputRow.spacing = 10
        inputRow.backgroundColor = .white
        inputRow.layer.borderColor = AppTheme.text.cgColor
        inputRow.layer.borderWidth = 2
        inputRow.layer.cornerRadius = 17
        inputRow.layer.cornerCurve = .continuous
        inputRow.isLayoutMarginsRelativeArrangement = true
        inputRow.layoutMargins = UIEdgeInsets(top: 5, left: 18, bottom: 5, right: 14)
        inputRow.heightAnchor.constraint(equalToConstant: 62).isActive = true
        modeButton.tintColor = AppTheme.text
        modeButton.widthAnchor.constraint(equalToConstant: 22).isActive = true
        textField.placeholder = "Say something…"
        textField.font = AppTheme.font(13, .semibold)
        textField.returnKeyType = .send
        textField.delegate = self
        sendButton.setImage(.symbol("paperplane.fill", size: 21, weight: .bold), for: .normal)
        sendButton.tintColor = AppTheme.text
        sendButton.widthAnchor.constraint(equalToConstant: 36).isActive = true
        holdButton.setTitle("Hold to Talk", for: .normal)
        holdButton.setTitleColor(.white, for: .normal)
        holdButton.titleLabel?.font = AppTheme.font(20, .bold)
        holdButton.backgroundColor = AppTheme.blue
        holdButton.round(15)
        holdButton.heightAnchor.constraint(equalToConstant: 62).isActive = true

        videoCallButton.setImage(UIImage(named: "video_call")?.withRenderingMode(.alwaysOriginal), for: .normal)
        videoCallButton.backgroundColor = .clear
        videoCallButton.imageView?.contentMode = .scaleAspectFit
        videoCallButton.accessibilityLabel = "Video call"
        videoCallButton.widthAnchor.constraint(equalToConstant: 62).isActive = true
        videoCallButton.heightAnchor.constraint(equalToConstant: 62).isActive = true

        let inputControlsRow = UIStackView(arrangedSubviews: [inputRow, videoCallButton])
        inputControlsRow.axis = .horizontal
        inputControlsRow.alignment = .center
        inputControlsRow.spacing = 10

        let inputStack = UIStackView(arrangedSubviews: [relationLabel, inputControlsRow])
        inputStack.axis = .vertical
        inputStack.spacing = 8
        inputStack.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.addSubview(inputStack)
        NSLayoutConstraint.activate([
            inputStack.topAnchor.constraint(equalTo: inputContainer.topAnchor),
            inputStack.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor),
            inputStack.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor),
            inputStack.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor)
        ])
        modeButton.addTarget(self, action: #selector(modeTapped), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        videoCallButton.addTarget(self, action: #selector(videoCallTapped), for: .touchUpInside)
        holdButton.addTarget(self, action: #selector(voiceBegan), for: .touchDown)
        holdButton.addTarget(self, action: #selector(voiceEnded), for: [.touchUpInside, .touchUpOutside])
        holdButton.addTarget(self, action: #selector(voiceCancelled), for: .touchCancel)
    }

    private func rebuildMessages() {
        messagesStack.arrangedSubviews.forEach { view in
            messagesStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        bubbleViews.removeAll()
        emptyLabel.text = "No messages yet. Say hello."
        emptyLabel.font = AppTheme.font(14)
        emptyLabel.textColor = AppTheme.mutedText
        emptyLabel.textAlignment = .center
        emptyLabel.heightAnchor.constraint(equalToConstant: 140).isActive = true
        messagesStack.addArrangedSubview(emptyLabel)
        for message in messages {
            let bubble = ChatBubbleView(message: message, isPlaying: playingVoiceMessageID == message.id)
            bubble.onVoice = { [weak self] in self?.voiceTapped(message) }
            bubbleViews[message.id] = bubble
            messagesStack.addArrangedSubview(bubble)
        }
    }

    private func updateInputMode() {
        inputRow.arrangedSubviews.forEach { view in
            inputRow.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        switch mode {
        case .text:
            modeButton.setImage(.symbol("mic.fill", size: 19, weight: .bold), for: .normal)
            modeButton.tintColor = AppTheme.text
            inputRow.backgroundColor = .white
            inputRow.layer.borderColor = AppTheme.text.cgColor
            inputRow.layoutMargins = UIEdgeInsets(top: 5, left: 18, bottom: 5, right: 14)
            inputRow.addArrangedSubview(modeButton)
            inputRow.addArrangedSubview(textField)
            inputRow.addArrangedSubview(sendButton)
        case .voice:
            modeButton.setImage(.symbol("keyboard", size: 19, weight: .bold), for: .normal)
            modeButton.tintColor = .white
            inputRow.backgroundColor = AppTheme.blue
            inputRow.layer.borderColor = AppTheme.blue.cgColor
            inputRow.layoutMargins = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18)
            inputRow.addArrangedSubview(modeButton)
            inputRow.addArrangedSubview(holdButton)
        }
    }

    private func scrollToBottom(animated: Bool) {
        let bottom = CGPoint(x: 0, y: max(0, scrollView.contentSize.height - scrollView.bounds.height))
        scrollView.setContentOffset(bottom, animated: animated)
    }

    @objc private func backTapped() { onBack?() }
    @objc private func menuTapped() { onMenu?(menuButton) }
    @objc private func authorTapped() {
        guard let participant else { return }
        onAuthor?(participant.id)
    }
    @objc private func modeTapped() {
        mode = mode == .text ? .voice : .text
        textField.resignFirstResponder()
        updateInputMode()
        onVoiceModeChanged?(mode)
    }
    @objc private func sendTapped() {
        guard let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty, canSend else { return }
        onSendText?(text)
        textField.text = nil
    }
    @objc private func videoCallTapped() {
        guard canSend else { return }
        textField.resignFirstResponder()
        onVideoCall?()
    }
    @objc private func voiceBegan() { guard canSend else { return }; onVoicePressBegan?() }
    @objc private func voiceEnded() { guard canSend else { return }; onVoicePressEnded?(false) }
    @objc private func voiceCancelled() { guard canSend else { return }; onVoicePressEnded?(true) }

    private func voiceTapped(_ message: ChatMessageViewModel) {
        let isPlaying = onPlayVoice?(message) ?? false
        playingVoiceMessageID = isPlaying ? message.id : nil
        syncVoiceBubbleStates()
    }

    private func syncVoicePlayback(token: String?, isPlaying: Bool) {
        let currentID = messages.first(where: { $0.voiceToken == token })?.id
        playingVoiceMessageID = isPlaying ? currentID : nil
        syncVoiceBubbleStates()
    }

    private func syncVoiceBubbleStates() {
        for message in messages {
            guard case .voice = message.kind, let bubble = bubbleViews[message.id] else { continue }
            bubble.setVoicePlaying(playingVoiceMessageID == message.id)
        }
    }
}

final class VideoCallViewController: UIViewController {
    var onHangUp: (() -> Void)?

    private let participant: MessageParticipantViewModel
    private let backgroundImage: UIImage?
    private let tonePlayer = VideoCallTonePlayer()
    private let backgroundImageView = UIImageView()
    private let informationPanel = UIView()

    init(participant: MessageParticipantViewModel, backgroundImage: UIImage?) {
        self.participant = participant
        self.backgroundImage = backgroundImage
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tonePlayer.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        tonePlayer.stop()
        super.viewWillDisappear(animated)
    }

    private func buildLayout() {
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = AppTheme.background

        backgroundImageView.image = backgroundImage
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        backgroundImageView.backgroundColor = UIColor(hex: 0xD8DDE2)
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundImageView)

        informationPanel.backgroundColor = .white
        informationPanel.layer.cornerRadius = 26
        informationPanel.layer.cornerCurve = .continuous
        informationPanel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        informationPanel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(informationPanel)

        let nameLabel = UILabel()
        nameLabel.text = participant.name
        nameLabel.font = AppTheme.font(29, .bold)
        nameLabel.textColor = AppTheme.text
        nameLabel.textAlignment = .center

        let callingLabel = UILabel()
        callingLabel.text = "You are calling \(participant.name) ..."
        callingLabel.font = AppTheme.font(15, .bold)
        callingLabel.textColor = AppTheme.text
        callingLabel.textAlignment = .center
        callingLabel.numberOfLines = 2

        let hangUpButton = UIButton(type: .system)
        hangUpButton.backgroundColor = .clear
        hangUpButton.setImage(UIImage(named: "video_phone")?.withRenderingMode(.alwaysOriginal), for: .normal)
        hangUpButton.imageView?.contentMode = .scaleAspectFit
        hangUpButton.layer.cornerRadius = 36
        hangUpButton.layer.cornerCurve = .continuous
        hangUpButton.accessibilityLabel = "End video call"
        hangUpButton.addTarget(self, action: #selector(hangUpTapped), for: .touchUpInside)

        [nameLabel, callingLabel, hangUpButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            informationPanel.addSubview($0)
        }

        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: informationPanel.topAnchor, constant: 22),

            informationPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            informationPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            informationPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            informationPanel.heightAnchor.constraint(equalToConstant: 246),

            nameLabel.topAnchor.constraint(equalTo: informationPanel.topAnchor, constant: 36),
            nameLabel.leadingAnchor.constraint(equalTo: informationPanel.leadingAnchor, constant: 24),
            nameLabel.trailingAnchor.constraint(equalTo: informationPanel.trailingAnchor, constant: -24),

            callingLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 11),
            callingLabel.leadingAnchor.constraint(equalTo: informationPanel.leadingAnchor, constant: 24),
            callingLabel.trailingAnchor.constraint(equalTo: informationPanel.trailingAnchor, constant: -24),

            hangUpButton.topAnchor.constraint(equalTo: callingLabel.bottomAnchor, constant: 29),
            hangUpButton.centerXAnchor.constraint(equalTo: informationPanel.centerXAnchor),
            hangUpButton.widthAnchor.constraint(equalToConstant: 72),
            hangUpButton.heightAnchor.constraint(equalToConstant: 72)
        ])
    }

    @objc private func hangUpTapped() {
        tonePlayer.stop()
        onHangUp?()
    }
}

private final class VideoCallTonePlayer {
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private var isPlaying = false

    init() {
        engine.attach(node)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        engine.connect(node, to: engine.mainMixerNode, format: format)
    }

    func start() {
        guard !isPlaying else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
            let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
            guard let buffer = makeRingbackBuffer(format: format) else { return }
            node.scheduleBuffer(buffer, at: nil, options: .loops)
            try engine.start()
            node.play()
            isPlaying = true
        } catch {
            stop()
        }
    }

    func stop() {
        guard isPlaying || engine.isRunning else { return }
        node.stop()
        engine.stop()
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func makeRingbackBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let duration = 4.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let activeTime = time.truncatingRemainder(dividingBy: duration)
            guard activeTime < 1.6 else {
                samples[frame] = 0
                continue
            }
            let edge = min(min(activeTime / 0.025, (1.6 - activeTime) / 0.025), 1)
            let tone = sin(2 * .pi * 440 * time) + sin(2 * .pi * 480 * time)
            samples[frame] = Float(0.09 * max(0, edge) * tone)
        }
        return buffer
    }
}

extension ChatViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendTapped()
        return false
    }
}

private final class ChatStateView: UIView {
    private let indicator = UIActivityIndicatorView(style: .medium)
    private let label = UILabel()
    private let retryButton = UIButton(type: .system)
    private var retry: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = AppTheme.background
        label.font = AppTheme.font(14)
        label.textColor = AppTheme.secondaryText
        label.textAlignment = .center
        label.numberOfLines = 0
        retryButton.setTitle("Retry", for: .normal)
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.titleLabel?.font = AppTheme.font(14, .semibold)
        retryButton.backgroundColor = AppTheme.blue
        retryButton.contentEdgeInsets = UIEdgeInsets(top: 11, left: 24, bottom: 11, right: 24)
        retryButton.round(12)
        let stack = UIStackView(arrangedSubviews: [indicator, label, retryButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 30),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -30)
        ])
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError() }

    func showLoading() {
        isHidden = false
        label.text = "Loading local messages…"
        retryButton.isHidden = true
        indicator.startAnimating()
    }

    func show(message: String, retry: (() -> Void)?) {
        isHidden = false
        indicator.stopAnimating()
        label.text = message
        self.retry = retry
        retryButton.isHidden = retry == nil
    }

    @objc private func retryTapped() { retry?() }
}
