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
    @State private var deleting = false

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
                    deleting = true
                }
                .buttonStyle(.bordered)
            }
            NavRow(
                model: model,
                bindings: defaultBindings,
                command: KeybindingCatalog.toggleLens(lens)
            )
        }
        .font(.callout)
        .confirmationDialog(
            KiwiVisionLensWords.deleteTitle(lens),
            isPresented: $deleting,
            titleVisibility: .visible
        ) {
            Button(KiwiVisionLensWords.delete, role: .destructive) {
                model.deleteLens(lens)
                model.nav.kiwiVisionLens = nil
            }
        } message: {
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
        }
    }

    /// The base layer's rows, where a lens chord is written.
    private var defaultBindings: Binding<[KeyBinding]> {
        Binding(
            get: { model.config.layers.first?.bindings ?? [] },
            set: { rows in
                guard !model.config.layers.isEmpty else { return }
                model.config.layers[0].bindings = rows
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
        .accessibilityLabel(KiwiVisionLensWords.appliesTo)
        .accessibilityValue(label)
        .popover(item: $request, arrowEdge: .bottom) { _ in
            checklist(reached)
        }
    }

    private func checklist(_ reached: Set<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(
                L("app_rules.reach.all", "All profiles"),
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
