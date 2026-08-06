import UIKit

final class ReportViewController: BaseScrollViewController {
    enum Reason: String, CaseIterable {
        case politicallySensitive = "Politically sensitive"
        case bloodyViolence = "Bloody violence"
        case frequentHarassment = "Frequent harassment"
        case infringement = "Infringement of rights"
        case pornographic = "Pornographic and vulgar"
        case discrimination = "Discrimination"
        case others = "Others"
    }

    var onBack: (() -> Void)?
    var onReport: ((Reason, String?) -> Void)?

    let targetID: String?
    let targetType: String?

    private let reasonStack = UIStackView()
    private let noteField = AppTextField(placeholder: "Add a note (optional)")
    private let reportButton = BrandButton(title: "Report")
    private var selectedReason: Reason?
    private var reasonButtons: [Reason: UIButton] = [:]

    init(targetID: String? = nil, targetType: String? = nil) {
        self.targetID = targetID
        self.targetType = targetType
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        targetID = nil
        targetType = nil
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        updateSelection()
        render(state: .content)
    }

    func setSubmitting(_ submitting: Bool) {
        reportButton.isEnabled = !submitting && selectedReason != nil
        reportButton.setTitle(submitting ? "Recording…" : "Report", for: .normal)
        reportButton.alpha = reportButton.isEnabled ? 1 : 0.45
    }

    private func buildLayout() {
        contentStack.layoutMargins = UIEdgeInsets(top: 4, left: 20, bottom: 25, right: 20)
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.spacing = 20
        let header = AppHeaderView(title: "Report")
        header.backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(header)

        reasonStack.axis = .vertical
        reasonStack.spacing = 15
        for reason in Reason.allCases {
            let button = UIButton(type: .system)
            button.setTitle(reason.rawValue, for: .normal)
            button.setTitleColor(AppTheme.text, for: .normal)
            button.titleLabel?.font = AppTheme.font(14, .bold)
            button.backgroundColor = .white
            button.contentHorizontalAlignment = .center
            button.layer.borderWidth = 0
            button.round(13)
            button.heightAnchor.constraint(equalToConstant: 51).isActive = true
            button.addTarget(self, action: #selector(reasonTapped(_:)), for: .touchUpInside)
            reasonButtons[reason] = button
            reasonStack.addArrangedSubview(button)
        }
        contentStack.addArrangedSubview(reasonStack)
        noteField.isHidden = true
        contentStack.addArrangedSubview(noteField)
        contentStack.addSpacer(82)
        contentStack.addArrangedSubview(reportButton)
        reportButton.addTarget(self, action: #selector(reportTapped), for: .touchUpInside)
    }

    private func updateSelection() {
        for (reason, button) in reasonButtons {
            let selected = reason == selectedReason
            button.backgroundColor = selected ? AppTheme.blue : .white
            button.setTitleColor(selected ? .white : AppTheme.text, for: .normal)
            button.setImage(selected ? .symbol("checkmark", size: 19, weight: .bold) : nil, for: .normal)
            button.tintColor = .white
            button.configuration?.imagePadding = 18
            button.accessibilityTraits = selected ? [.button, .selected] : [.button]
        }
        noteField.isHidden = selectedReason != .others
        reportButton.isEnabled = selectedReason != nil
        reportButton.alpha = reportButton.isEnabled ? 1 : 0.45
    }

    @objc private func reasonTapped(_ sender: UIButton) {
        selectedReason = reasonButtons.first(where: { $0.value === sender })?.key
        updateSelection()
    }

    @objc private func backTapped() {
        if let onBack {
            onBack()
        } else if let navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    @objc private func reportTapped() {
        guard let selectedReason else { return }
        let cleanNote = noteField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = cleanNote?.isEmpty == false ? cleanNote : nil
        if let onReport {
            onReport(selectedReason, note)
            return
        }

        // Some feature screens open Report directly instead of through the
        // app coordinator. Keep the page functional for every entry path.
        do {
            guard let targetID, let targetType else { throw LocalStoreError.invalidInput }
            try LocalDataStore.shared.report(targetID: targetID,
                                             targetType: targetType,
                                             reason: selectedReason.rawValue,
                                             note: note)
            showKinvaNotice(title: "Report Successful",
                            message: "Thank you. Your report has been submitted.")
        } catch {
            showKinvaNotice(title: "Could Not Report", message: error.localizedDescription)
        }
    }
}
