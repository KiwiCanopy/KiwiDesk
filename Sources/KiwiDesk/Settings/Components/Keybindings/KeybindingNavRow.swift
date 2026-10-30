import KiwiDeskCore
import SwiftUI

/// Single navigation shortcut row with label and recorder field
/// (#34, #68 §3.6.2).
///
/// It observes nothing: its parent, which observes the model,
/// builds it in every render, and its body draws only `drawn`, read
/// at init, which is what it compares by — so a draft write that
/// leaves the row as it was skips it whole (#2783). A parent draws
/// it `.equatable()` and hands it the layer and the disabled set
/// from its own environment. Its actions read the draft when
/// called, through a binding that must find its rows when called
/// rather than capture where they were: a skipped render keeps the
/// binding of the last one that drew.
struct NavRow: View, Equatable {
    let model: SettingsModel
    /// The layer's rows, out of SwiftUI's sight: a `Binding` the
    /// view stored would re-render the row on every write to any of
    /// them (#2783).
    private let rows: Rows
    let command: NavCommand
    let layerName: String
    @Environment(\.keybindingReservesTrashSlot)
    private var reservesTrashSlot
    /// A clear of a shortcut other profiles share asks where it
    /// goes, as the trash does (#1393).
    @State private var confirmingClear = false
    let drawn: Drawn

    /// Everything the body draws; equal values draw the same row.
    struct Drawn: Equatable {
        let title: String
        let help: String?
        let icon: String?
        let unavailable: String?
        let liveOnly: LiveOnlySpace.Kind?
        let isPocket: Bool
        let binding: KeyBinding?
        let reach: KeyReachColumn?
        let reading: ConflictReading?
    }

    init(
        model: SettingsModel,
        bindings: Binding<[KeyBinding]>,
        command: NavCommand,
        layer: String,
        disabled: Set<SystemShortcut>
    ) {
        self.model = model
        rows = Rows(binding: bindings)
        self.command = command
        layerName = layer
        let rows = bindings.wrappedValue
        let index = Self.index(of: command, in: rows)
        let binding = index.map { rows[$0] }
        drawn = Drawn(
            title: command.resolvedLabel,
            help: command.help?(),
            icon: ShortcutsReferenceBuilder.icon(for: command),
            unavailable: command.unavailable?(),
            liveOnly: command.liveOnly,
            isPocket: command.lua == KeybindingCatalog.pocket.lua,
            binding: binding,
            reach: binding.flatMap { binding in
                KeyReachColumn.reading(
                    model: model,
                    layer: layer,
                    binding: binding
                ).map {
                    KeyReachColumn(
                        model: model,
                        layer: layer,
                        binding: binding,
                        reading: $0
                    )
                }
            },
            reading: Self.reading(
                at: index,
                in: rows,
                model: model,
                disabledSystemShortcuts: disabled
            )
        )
    }

    /// A plain box: SwiftUI reads no dynamic property inside it.
    private struct Rows {
        let binding: Binding<[KeyBinding]>
    }

    nonisolated static func == (a: Self, b: Self) -> Bool {
        a.command.lua == b.command.lua && a.layerName == b.layerName
            && a.drawn == b.drawn
    }

    var body: some View {
        HStack {
            // Icon slot reserved unconditionally (#264); the
            // panel's glyph (#2670).
            Color.clear
                .frame(width: SettingsMetrics.shortcutIconSlot)
                .overlay {
                    if drawn.isPocket {
                        // The mark itself, as the panel draws it.
                        Image(
                            nsImage: PocketMark.mark.image(size: 16, hex: "")
                        )
                        .frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                    } else if let glyph = drawn.icon {
                        IconGlyphLabel(icon: glyph)
                    }
                }
            Text(drawn.title)
            if let kind = drawn.liveOnly {
                LiveOnlySpaceChip(kind: kind)
            }
            if let help = drawn.help {
                HelpButton(explanation: help, subject: drawn.title)
            }
            Spacer()
            if let reach = drawn.reach {
                reach
            }
            KeyRecorderField(
                name: drawn.title,
                combo: drawn.binding?.combo ?? "",
                reading: drawn.reading,
                preflight: preflight,
                onRecord: record,
                onClear: clear
            )
            if reservesTrashSlot {
                AppRuleDeleteButton.slot
            }
        }
        .keybindingRowStyle(unavailable: drawn.unavailable)
        .confirmationDialog(
            L(
                "shortcuts.clear_shared.title",
                "Other profiles use this shortcut too."
            ),
            isPresented: $confirmingClear
        ) {
            // Read only while asked, never in every row's render.
            if confirmingClear, let reading = sharedFrom {
                Button(RuleReachWords.removeHere(reading)) { clear(.here) }
                Button(RuleReachWords.removeEverywhere(reading)) {
                    clear(.everywhere)
                }
            }
        }
        .id(command.lua)
    }

    private var bindings: [KeyBinding] {
        get { rows.binding.wrappedValue }
        nonmutating set { rows.binding.wrappedValue = newValue }
    }

    private var index: Int? { Self.index(of: command, in: bindings) }

    private static func index(
        of command: NavCommand,
        in bindings: [KeyBinding]
    ) -> Int? {
        bindings.firstIndex {
            $0.kind == .navigation && command.runs($0.lua)
        }
    }

    private static func reading(
        at index: Int?,
        in bindings: [KeyBinding],
        model: SettingsModel,
        disabledSystemShortcuts: Set<SystemShortcut>
    ) -> ConflictReading? {
        guard let index else { return nil }
        return ConflictText.reading(
            for: bindings[index],
            in: bindings,
            config: model.config,
            disabled: disabledSystemShortcuts,
            sides: model.appWide.modifierSides
        )
    }

    private func preflight(
        _ combo: String
    ) -> RecorderRejection? {
        RecorderPreflight.rejection(
            combo: combo,
            excluding: { [command] in
                $0.kind == .navigation && command.runs($0.lua)
            },
            bindings: rows.binding,
            config: model.config,
            commit: { record($0) }
        )
    }

    private func record(
        _ combo: String
    ) {
        if let index {
            bindings[index].combo = combo
        } else {
            bindings.append(
                KeyBinding(
                    combo: combo,
                    lua: command.lua,
                    kind: .navigation,
                    label: command.label
                )
            )
        }
        if let updated = bindings.first(where: {
            $0.kind == .navigation && command.runs($0.lua)
        }) {
            model.noteRecordedCombo(updated, in: bindings)
        }
    }

    /// The edited profile, where another profile shares this row.
    private var sharedFrom: RuleReachReading? {
        guard model.offersReachColumn, let index,
            let reading = model.keyReach(
                RuleReachTable<String>.keyID(
                    layer: layerName,
                    lua: bindings[index].lua
                )
            ),
            reading.users.count > 1
        else { return nil }
        return reading
    }

    private func clear() {
        if sharedFrom != nil {
            confirmingClear = true
        } else {
            clear(.everywhere)
        }
    }

    private func clear(_ removal: RuleRemoval) {
        guard let index else { return }
        model.recordRemoval(
            .key,
            RuleReachTable<String>.keyID(
                layer: layerName,
                lua: bindings[index].lua
            ),
            removal
        )
        bindings.remove(at: index)
    }
}
