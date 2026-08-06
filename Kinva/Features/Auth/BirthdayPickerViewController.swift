import UIKit

final class BirthdayPickerViewController: UIViewController {
    var onDone: ((Date) -> Void)?

    private let picker = UIDatePicker()

    init(selectedDate: Date?) {
        super.init(nibName: nil, bundle: nil)
        picker.date = selectedDate ?? Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
        modalPresentationStyle = .pageSheet
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        let title = UILabel()
        title.text = "Birthday"
        title.font = birthdayRoundedFont(22, weight: .bold)
        title.textColor = AppTheme.text

        let cancel = UIButton(type: .system)
        cancel.setTitle("Cancel", for: .normal)
        cancel.titleLabel?.font = birthdayRoundedFont(16, weight: .bold)
        cancel.setTitleColor(AppTheme.secondaryText, for: .normal)
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let done = UIButton(type: .system)
        done.setTitle("Done", for: .normal)
        done.titleLabel?.font = birthdayRoundedFont(16, weight: .bold)
        done.setTitleColor(.white, for: .normal)
        done.backgroundColor = AppTheme.blue
        done.round(10)
        done.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)

        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.maximumDate = Date()
        picker.minimumDate = Calendar.current.date(byAdding: .year, value: -120, to: Date())

        [title, cancel, done, picker].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: view.topAnchor, constant: 22),
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            cancel.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            cancel.trailingAnchor.constraint(equalTo: done.leadingAnchor, constant: -12),
            cancel.widthAnchor.constraint(greaterThanOrEqualToConstant: 62),
            cancel.heightAnchor.constraint(equalToConstant: 42),
            done.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            done.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            done.widthAnchor.constraint(equalToConstant: 72),
            done.heightAnchor.constraint(equalToConstant: 42),
            picker.topAnchor.constraint(greaterThanOrEqualTo: title.bottomAnchor, constant: 8),
            picker.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            picker.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            picker.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            picker.heightAnchor.constraint(equalToConstant: 216)
        ])

        if let sheet = sheetPresentationController {
            if #available(iOS 16.0, *) {
                let compact = UISheetPresentationController.Detent.custom(identifier: .init("birthday.compact")) { context in
                    min(330, context.maximumDetentValue)
                }
                sheet.detents = [compact]
            } else {
                sheet.detents = [.medium()]
            }
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
    }

    @objc private func cancelTapped() { dismiss(animated: true) }
    @objc private func doneTapped() {
        let date = picker.date
        let completion = onDone
        dismiss(animated: true) { completion?(date) }
    }
}

private func birthdayRoundedFont(_ size: CGFloat, weight: UIFont.Weight) -> UIFont {
    let base = UIFont.systemFont(ofSize: size, weight: weight)
    guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
    return UIFont(descriptor: descriptor, size: size)
}
