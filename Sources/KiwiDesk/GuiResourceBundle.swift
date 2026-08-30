import Foundation
import KiwiDeskCore

extension Bundle {
    /// Resource bundle name for the KiwiDesk GUI target (#89).
    static let kiwiDeskGuiName = "KiwiDesk_KiwiDesk"

    static let kiwiDeskGui: Bundle = ResourceBundle.locate(
        kiwiDeskGuiName,
        fallback: .module
    )
}
