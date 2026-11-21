import KiwiDeskCore
import SwiftUI

/// The edited layer's keys that run an Apple Shortcut (#3526), a
/// collapsible card after Open applications. Shut with a summary
/// until a key exists, then open on arrival, as Key sequences is;
/// never swapped for another container (#1125). A row's shortcut is
/// fixed once added, as an app row's app is (#2708).
struct AppleShortcutsCard: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    @Environment(\.systemShortcutState)
    var systemShortcutState
    @Environment(\.keybindingLayerName)
    var layerName
    @ObservedObject private var library = AppleShortcutLibrary.shared
    @State private var expanded = false
    /// Alphabetical order snapshotted on arrival, as the app rows'
    /// (#333): a live re-sort could move a row mid-record.
    @State private var displayOrder: [UUID] = []

    private var shortcuts: [KeyBinding] {
        bindings.filter(AppleShortcutAction.isRow)
    }

    var body: some View {
        SettingsCollapsibleSection(
            SettingsCatalog.shortcuts.appleShortcutsCard,
            isExpanded: $expanded,
            summary: summary,
            help: AppleShortcutAction.conflictBlindSpot
        ) {
            VStack(alignment: .leading, spacing: 8) {
                if shortcuts.isEmpty {
                    Text(Self.empty)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(ordered) { binding in
                    row(binding)
                }
                AppleShortcutPickerButton(
                    core: model.core,
                    selection: nil,
                    onPick: {
                        bindings.append(AppleShortcutAction.binding($0))
                    }
                )
                .fixedSize()
                .accessibilityLabel(
                    L("shortcuts.apple_shortcut.add", "Add Apple Shortcut")
                )
            }
        }
        // Open on arrival once in use — never forced shut.
        .onAppear {
            recomputeOrder()
            if !shortcuts.isEmpty { expanded = true }
        }
        .onChange(of: shortcuts.isEmpty) { _, empty in
            if !empty { expanded = true }
        }
        .onChange(of: layerName) { _, _ in recomputeOrder() }
        .task(id: shortcuts.isEmpty) {
            if !shortcuts.isEmpty {
                await library.reload(from: model.core)
            }
        }
    }

    /// Snapshot order, new rows after it.
    private var ordered: [KeyBinding] {
        let known = displayOrder.compactMap { id in
            shortcuts.first { $0.id == id }
        }
        let seen = Set(known.map(\.id))
        return known + shortcuts.filter { !seen.contains($0.id) }
    }

    private func recomputeOrder() {
        displayOrder = shortcuts.sorted {
            name(of: $0).localizedCaseInsensitiveCompare(name(of: $1))
                == .orderedAscending
        }
        .map(\.id)
    }

    private func name(of binding: KeyBinding) -> String {
        AppleShortcutAction.name(from: binding.lua) ?? binding.label
    }

    private func row(_ binding: KeyBinding) -> some View {
        let name = name(of: binding)
        return VStack(alignment: .leading, spacing: 4) {
            ShortcutKeyRow {
                HStack(spacing: 6) {
                    AppleShortcutMark(name: name)
                        .frame(width: SettingsMetrics.shortcutIconSlot)
                    Text(name).lineLimit(1)
                }
                Spacer()
                KeyReachColumn(
                    model: model,
                    layer: layerName,
                    binding: binding
                )
                recorder(binding, name: name)
                KeyReachTrash(
                    model: model,
                    layer: layerName,
                    binding: binding
                ) { remove(binding.id) }
            }
            if library.isMissing(name) {
                missingLine(name)
            }
        }
        .id(binding.id.uuidString)
    }

    /// Why the row does nothing, drawn, not hover text alone.
    private func missingLine(_ name: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(SettingsTheme.warningInk)
                .accessibilityHidden(true)
            Text(AppleShortcutMark.missing(name))
                .foregroundStyle(SettingsTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
        .padding(.leading, SettingsMetrics.shortcutTextIndent)
    }

    private func recorder(_ binding: KeyBinding, name: String) -> some View {
        KeyRecorderField(
            name: name,
            combo: binding.combo,
            reading: ConflictText.reading(
                for: binding,
                in: bindings,
                config: model.config,
                system: systemShortcutState,
                sides: model.appWide.modifierSides
            ),
            narrowing: SideNarrowing.of(
                binding,
                in: bindings,
                config: model.config,
                sides: model.appWide.modifierSides
            ),
            preflight: { combo in
                RecorderPreflight.rejection(
                    combo: combo,
                    excluding: { [id = binding.id] in $0.id == id },
                    bindings: $bindings,
                    config: model.config,
                    commit: { record($0, id: binding.id) }
                )
            },
            onRecord: { record($0, id: binding.id) },
            onClear: { record("", id: binding.id) }
        )
    }

    private func record(_ combo: String, id: UUID) {
        guard let index = bindings.firstIndex(where: { $0.id == id })
        else { return }
        bindings[index].combo = combo
        guard !combo.isEmpty else { return }
        model.noteRecordedCombo(bindings[index], in: bindings)
    }

    private func remove(_ id: UUID) {
        bindings.removeAll { $0.id == id }
    }

    /// The shortcuts by name once one has a key, or what the card is.
    private var summary: String {
        guard !shortcuts.isEmpty else {
            return L(
                "shortcuts.apple_shortcut.summary",
                "Run a shortcut from the Shortcuts app with a key"
            )
        }
        return LocalizedList.join(ordered.map(name(of:)))
    }

    static var empty: String {
        L(
            "shortcuts.apple_shortcut.empty",
            "No shortcut from the Shortcuts app has a key yet. Choose "
                + "one and give it a key."
        )
    }
}
