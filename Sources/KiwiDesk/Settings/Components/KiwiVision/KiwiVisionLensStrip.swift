import KiwiDeskCore
import SwiftUI

/// The chip strip atop Settings ▸ KiwiVision (#2103 rulings 29,
/// 48, 50, 54): Default, a thin rule, each lens, and `+`.
/// The selection parks on `nav`, which the side panel reads.
struct KiwiVisionLensStrip: View {
    @ObservedObject var model: SettingsModel
    @State private var adding: NameEditRequest?

    var body: some View {
        let lenses = model.draftLenses
        let selected = model.nav.kiwiVisionLensSelection(in: lenses)
        HStack(spacing: 6) {
            ShortcutLayerChip(
                name: KiwiVisionLensWords.defaultName,
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
        .onAppear(perform: takeAddRequest)
        .onChange(of: model.nav.kiwiVisionAddRequested) {
            takeAddRequest()
        }
    }

    /// KiwiHub's New Lens… lands here asking for the add popover
    /// (#2359 ruling 4): opened once, where the add is not greyed,
    /// a turn later so a page drawn this pass has its anchor.
    private func takeAddRequest() {
        guard model.nav.kiwiVisionAddRequested else { return }
        model.nav.kiwiVisionAddRequested = false
        guard addReason == nil else { return }
        DispatchQueue.main.async { openAdd() }
    }

    /// The add popover, as the `+` and a landing open it.
    private func openAdd() {
        adding = NameEditRequest(seed: "", subject: "")
    }

    private var addReason: String? {
        KiwiVisionGates(guiManaged: model.guiManaged)
            .inertReason(for: .kiwiVision(.lenses))
            .map(KiwiVisionGates.sentence(for:))
    }

    private var addChip: some View {
        Button(action: openAdd) {
            Image(systemName: "plus")
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .choiceChip(edged: false)
        }
        .buttonStyle(.plain)
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
            .settingsPopoverChrome()
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
            .choiceChip(selected: selected)
        }
        .buttonStyle(.plain)
        .help(empty ? KiwiVisionLensWords.noApps(name) : "")
        .accessibilityLabel(name)
        .accessibilityValue(empty ? KiwiVisionLensWords.noApps(name) : "")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
