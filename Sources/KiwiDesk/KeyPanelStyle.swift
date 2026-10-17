import SwiftUI

/// The one style the key panels share — Jump to window and the
/// shortcuts overview (#2229 ▸ shared panel style): a panel's
/// corners, and a selection pill inset so it stays concentric
/// with them.
enum KeyPanelStyle {
    static let cornerRadius: CGFloat = 16
    /// The selection pill's inset from the panel's sides.
    static let selectionInset: CGFloat = 6
    static var selectionRadius: CGFloat { cornerRadius - selectionInset }

    static var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}
