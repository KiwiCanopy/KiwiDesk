import Foundation

/// Where a Tile refusal becomes words (#1810, #96): the pill Core
/// draws on the window and the subtitle of the bar menu's greyed
/// row take this one sentence, so they cannot disagree.
extension AutoFloatReason {
    /// A rule's sentence names App Rules, where it is changed.
    @MainActor
    var sentence: String {
        switch self {
        case .rule:
            L("float.refusal.rule", "An App Rule floats this window")
        case .panel:
            L("float.refusal.panel", "Dialogs and panels always float")
        case .accessoryApp:
            L(
                "float.refusal.accessory_app",
                "Apps without a Dock icon always float"
            )
        }
    }

    /// The CLI/IPC failure — English, a machine contract (#96).
    var failure: String {
        switch self {
        case .rule: "a float rule floats this window"
        case .panel: "dialogs and panels always float"
        case .accessoryApp: "apps without a Dock icon always float"
        }
    }
}
