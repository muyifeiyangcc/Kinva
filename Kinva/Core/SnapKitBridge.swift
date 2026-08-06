#if canImport(SnapKit)
import SnapKit
import UIKit

extension UIView {
    /// CocoaPods-backed convenience used by isolated overlays while the main layout remains readable Auto Layout.
    func pinToSuperviewUsingSnapKit() {
        snp.makeConstraints { make in make.edges.equalToSuperview() }
    }
}
#endif
