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
    static let kiwiDeskGui: Bundle = ResourceBundle.locate(
        "KiwiDesk_KiwiDesk",
        fallback: .module
    )
}
