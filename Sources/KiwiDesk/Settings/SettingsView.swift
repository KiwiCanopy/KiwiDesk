import KiwiDeskCore
import SwiftUI

/// Settings dashboard shell hosting Home grid or pushed section screen (#678).
struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    /// Scroll and flash task for pending reveal, held so a second
    /// search click supersedes the first instead of overlapping.
    @State var revealTask: Task<Void, Never>?
    /// Preview card state per mount; nil follows width class default
    /// (`DetailPanelTests`).
    @State var previewShown: Bool?
    @Environment(\.accessibilityReduceMotion)
    var reduceMotion

    /// Whether current destination supports detail panel.
    var panelOffered: Bool {
        SettingsDetailPanelOffer.offers(model.destination)
            && !model.editingLua
    }

    private var selection: SettingsDestination? {
        get { model.destination }
        nonmutating set { model.destination = newValue }
    }

    var body: some View {
        // The ONE measurement: every responsive verdict below
        // derives from the class this hands down, so no site
        // compares a width of its own (17a).
        GeometryReader { geo in
            let width = SettingsWidthClass.of(
                width: geo.size.width
            )
            shell(width)
                .environment(\.settingsWidth, width)
                // Re-docking retires the per-mount answer — a
                // "not now" must not outlive the band it was given
                // in (architecture review, 2026-08-11).
                .onChange(of: width) { _, now in
                    if now.docksPanel { previewShown = nil }
                }
        }
        .frame(
            minWidth: SettingsWidthClass.minimum,
            minHeight: SettingsWidthClass.minimumHeight
        )
        // Set ONCE at the root so no control can opt out (owner
        // ruled full kiwi, 2026-08-04); above the `editingLua`
        // branch so both arms carry it.
        .tint(SettingsTheme.accent)
        // The one discard dialog (#515), hosted above the
        // `editingLua` branch: `chrome` is instantiated per arm
        // and two gated actions flip `editingLua`, so a dialog
        // hosted there is torn down by its own confirm button.
        .discardConfirmation(model: model)
        // Two repairs on two signals, deliberately unmerged:
        // reachability keys on the live↔stored transition, the
        // mode tab on the target — stored A → stored B leaves the
        // boolean true. The selection must never point at a
        // destination the grid just hid (#18); Home is the repair
        // target.
        .onChange(of: model.editingStoredProfile) { _, editing in
            if let selection,
                !selection.isReachable(
                    editingStoredProfile: editing
                )
            {
                self.selection = nil
            }
        }
        .onChange(of: model.target) { _, _ in
            // A different profile means a different most-used
            // mode, so the tab re-derives (#277).
            model.nav.resetSurfaces()
        }
        // The #326 "Edit in Settings…" deep link or a #277 search
        // hit, guarded by the same #18 reachability filter as
        // every other nav path.
        .onChange(of: model.nav.pendingReveal) { _, request in
            apply(request)
        }
        .onAppear { apply(model.nav.pendingReveal) }
        .onChange(of: model.destination) { _, _ in
            previewShown = nil
        }
    }

    @ViewBuilder private func shell(
        _ width: SettingsWidthClass
    ) -> some View {
        if model.editingLua {
            chrome(width) { LuaEditorTab(model: model) }
        } else {
            structuredShell(width)
        }
    }

    /// Structured settings shell with header, body content, and save footer
    /// (#297, #68).
    private func structuredShell(
        _ width: SettingsWidthClass
    ) -> some View {
        chrome(width) {
            if selection == nil {
                HomeScreen(model: model)
            } else {
                detailPane(width)
            }
        }
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(.container, edges: .top)
        .onExitCommand {
            if selection != nil { selection = nil }
        }
        .environment(\.settingsNavigate) { destination in
            // Third #18 enforcement point beside the grid's offer
            // filter and the onChange repair, which only fires on
            // editing-flag transitions: links must refuse what the
            // grid hides.
            guard
                destination.isReachable(
                    editingStoredProfile:
                        model.editingStoredProfile
                )
            else { return }
            ensureModeAdmits(destination)
            selection = destination
        }
    }

    /// Switches Simple to Power User mode when navigation targets advanced
    /// section (#678).
    func ensureModeAdmits(
        _ destination: SettingsDestination
    ) {
        if !HomeCardOrder.isOffered(
            destination,
            mode: model.settingsMode,
            displayCount: model.displays.count,
            editingStoredProfile: model.editingStoredProfile
        ),
            destination.isReachable(
                editingStoredProfile:
                    model.editingStoredProfile
            )
        {
            model.setSettingsMode(.powerUser)
        }
    }

}
