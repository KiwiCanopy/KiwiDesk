import KiwiDeskCore

/// A navigation target inside the Settings window (#277): which
/// sidebar destination, which of its local surfaces, and —
/// optionally — which cataloged control inside it to scroll to
/// and briefly flash.
///
/// `anchor` is a **`SettingsControl.id`**, never display text,
/// and that is the load-bearing decision here. Part 1 anchored
/// by resolved label text — sound for header-level anchors and
/// measured-dead one level down (Appearance renders "Color" six
/// times simultaneously; `SlotSizeRows.sizeLabel` swaps with a
/// sibling picker, so text `.id()` churn would tear down rows
/// holding uncommitted `@State` drafts mid-edit). The catalog
/// declaration a render site consumes supplies both its label
/// and this id, so there is still exactly one list and it is the
/// render path (`.claude/rules/parity-tests.md`) — the id is
/// merely the stable half of that declaration.
struct SettingsAnchor: Hashable {
    let destination: SettingsDestination
    /// The local branch that must be showing before the anchor
    /// exists in the view tree at all.
    var surface: SettingsSurface = .main
    /// The `SettingsControl.id` to reveal, or nil for "just open
    /// the destination" — the #326 "Edit in Settings…" deep
    /// link, which names a tab and nothing finer.
    var anchor: String?

    /// What the shell should do with this request, or nil to
    /// refuse it.
    ///
    /// A pure decision, split from the assignment in
    /// `SettingsView.apply` so the parts worth pinning are
    /// reachable from a test: the #18 reachability refusal, which
    /// of the three surfaces to select, and the nil-anchor case
    /// that must request no scroll (the #326 bridge). What is left
    /// in the view is three field writes.
    ///
    /// A surface that its destination cannot render is dropped to
    /// `.main` rather than refusing the whole request — the
    /// destination is still worth opening. This is the only
    /// decision point, so the check belongs here: the index side
    /// is guarded by `surfacesMatchDestination`, but a hand-built
    /// anchor carrying `.layoutMode(.floating)` would otherwise
    /// select a tab whose editor is `EmptyView`, i.e. an empty
    /// Layout Defaults pane.
    func resolved(
        editingStoredProfile: Bool
    ) -> (
        destination: SettingsDestination,
        surface: SettingsSurface,
        scroll: String?
    )? {
        guard
            destination.isReachable(
                editingStoredProfile: editingStoredProfile
            )
        else { return nil }
        return (destination, renderableSurface, anchor)
    }

    /// `surface` if `destination` can show it, else `.main`.
    private var renderableSurface: SettingsSurface {
        switch surface {
        case .main:
            return .main
        case .layoutMode(let mode):
            let renders =
                destination == .layoutDefaults
                && LayoutMode.placementTabs.contains(mode)
            return renders ? surface : .main
        }
    }
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
/// nothing forced open. A hit on a control *inside* a drawer is
/// handled by the drawer itself: `SettingsDisclosure` reads the
/// standing reveal target from the environment and expands when
/// its own `SettingsDrawer` children contain it — a render-path
/// fact, never a surface case or a catalog column.
enum SettingsSurface: Hashable {
    case main
    case layoutMode(LayoutMode)
}
