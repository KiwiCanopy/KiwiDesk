import KiwiDeskCore
import SwiftUI

/// The Pocket card's per-app keys (#2612): one row per app, each
/// with its own chord, and the picker that adds one. A row writes
/// exactly `PocketAppLuaArg.call`, kind `navigation`, so Core reads
/// it by the same shape.
struct PocketAppRows: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    @Environment(\.disabledSystemShortcuts)
    var disabledSystemShortcuts
    @Environment(\.keybindingLayerName)
    var layerName
    /// The app the last pick named that already has a key: WHICH
    /// app, never the sentence, which `takenNotice` derives live.
    @State private var refusal: String?

    var body: some View {
        ForEach(rowIDs, id: \.self) { id in
            if let binding = binding(id) {
                row(binding)
            }
        }
        addRow
    }

    /// Binding order: a new row lands at the bottom, as Open
    /// applications does, so a row never moves under the recorder.
    private var rowIDs: [UUID] {
        bindings.filter { Self.isPocketApp($0) }.map(\.id)
    }

    static func isPocketApp(_ binding: KeyBinding) -> Bool {
        PocketAppLuaArg.bundleID(of: binding.lua) != nil
    }

    private func row(_ binding: Binding<KeyBinding>) -> some View {
        let current = binding.wrappedValue
        let name = Self.name(current)
        return HStack {
            AppRuleIdentity(
                app: PocketAppLuaArg.bundleID(of: current.lua) ?? "",
                name: name
            )
            Spacer()
            KeyReachColumn(model: model, layer: layerName, binding: current)
            KeyRecorderField(
                // The recorder names its action, as an app row's does.
                name: PocketAppLuaArg.bundleID(of: current.lua).map {
                    KeybindingCatalog.pocketApp($0).resolvedLabel
                } ?? name,
                combo: current.combo,
                reading: ConflictText.reading(
                    for: current,
                    in: bindings,
                    config: model.config,
                    disabled: disabledSystemShortcuts,
                    sides: model.appWide.modifierSides
                ),
                preflight: { combo in
                    RecorderPreflight.rejection(
                        combo: combo,
                        excluding: { [id = current.id] in $0.id == id },
                        bindings: $bindings,
                        config: model.config,
                        commit: { record($0, id: current.id) }
                    )
                },
                onRecord: { record($0, id: current.id) },
                onClear: { binding.wrappedValue.combo = "" }
            )
            KeyReachTrash(model: model, layer: layerName, binding: current) {
                bindings.removeAll { $0.id == current.id }
            }
        }
        .id(current.id.uuidString)
    }

    /// The app's name, the one the row draws and speaks.
    static func name(_ binding: KeyBinding) -> String {
        PocketAppLuaArg.bundleID(of: binding.lua).map {
            KeybindingCatalog.displayName(forBundleID: $0)
        } ?? ""
    }

    /// The picker IS the add, as on Open applications (#1235); an
    /// app that already has a Pocket key is left out of its list.
    private var addRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            AppPickerButton(
                placeholder: Self.addLabel,
                selection: nil,
                onPick: { add($0.bundleID) },
                escapeLabel: L("shortcuts.other_ellipsis", "Other…"),
                onEscape: {
                    if let app = AppBundlePanel.pick() { add(app.bundleID) }
                },
                exclude: Set(KeybindingCatalog.pocketApps(in: bindings))
            )
            .fixedSize()
            .accessibilityLabel(Self.addLabel)
            .accessibilityValue(
                L("shortcuts.choose_app", "Choose app…")
            )
            // It explains the rows' trash, so it waits for a row.
            ForEach(captions, id: \.self) { caption in
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var captions: [String] {
        var lines: [String] = []
        if let takenNotice { lines.append(takenNotice) }
        if !rowIDs.isEmpty { lines.append(Self.help) }
        return lines
    }

    /// Why the last pick added nothing, asked of live state (#1235).
    private var takenNotice: String? {
        guard let refusal,
            KeybindingCatalog.pocketApps(in: bindings).contains(refusal)
        else { return nil }
        return Self.takenNotice(
            KeybindingCatalog.displayName(forBundleID: refusal)
        )
    }

    /// The "Other…" panel can name an app the list left out: it
    /// adds nothing a second time, and says so.
    private func add(_ bundleID: String) {
        let id = bundleID.lowercased()
        guard !KeybindingCatalog.pocketApps(in: bindings).contains(id)
        else {
            refusal = id
            let app = KeybindingCatalog.displayName(forBundleID: id)
            _ = DelayedAnnouncement.schedule(Self.takenNotice(app))
            return
        }
        refusal = nil
        bindings.append(KeybindingCatalog.pocketAppBinding(id))
    }

    static func takenNotice(_ app: String) -> String {
        L(
            "shortcuts.pocket_app.taken",
            "\u{201C}%1$@\u{201D} already has a Pocket key.",
            app
        )
    }

    private func record(_ combo: String, id: UUID) {
        guard let index = bindings.firstIndex(where: { $0.id == id })
        else { return }
        bindings[index].combo = combo
        model.noteRecordedCombo(bindings[index], in: bindings)
    }

    private func binding(_ id: UUID) -> Binding<KeyBinding>? {
        guard bindings.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: {
                bindings.first { $0.id == id }
                    ?? KeyBinding(kind: .navigation)
            },
            set: { new in
                if let index = bindings.firstIndex(where: { $0.id == id }) {
                    bindings[index] = new
                }
            }
        )
    }

    static var addLabel: String {
        L("shortcuts.pocket_app.add", "Add an app to your Pocket…")
    }

    static var help: String {
        L(
            "shortcuts.pocket_app.help",
            "Remove the app to make its window an ordinary window again."
        )
    }
}
