import KiwiDeskCore
import SwiftUI

/// The chip strip atop Settings ▸ KiwiVision (#2103 rulings 29,
/// 48, 50, 54): Focused window, a thin rule, each lens, and `+`.
/// The selection parks on `nav`, which the side panel reads.
struct KiwiVisionLensStrip: View {
    @ObservedObject var model: SettingsModel
    @State private var adding: NameEditRequest?
    @State private var addHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let lenses = model.draftLenses
        let selected = model.nav.kiwiVisionLensSelection(in: lenses)
        HStack(spacing: 6) {
            ShortcutLayerChip(
                name: KiwiVisionLensWords.focusedWindow,
                selected: selected == nil
            ) { model.nav.kiwiVisionLens = nil }
            Rectangle()
                .fill(SettingsTheme.hairline)
                .frame(width: 1, height: 16)
                .padding(.horizontal, 2)
                .accessibilityHidden(true)
            ForEach(lenses, id: \.name) { lens in
                KiwiVisionLensChip(
                    name: lens.name,
                    empty: lens.apps.isEmpty,
                    selected: selected == lens.name
                ) { model.nav.kiwiVisionLens = lens.name }
            }
            addChip
        }
        .searchAnchored(SettingsCatalog.kiwiVision.lenses)
        .help(KiwiVisionLensWords.lensesHelp)
    }

    private var addReason: String? {
        KiwiVisionGates(guiManaged: model.guiManaged)
            .inertReason(for: .kiwiVision(.lenses))
            .map(KiwiVisionGates.sentence(for:))
    }

    private var addChip: some View {
        Button {
            adding = NameEditRequest(seed: "", subject: "")
        } label: {
            Image(systemName: "plus")
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .choiceChip(hovering: isEnabled && addHovered, edged: false)
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.12),
                    value: addHovered
                )
        }
        .buttonStyle(.plain)
        .onHover { addHovered = isEnabled && $0 }
        // A Lua-owned setup defines its lenses in init.lua; the
        // chips stay live, the add greys with its reason.
        .disabled(addReason != nil)
        .help(addReason ?? KiwiVisionLensWords.newLens)
        .accessibilityLabel(KiwiVisionLensWords.newLens)
        .accessibilityHint(addReason ?? "")
        .popover(item: $adding, arrowEdge: .bottom) { request in
            NameEditPopover(
                seed: request.seed,
                placeholder: KiwiVisionLensWords.lensName,
                confirmLabel: { _ in KiwiVisionLensWords.add },
                isValid: { model.lensNameRefusal($0) == nil },
                problem: {
                    model.lensNameRefusal($0)
                        .flatMap(KiwiVisionLensWords.refusal)
                }
            ) { typed in
                guard model.addLens(named: typed) == nil else { return }
                adding = nil
                model.nav.kiwiVisionLens = AppWideSettings.lensName(typed)
            }
        }
    }
}

/// A lens's chip: an empty lens stays a live button — the page is
/// where it is filled — greyed by its lighter label and a leading
/// dashed circle, never by hue alone (ruling 50).
struct KiwiVisionLensChip: View {
    let name: String
    let empty: Bool
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if empty {
                    Image(systemName: "circle.dashed")
                        .font(.caption)
                        .accessibilityHidden(true)
                }
                Text(name).lineLimit(1)
            }
            .font(.callout)
            .foregroundStyle(empty ? SettingsTheme.ink2 : SettingsTheme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .choiceChip(selected: selected, hovering: hovering && isEnabled)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: hovering
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = isEnabled && $0 }
        .onChange(of: isEnabled) { _, now in
            if !now { hovering = false }
        }
        .help(empty ? KiwiVisionLensWords.noApps(name) : "")
        .accessibilityLabel(name)
        .accessibilityValue(empty ? KiwiVisionLensWords.noApps(name) : "")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
