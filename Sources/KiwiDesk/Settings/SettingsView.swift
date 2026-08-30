import KiwiDeskCore
import SwiftUI

/// Settings dashboard shell hosting Home grid or pushed section screen (#678).
struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    /// Scroll and flash task for pending reveal.
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
        GeometryReader { geo in
            let width = SettingsWidthClass.of(
                width: geo.size.width
            )
            shell(width)
                .environment(\.settingsWidth, width)
                .onChange(of: width) { _, now in
                    if now.docksPanel { previewShown = nil }
                }
        }
        .frame(
            minWidth: SettingsWidthClass.minimum,
            minHeight: SettingsWidthClass.minimumHeight
        )
        .tint(SettingsTheme.accent)
        .discardConfirmation(model: model)
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
            model.nav.resetSurfaces()
        }
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
