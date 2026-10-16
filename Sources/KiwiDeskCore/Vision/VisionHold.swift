import Foundation

/// A lens's delayed clear (#2103 rulings 12, 14, 30, 34): a window
/// the lens leaves out that takes the focus stays under the haze
/// for the lens's delay, with a reminder pill on it. One hold at a
/// time; its deadline is the `.visionHold` deferred slot.
struct VisionHold: Equatable {
    /// The window held under the haze.
    let window: WindowID

    /// What the plate's new target is, as a hold judges it.
    struct Landing: Equatable {
        /// The lens on leaves it out (`KiwiCore.lensKeySkip`).
        var leftOut: Bool
        /// A Never dimmed app's: clear without being a member.
        var neverDimmed = false
        /// A transient overlay or raised-layer window — a palette,
        /// a quick terminal, a banner (ruling 14).
        var overlay = false
        /// KiwiDesk's own window.
        var own = false
        /// A dialog of the app whose window was clear (ruling 14).
        var dialogOfClear = false
        /// A fresh click reached it: the one landing that never
        /// waits (ruling 34).
        var clicked = false
    }

    /// Whether `landing` waits under the haze. Every landing
    /// waits — a key, ⌘-Tab, the Dock, a notification, a Space
    /// switch — save a click on the window itself and the classes
    /// ruling 14 never pills.
    static func begins(_ landing: Landing) -> Bool {
        landing.leftOut && !landing.neverDimmed && !landing.overlay
            && !landing.own && !landing.dialogOfClear
            && !landing.clicked
    }
}
