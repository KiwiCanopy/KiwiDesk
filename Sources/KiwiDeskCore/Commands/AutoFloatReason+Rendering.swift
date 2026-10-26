import Foundation

/// Where a Tile refusal becomes words (#1810, #96): the pill Core
/// draws on the window and the subtitle of the bar menu's greyed
/// row take this one sentence, so they cannot disagree.
extension AutoFloatReason {
    /// A rule's sentence names App Rules, where it is changed, and
    /// so does a guess's (#2173): "always" is kept for the floats
    /// no setting removes.
    @MainActor
    var sentence: String {
        switch self {
        case .rule:
            L("float.refusal.rule", "An App Rule floats this window")
        case .panel, .raisedLayer:
            L("float.refusal.panel", "Dialogs and panels always float")
        case .accessoryApp:
            L(
                "float.refusal.accessory_app",
                "Apps without a Dock icon float automatically. "
                    + "Change it in %1$@.",
                Self.appRules
            )
        case .fixedSize:
            L(
                "float.refusal.fixed_size",
                "Windows that can't be resized float automatically. "
                    + "Change it in %1$@.",
                Self.appRules
            )
        case .pocket:
            L("pocket.refusal.float", "Pocket windows always float")
        }
    }

    @MainActor
    private static var appRules: String {
        L("destination.app_rules", "App Rules")
    }

    /// The pill's glyph: no tile here, the resize family's
    /// non-arrow (`ResizeRefusal.pillSymbol`), SF Symbols 1.0.
    var pillSymbol: String { "nosign" }

    /// The reason's wire spelling in `explain_window` (#1685) — a
    /// stored machine contract once shipped.
    var wireName: String {
        switch self {
        case .rule: "rule"
        case .panel: "panel"
        case .raisedLayer: "raised_layer"
        case .accessoryApp: "accessory_app"
        case .fixedSize: "fixed_size"
        case .pocket: "pocket"
        }
    }

    /// What would let the window tile, as the verb that does it:
    /// a guess yields to Float automatically off or to a Tile rule
    /// (#2173), which no verb writes, so it is named `tile_rule`;
    /// a rule yields to its removal, and a panel to nothing.
    var escapes: [String] {
        switch self {
        case .accessoryApp, .fixedSize:
            ["set_float_automatically", "tile_rule"]
        case .rule: ["app_rule.remove_float"]
        case .panel, .raisedLayer, .pocket: []
        }
    }

    /// The CLI/IPC failure — English, a machine contract (#96).
    var failure: String {
        switch self {
        case .rule: "a float rule floats this window"
        case .panel, .raisedLayer: "dialogs and panels always float"
        case .accessoryApp:
            "apps without a Dock icon float automatically"
        case .fixedSize:
            "windows that can't be resized float automatically"
        case .pocket: "pocket windows always float"
        }
    }
}
