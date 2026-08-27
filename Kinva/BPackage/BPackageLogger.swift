import Foundation

final class BPackageLogger: @unchecked Sendable {
    static let bPackageShared = BPackageLogger()
    var bPackageOnLog: ((String) -> Void)?

    func bPackageLog(_ bPackageCategory: String, _ bPackageMessage: String) {
        let bPackageFormatter = DateFormatter()
        bPackageFormatter.dateFormat = "HH:mm:ss.SSS"
        let bPackageLine = "[\(bPackageFormatter.string(from: Date()))] [\(bPackageCategory)] \(bPackageMessage)"
        print(bPackageLine)
        if Thread.isMainThread { bPackageOnLog?(bPackageLine) }
        else { DispatchQueue.main.async { [weak self] in self?.bPackageOnLog?(bPackageLine) } }
    }
}
