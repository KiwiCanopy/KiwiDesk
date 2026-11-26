import Foundation

/// A window id's re-key and end reach every BSP split it owns
/// (#3672), on every Space, Desktop and arrangement, through the
/// store's clearing door.
extension KiwiCore {
    /// A native-tab re-key: the splits `old` owned move to `new`.
    func rekeyBspSplits(_ old: WindowID, to new: WindowID) {
        clearSessionRatios { $0.bspSplits?.rekey(old, to: new) }
    }

    /// A closed window's splits end with it; a vanish or a hide comes
    /// back under the same id and keeps them.
    func forgetBspSplits(of window: WindowID) {
        clearSessionRatios { ratios in
            ratios.bspSplits?.forget(window)
            if ratios.bspSplits?.isEmpty == true { ratios.bspSplits = nil }
        }
    }
}
