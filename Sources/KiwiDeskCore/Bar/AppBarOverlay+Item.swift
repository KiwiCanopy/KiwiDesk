import AppKit

/// One App Bar entry as the driver hands it over. Split from
/// AppBarOverlay.swift, which sat on the §2.1 file ceiling.
///
/// The overlay is a dumb renderer: everything here is already
/// RESOLVED — the glyph picked over the image (#294), and the
/// drawn text picked over the app name and capped
/// (`KiwiCore.barItemText`). Nothing in the render pass decides
/// what an item says.
extension AppBarOverlay {
    public struct Item {
        public let id: WindowID
        /// The app's name — the item's identity, never what it
        /// draws (that is `text`).
        ///
        /// The glyph is resolved from the same app name in the
        /// driver BEFORE this value exists, and the App Bar item
        /// carries no accessibility label, so nothing reads this
        /// today. It is the input an explicit AX label would be
        /// built from; see `AppBarItemView.name`.
        public let name: String
        /// The string the item actually draws under a
        /// text-bearing `Content`: the window's title, already
        /// capped, with the app name standing in for a collapsed
        /// group or an empty title. Resolved by the driver
        /// (`KiwiCore.barItemText`) so the overlay stays a dumb
        /// renderer, exactly like `glyph`.
        public let text: String
        public let icon: NSImage?
        /// SketchyBar App Font ligature to render instead of
        /// `icon` (#294); nil = native image. Resolved by the
        /// driver so the overlay stays a dumb renderer.
        public let glyph: String?
        /// Windows behind this item; > 1 for a group of
        /// adjacent same-app windows (shown as a badge).
        public let count: Int

        /// `text` is REQUIRED, deliberately. Defaulting it to
        /// `name` made every render-side fixture blind: with the
        /// two equal by construction, no assertion could tell a
        /// bar drawing the title from one drawing the app name,
        /// and both the label write and the slot measurement
        /// could be reverted with the suite green (guard-prover,
        /// 2026-08-19). A silent fallback on a driver-resolved
        /// value is worth less than three explicit fixtures.
        public init(
            id: WindowID,
            name: String,
            text: String,
            icon: NSImage?,
            glyph: String? = nil,
            count: Int = 1
        ) {
            self.id = id
            self.name = name
            self.text = text
            self.icon = icon
            self.glyph = glyph
            self.count = count
        }
    }
}
