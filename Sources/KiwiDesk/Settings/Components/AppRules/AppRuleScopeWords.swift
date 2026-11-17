import KiwiDeskCore

/// The Space rows' scope words (#3341): which of an app's windows a
/// row opens in its Space. The Float rows' "All windows" and
/// "Windows titled…" are the same keys, so the two cards read
/// alike. Computed per read, never stored (#1311).
@MainActor
enum AppRuleScopeWords {
    static var all: String {
        L("app_rules.float.scope.all", "All windows")
    }

    /// The bare row while titled rows of its app stand above it.
    static var allOther: String {
        L("app_rules.space.scope.all_other", "All other windows")
    }

    /// The Float menu's item opening the pattern editor.
    static var titledItem: String {
        L("app_rules.float.scope.titled", "Windows titled…")
    }

    /// A titled row's resting value, its fragment in the frame.
    static func titled(_ fragment: String) -> String {
        L(
            "app_rules.space.scope.titled.value",
            "Windows titled “%1$@”",
            fragment
        )
    }

    /// A titled row's item opening the popover on its own title.
    static var changeTitle: String {
        L("app_rules.space.scope.change_title", "Change Title…")
    }

    static var addTitled: String {
        L(
            "app_rules.space.scope.add_titled",
            "Add Rule for Windows Titled…"
        )
    }

    /// Why a titled row cannot become the bare one: the app has it.
    static var allTaken: String {
        L(
            "app_rules.space.scope.all_taken",
            "Delete this row to open these windows with “%1$@”.",
            allOther
        )
    }

    /// Why a typed pattern cannot be added: its app has that row.
    static func duplicate(app: String, _ fragment: String) -> String {
        L(
            "app_rules.space.scope.duplicate",
            "%1$@ already has a row for “%2$@”.",
            app,
            fragment
        )
    }

    /// The scope menu's spoken name.
    static var menuName: String {
        L("app_rules.space.scope", "Which windows")
    }
}
