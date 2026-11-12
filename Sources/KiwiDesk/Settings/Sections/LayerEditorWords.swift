import KiwiDeskCore

/// The words the Layers card's ✎, + and editor popovers say
/// (#3263), one home so the drawn and spoken forms cannot drift.
@MainActor
enum LayerEditorWords {
    static var addHelp: String {
        L("shortcuts.add_layer.help", "Add a layer")
    }

    /// ✎'s label and help, which name the layer it edits.
    static func editHelp(_ layer: String) -> String {
        L("shortcuts.layer_edit.help", "Edit layer “%1$@”…", layer)
    }

    /// ✎ greyed on `default`, and why.
    static var defaultHelp: String {
        L(
            "shortcuts.layer_edit.default_help",
            "The “default” layer can't be renamed, deleted or given "
                + "an icon."
        )
    }

    static var newLayer: String {
        L("shortcuts.layer_add.title", "New layer")
    }

    static var name: String {
        L("shortcuts.layer_editor.name", "Name")
    }

    static var namePlaceholder: String {
        L("shortcuts.layer_name", "Layer name")
    }

    static var icon: String {
        L("shortcuts.menu_bar_icon", "Menu bar icon")
    }

    static var reach: String {
        L("app_rules.reach", "Applies to")
    }

    /// Why a new layer's Applies to is dimmed.
    static var reachAfterAdd: String {
        L(
            "shortcuts.layer_add.reach_after_add",
            "You can change this once the layer is added."
        )
    }

    static var deleteLayer: String {
        L("shortcuts.layer_editor.delete", "Delete Layer…")
    }

    static var done: String {
        L("common.done", "Done")
    }

    static var cancel: String {
        L("shortcuts.layer_add.cancel", "Cancel")
    }

    static var add: String {
        L("shortcuts.add", "Add")
    }

    /// The row is drawn where there is a second profile to name.
    static func offersReach(_ reading: RuleReachReading) -> Bool {
        reading.profiles.count + reading.unreadable.count >= 2
    }

    /// Where a layer not yet on the page starts: shared, or the
    /// edited profile alone, which the reading of a name no file
    /// holds leaves out until the add records it.
    static func startingReach(_ reading: RuleReachReading) -> String {
        var start = reading
        if !start.shared { start.users.insert(start.editing) }
        return RuleReachWords.label(start)
    }
}
