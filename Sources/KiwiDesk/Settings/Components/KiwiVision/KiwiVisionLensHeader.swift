import KiwiDeskCore
import SwiftUI

/// The selected lens's header (#2103 rulings 29, 38, 48, 49, 53):
/// its name as the title, which saved profiles it applies to, its
/// shortcut — the one `KeyBinding` row Shortcuts ▸ KiwiVision
/// draws, registered on Save only — Rename… and Delete Lens….
struct KiwiVisionLensHeader: View {
    @ObservedObject var model: SettingsModel
    let lens: String
    @State private var renameRequest: NameEditRequest?
    @State private var deleting: LensDeleteRequest?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lens)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 10) {
                if let profiles = model.lensProfiles, !profiles.isEmpty {
                    Text(KiwiVisionLensWords.appliesTo)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    KiwiVisionLensReachControl(
                        model: model,
                        lens: lens,
                        profiles: profiles
                    )
                }
                Spacer(minLength: 8)
                renameButton
                Button(KiwiVisionLensWords.deleteLens, role: .destructive) {
                    deleting = LensDeleteRequest(id: lens)
                }
                .buttonStyle(.bordered)
            }
            NavRow(
                model: model,
                bindings: defaultBindings,
                command: KeybindingCatalog.toggleLens(lens)
            )
            if let layer = otherLayer {
                Text(KiwiVisionLensWords.chordElsewhere(layer))
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.callout)
        .confirmationDialog(
            KiwiVisionLensWords.deleteTitle(deleting?.id ?? lens),
            isPresented: Binding(
                get: { deleting != nil },
                set: { if !$0 { deleting = nil } }
            ),
            titleVisibility: .visible,
            presenting: deleting
        ) { request in
            Button(KiwiVisionLensWords.delete, role: .destructive) {
                model.deleteLens(request.id)
                model.nav.kiwiVisionLens = nil
            }
        } message: { _ in
            Text(KiwiVisionLensWords.deleteMessage)
        }
    }

    private var renameButton: some View {
        Button(KiwiVisionLensWords.renameEllipsis) {
            renameRequest = NameEditRequest(seed: lens, subject: lens)
        }
        .settingsActionButton()
        .popover(item: $renameRequest, arrowEdge: .bottom) { request in
            NameEditPopover(
                seed: request.seed,
                placeholder: KiwiVisionLensWords.lensName,
                confirmLabel: { _ in KiwiVisionLensWords.rename },
                isValid: {
                    AppWideSettings.lensName($0) != lens
                        && model.lensNameRefusal($0, renaming: lens) == nil
                },
                problem: {
                    model.lensNameRefusal($0, renaming: lens)
                        .flatMap(KiwiVisionLensWords.refusal)
                }
            ) { typed in
                guard model.renameLens(lens, to: typed) == nil else { return }
                renameRequest = nil
                model.nav.kiwiVisionLens = AppWideSettings.lensName(typed)
            }
            .settingsPopoverChrome()
        }
    }

    /// A layer other than the default holding a chord for the
    /// lens: that chord is the layer's, edited on Shortcuts.
    private var otherLayer: String? {
        model.config.layers.first { layer in
            !layer.isDefault
                && layer.bindings.contains {
                    KeybindingCatalog.isLensChord($0, lens)
                }
        }?.name
    }

    /// The default layer's rows, where the header reads and
    /// writes a lens chord; a chord on another layer is that
    /// layer's, edited on Shortcuts.
    private var defaultBindings: Binding<[KeyBinding]> {
        let index = model.config.layers.firstIndex(where: \.isDefault)
        return Binding(
            get: { index.map { model.config.layers[$0].bindings } ?? [] },
            set: { rows in
                guard let index else { return }
                model.config.layers[index].bindings = rows
            }
        )
    }
}

/// "Applies to" for a lens (ruling 38): the closed label, and a
/// checklist of the saved profiles; built-in setups always take
/// every lens, which the popover says.
struct KiwiVisionLensReachControl: View {
    @ObservedObject var model: SettingsModel
    let lens: String
    let profiles: [String]
    @State private var request: RuleReachRequest?

    var body: some View {
        let reached = model.lensReach(lens) ?? Set(profiles)
        let label = KiwiVisionLensWords.reachLabel(
            profiles.filter(reached.contains),
            of: profiles
        )
        Button {
            request = RuleReachRequest(id: lens)
        } label: {
            AppRuleMenuLabel(text: label)
        }
        .buttonStyle(.borderless)
        .menuTriggerHover()
        .accessibilityLabel(KiwiVisionLensWords.appliesTo)
        .accessibilityValue(label)
        .popover(item: $request, arrowEdge: .bottom) { _ in
            checklist(reached)
                .settingsPopoverChrome()
        }
    }

    private func checklist(_ reached: Set<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(
                RuleReachWords.allProfiles,
                isOn: Binding(
                    get: { reached.count == profiles.count },
                    set: { model.setLensReach(lens, $0 ? Set(profiles) : []) }
                )
            )
            .toggleStyle(.checkbox)
            Divider()
            ForEach(profiles, id: \.self) { profile in
                Toggle(
                    profile,
                    isOn: Binding(
                        get: { reached.contains(profile) },
                        set: { on in
                            var next = reached
                            if on {
                                next.insert(profile)
                            } else {
                                next.remove(profile)
                            }
                            model.setLensReach(lens, next)
                        }
                    )
                )
                .toggleStyle(.checkbox)
            }
            Text(KiwiVisionLensWords.reachCaption)
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
                .frame(width: 240, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(KiwiVisionLensWords.appliesTo)
    }
}

/// The delete dialog's request, built from ONE lens (#843).
struct LensDeleteRequest: Identifiable {
    let id: String
}
