import Foundation
import KiwiDeskCore

extension Bundle {
    /// This target's resources. Routed through
    /// `ResourceBundle.locate` rather than used as
    /// `Bundle.module` directly, because inside an `.app` the
    /// generated accessor searches the bundle *root* — where a
    /// signed app may not keep anything — and otherwise falls
    /// through to an absolute `.build` path that exists only on
    /// the machine that compiled it (#89).
    /// See `Bundle.kiwiDeskCoreName` — pinned on disk, because
    /// the accessor cannot expose a wrong literal.
    static let kiwiDeskGuiName = "KiwiDesk_KiwiDesk"

    static let kiwiDeskGui: Bundle = ResourceBundle.locate(
        kiwiDeskGuiName,
        fallback: .module
    )
}
