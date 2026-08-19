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
        /// The app's name. Still the identity the item is keyed
        /// and announced by — glyph resolution and the
        /// accessibility label both read it — never what the
        /// item draws. That is `text`.
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

        /// `text` defaults to `name` so a fixture or a caller
        /// that only cares about identity still draws something
        /// legible rather than an empty slot.
        public init(
            id: WindowID,
            name: String,
            text: String? = nil,
            icon: NSImage?,
            glyph: String? = nil,
            count: Int = 1
        ) {
            self.id = id
            self.name = name
            self.text = text ?? name
            self.icon = icon
            self.glyph = glyph
            self.count = count
        }
    }
}
