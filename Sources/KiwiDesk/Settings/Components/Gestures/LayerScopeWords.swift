import KiwiDeskCore

/// The Shortcuts page's words for what a layer reaches (#3535): the
/// layer strip above the switcher scopes every part below it, so a
/// setting that is not the layer's says so, and a layer that binds
/// no gestures says what that means.
@MainActor
enum LayerScopeWords {
    /// Under a setting that applies whatever layer is active.
    static var everyLayer: String {
        L("shortcuts.every_layer", "Applies in every layer.")
    }

    /// Over Mouse & Trackpad while `layer` binds no gesture.
    static func noGestures(_ layer: String) -> String {
        L(
            "shortcuts.gestures.layer_empty",
            "\u{201C}%1$@\u{201D} binds no gestures. While it is "
                + "active, the mouse and trackpad do only what macOS "
                + "does.",
            layer
        )
    }
}
