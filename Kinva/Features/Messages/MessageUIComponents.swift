import UIKit

struct MessageParticipantViewModel: Hashable {
    let id: String
    let name: String
}

struct MessageConversationViewModel: Hashable {
    let id: String
    let participant: MessageParticipantViewModel
    var preview: String
    var timestamp: String
    var isUnread: Bool
}

struct ChatMessageViewModel: Hashable {
    enum Kind: Hashable {
        case text(String)
        case voice(duration: String, progress: CGFloat)
    }

    let id: String
    let sender: MessageParticipantViewModel
    var isOutgoing: Bool
    var kind: Kind
    var voiceToken: String?
}

struct SystemNotificationViewModel: Hashable {
    let id: String
    let actor: MessageParticipantViewModel?
    var text: String
    var timestamp: String
    var hasThumbnail: Bool
}

final class ConversationRowView: UIControl {
    private let avatar: AvatarView
    private let nameLabel = UILabel()
    private let previewLabel = UILabel()
    private let timeLabel = UILabel()
    private let unreadDot = UIView()

    init(model: MessageConversationViewModel) {
        avatar = AvatarView(name: model.participant.name, size: 52, userID: model.participant.id)
        super.init(frame: .zero)
        nameLabel.text = model.participant.name
        nameLabel.font = AppTheme.font(17, .bold)
        nameLabel.textColor = AppTheme.text
        previewLabel.text = model.preview
        previewLabel.font = AppTheme.font(13, model.isUnread ? .semibold : .regular)
        previewLabel.textColor = AppTheme.text
        previewLabel.numberOfLines = 1
        timeLabel.text = model.timestamp
        timeLabel.font = AppTheme.font(10, .semibold)
        timeLabel.textColor = AppTheme.text
        unreadDot.backgroundColor = AppTheme.blue
        unreadDot.round(4)
        unreadDot.isHidden = !model.isUnread
        let copy = UIStackView(arrangedSubviews: [nameLabel, previewLabel])
        copy.axis = .vertical
        copy.spacing = 5
        [avatar, copy, timeLabel, unreadDot].forEach {
            // ConversationRowView owns the complete row hit area. These views
            // are decorative and must not intercept touches inside the cell.
            $0.isUserInteractionEnabled = false
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 68),
            avatar.leadingAnchor.constraint(equalTo: leadingAnchor),
            avatar.centerYAnchor.constraint(equalTo: centerYAnchor),
            copy.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            copy.centerYAnchor.constraint(equalTo: avatar.centerYAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            timeLabel.topAnchor.constraint(equalTo: avatar.topAnchor, constant: 3),
            copy.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -10),
            unreadDot.trailingAnchor.constraint(equalTo: trailingAnchor),
            unreadDot.bottomAnchor.constraint(equalTo: avatar.bottomAnchor, constant: -3),
            unreadDot.widthAnchor.constraint(equalToConstant: 8),
            unreadDot.heightAnchor.constraint(equalToConstant: 8)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = "\(model.participant.name), \(model.preview), \(model.timestamp)"
    }

    required init?(coder: NSCoder) { fatalError() }
}

final class ChatBubbleView: UIView {
    var onVoice: (() -> Void)?
    private let voiceButton = UIButton(type: .system)
    private let voiceProgress = UIProgressView(progressViewStyle: .default)
    private let voiceDurationLabel = UILabel()
    private var voicePlaying = false

    init(message: ChatMessageViewModel, isPlaying: Bool = false) {
        super.init(frame: .zero)
        let avatar = AvatarView(name: message.sender.name, size: 40, userID: message.sender.id)
        let bubble = UIView()
        bubble.backgroundColor = message.isOutgoing ? .white : .white
        bubble.round(11)
        let bubbleContent: UIView
        switch message.kind {
        case .text(let text):
            let label = UILabel()
            label.text = text
            label.font = AppTheme.font(15, .bold)
            label.textColor = AppTheme.secondaryText
            label.numberOfLines = 0
            bubbleContent = label
        case .voice(let duration, let progress):
            bubble.backgroundColor = AppTheme.blue
            bubble.round(12)
            voiceButton.tintColor = .white
            voiceButton.backgroundColor = .clear
            voiceButton.contentHorizontalAlignment = .center
            voiceButton.setImage(.symbol("play.fill", size: 14, weight: .bold), for: .normal)
            voiceButton.addTarget(self, action: #selector(voiceTapped), for: .touchUpInside)
            voiceProgress.progressTintColor = .white
            voiceProgress.trackTintColor = UIColor.white.withAlphaComponent(0.35)
            voiceProgress.progress = Float(max(0, min(1, progress)))
            voiceDurationLabel.text = duration
            voiceDurationLabel.font = AppTheme.font(15, .bold)
            voiceDurationLabel.textColor = .white
            let row = UIStackView(arrangedSubviews: [voiceButton, voiceProgress, voiceDurationLabel])
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = 10
            voiceButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
            voiceProgress.widthAnchor.constraint(greaterThanOrEqualToConstant: 104).isActive = true
            bubbleContent = row
        }
        bubbleContent.translatesAutoresizingMaskIntoConstraints = false
        bubble.addSubview(bubbleContent)
        [avatar, bubble].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0) }
        NSLayoutConstraint.activate([
            bubbleContent.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 13),
            bubbleContent.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 13),
            bubbleContent.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -13),
            bubbleContent.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -13),
            bubble.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: message.isOutgoing ? 0.63 : 0.69),
            bubble.topAnchor.constraint(equalTo: topAnchor),
            bubble.bottomAnchor.constraint(equalTo: bottomAnchor),
            avatar.centerYAnchor.constraint(equalTo: bubble.centerYAnchor)
        ])
        if message.isOutgoing {
            NSLayoutConstraint.activate([
                avatar.trailingAnchor.constraint(equalTo: trailingAnchor),
                bubble.trailingAnchor.constraint(equalTo: avatar.leadingAnchor, constant: -10),
                bubble.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                avatar.leadingAnchor.constraint(equalTo: leadingAnchor),
                bubble.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 10),
                bubble.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
            ])
        }
        if case .voice = message.kind {
            setVoicePlaying(isPlaying)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func setVoicePlaying(_ playing: Bool) {
        voicePlaying = playing
        voiceButton.setImage(.symbol(playing ? "pause.fill" : "play.fill", size: 14, weight: .bold), for: .normal)
        voiceButton.accessibilityLabel = playing ? "Pause voice message" : "Play voice message"
    }

    func setVoiceProgress(_ progress: CGFloat) {
        voiceProgress.progress = Float(max(0, min(1, progress)))
    }

    @objc private func voiceTapped() {
        onVoice?()
    }
}
