import KiwiDeskCore

/// A navigation target inside the Settings window (#277): which
/// sidebar destination, which of its local surfaces, and —
/// optionally — which labelled thing inside it to scroll to and
/// briefly flash.
///
/// `anchor` is the **resolved, localized label text**, never an
/// `L()` key, and that is the load-bearing decision here.
/// `SettingsSection` tags itself `.id(title)` from the title it
/// was already handed, so a scroll target needs no second
/// identifier threaded through forty call sites — and the search
/// index already stores the `L(key, english)` tuple whose text
/// this is. One list, and it is the render path: there is no
/// hand-mirrored id table to drift from the views
/// (`.claude/rules/parity-tests.md`). The cost is that two
/// same-titled anchors in one destination are one id; `scrollTo`
/// then picks the first, which is the behavior the index already
/// documents ("the first matching subsection wins").
struct SettingsAnchor: Hashable {
    let destination: SettingsDestination
    /// The local branch that must be showing before the anchor
    /// exists in the view tree at all.
    var surface: SettingsSurface = .main
    /// Label text to reveal, or nil for "just open the
    /// destination" — the #326 "Edit in Settings…" deep link,
    /// which names a tab and nothing finer.
    var anchor: String?
}

/// The local switches a destination hides content behind, lifted
/// out of view-local `@State` so a search hit can set them
/// (#277). `.main` is the plain case — most destinations have no
/// such switch.
///
/// These are *selections*, not disclosure state, and the
/// distinction is why there is no `.drawer` case: a collapsed
/// `DisclosureGroup` still renders its own header, so a hit on a
/// drawer scrolls to a label that is already on screen and needs
/// nothing forced open. A hit on a control *inside* a drawer
/// does — that arrives with the per-control catalog, which is
/// also what supplies the control→parent-drawer relation needed
/// to do it without hand-listing one.
enum SettingsSurface: Hashable {
    case main
    case layoutMode(LayoutMode)
    case bar(BarEditor)
}

/// The two editors behind the Bars switch (#293). A top-level
/// type rather than `BarsSection.Editor` (#277): the selection
/// now lives on `SettingsModel` so a hit on a `space_bar.*`
/// header can land in the right editor, and a nested type would
/// make the model import the view that owns it.
enum BarEditor: String, CaseIterable, Hashable {
    case appBar
    case spaceBar

    /// The switch chip's label, and the breadcrumb segment a
    /// search result shows — one home, so the two cannot drift.
    @MainActor var displayName: String {
        switch self {
        case .appBar:
            return L("bars.switch.app_bar", "App Bar")
        case .spaceBar:
            return L("bars.switch.space_bar", "Space Bar")
        }
    }
}
