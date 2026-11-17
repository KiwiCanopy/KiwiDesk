import KiwiDeskCore
import SwiftUI

/// One node of a key sequence's outline (#1871 ▸ Settings; #3162 ▸
/// Ruling): the leader, with its name, reach, recorder and trash;
/// every other key one line — its recorder, then one container
/// saying what it does, then its remove. A command or an app on the
/// plain pop-up face, a Lua key's description dashed, a key that
/// opens more keys tinted with its name. An open branch draws its
/// keys one 18 pt step in, a 1 pt rail centred in that step running
/// down to its "Add Key"; past `indentCap` its keys list flat under
/// a caption naming the path (#3425 ▸ Ruling).
struct SequenceNodeRow: View {
    @ObservedObject var model: SettingsModel
    let editing: SequenceEditing
    let node: KeyBinding
    /// The stored chords from the leader down to this node.
    let path: [String]
    let catalog: SequenceActionCatalog
    @Binding var collapsed: Set<UUID>
    /// The node just added, whose recorder arms on arrival.
    @Binding var fresh: UUID?
    @Environment(\.systemShortcutState)
    var systemShortcutState
    @State private var confirmingDelete = false
    @State var editingLua: LuaEditRequest?
    @State var editingBranch: SequenceBranchRequest?
    @State var picking: SequencePickRequest?
    /// "App…" swapped the app list in for the action picker.
    @State private var choosingApp = false
    @Environment(\.keybindingLayerName) var layerName

    var isLeader: Bool { node.id == editing.rootID }
    var isOpen: Bool { !collapsed.contains(node.id) }
    var name: String {
        SequenceNames.name(of: node, catalog: catalog, config: model.config)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ShortcutKeyRow(spacing: 8) {
                if isLeader { leaderLine } else { keyLine }
            }
            if node.isSequence, node.steps?.isEmpty ?? true {
                Text(L("shortcuts.sequence.empty", "Does nothing yet"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, SettingsMetrics.shortcutTextIndent)
            }
            if node.isSequence, isOpen { keys }
        }
        .id(node.id.uuidString)
        // A well armed once: rebuilt later, it waits for a click.
        .onDisappear { if fresh == node.id { fresh = nil } }
        .confirmationDialog(
            L(
                "shortcuts.sequence.delete_title",
                "Remove \u{201C}%1$@\u{201D} and every key under it?",
                name
            ),
            isPresented: $confirmingDelete
        ) {
            Button(
                L("shortcuts.sequence.delete_confirm", "Remove"),
                role: .destructive
            ) { editing.remove(node.id) }
        }
    }

    // MARK: - Lines

    /// The leader in the step keys' order (#3381 ▸ c2, amended by
    /// #3425): its fold, its chord one step left of its keys', its
    /// pill, then the sequence's reach and trash, as a shortcut
    /// row's (#3124).
    @ViewBuilder private var leaderLine: some View {
        disclosure(width: Self.foldSlot)
        recorder.fixedSize().layoutPriority(1)
        branchContainer
        Spacer(minLength: 8)
        // Sized ahead of the pill, whose title alone gives way.
        KeyReachColumn(model: model, layer: layerName, binding: node)
            .layoutPriority(1)
        KeyReachTrash(
            model: model,
            layer: layerName,
            binding: node
        ) { requestDelete() }
    }

    /// The fold, the key, its one container, then remove (#3162 ▸
    /// Ruling; #3241): the fold sits outside a branch's container,
    /// and every other key keeps its slot so the keys line up.
    @ViewBuilder private var keyLine: some View {
        if node.isSequence {
            disclosure(width: Self.foldSlot)
                .font(.caption.weight(.semibold))
        } else {
            Color.clear.frame(width: Self.foldSlot, height: 1)
                .accessibilityHidden(true)
        }
        recorder.fixedSize().layoutPriority(1)
        if node.isSequence { branchContainer } else { endKeyContainer }
        Spacer(minLength: 8)
        AppRuleDeleteButton(
            help: L("shortcuts.sequence.remove", "Remove key"),
            sharedFrom: nil
        ) { _ in requestDelete() }
    }

    /// Every line's fold slot, the leader's included, and so the
    /// step each level indents by (#3425): one icon slot, 18 pt.
    static let foldSlot = SettingsMetrics.shortcutIconSlot

    /// An open branch's rail, drawn centred in its keys' step and
    /// adding no width of its own (#3425).
    static let railWidth: CGFloat = 1

    /// The deepest level that still indents (#3425): keys deeper
    /// list flat in its column.
    static let indentCap = 4

    /// The fold, its own button so it never shares the name's click
    /// (#3162 ▸ Ruling amendment).
    func disclosure(width: CGFloat) -> some View {
        Button {
            if isOpen {
                collapsed.insert(node.id)
            } else {
                collapsed.remove(node.id)
            }
        } label: {
            Image(systemName: "chevron.right")
                .rotationEffect(.degrees(isOpen ? 90 : 0))
                .frame(width: width)
                .contentShape(Rectangle())
        }
        // Plain, not borderless: an AppKit-backed button clips the
        // tinted container it sits in (#3162).
        .buttonStyle(.plain)
        .foregroundStyle(SettingsTheme.ink2)
        .accessibilityLabel(name)
        .accessibilityValue(
            isOpen
                ? L("settings.disclosure.ax_expanded", "expanded")
                : L("settings.disclosure.ax_collapsed", "collapsed")
        )
    }

    @ViewBuilder private var endKeyContainer: some View {
        if choosingApp {
            AppPickerButton(
                placeholder: L("shortcuts.choose_app", "Choose app…"),
                selection: node.kind == .application ? name : nil,
                onPick: pickApp,
                escapeLabel: L("shortcuts.other_ellipsis", "Other…"),
                onEscape: {
                    if let app = AppBundlePanel.pick() { pickApp(app) }
                },
                opensOnAppear: true,
                onClose: { choosingApp = false }
            )
            .fixedSize()
            .accessibilityLabel(actionLabel)
        } else {
            actionMenu
        }
    }

    private var actionMenu: some View {
        SequenceActionMenu(
            face: SequencePickFace(node),
            catalog: catalog,
            spokenLabel: actionLabel,
            pins: [
                SequencePickPin(
                    id: "branch",
                    title: SequenceActionMenu.branchLabel,
                    symbol: "plus"
                ) {
                    // A named branch and an armed child well (#1871).
                    let key = SequenceTree.newEndKey()
                    editing.update(node.id) {
                        $0 = SequenceTree.branch($0)
                        $0.steps = [key]
                    }
                    collapsed.remove(node.id)
                    fresh = key.id
                }
            ],
            marksKind: true,
            onPick: { command in
                editing.update(node.id) {
                    $0 = SequenceTree.endKey($0, running: command)
                }
            },
            onApp: { choosingApp = true },
            onLua: {
                editing.update(node.id) { $0 = SequenceTree.luaKey($0) }
                editingLua = LuaEditRequest(id: node.id)
            },
            onEditLua: { editingLua = LuaEditRequest(id: node.id) },
            request: $picking
        )
        .popover(item: $editingLua) { _ in
            luaPopover.settingsPopoverChrome()
        }
    }

    private func pickApp(_ app: KeybindingCatalog.InstalledApp) {
        editing.update(node.id) {
            $0 = SequenceTree.appKey(
                $0,
                bundleID: app.bundleID,
                name: app.name
            )
        }
    }

    // MARK: - Keys under a branch

    /// Whether this branch's keys sit past `indentCap`, flat in its
    /// own column under the path caption.
    private var keysFlat: Bool { path.count - 1 >= Self.indentCap }

    private var keys: some View {
        HStack(alignment: .top, spacing: 0) {
            if !keysFlat {
                Color.clear
                    .frame(width: Self.foldSlot)
                    .overlay {
                        SettingsTheme.hairlineSubtle
                            .frame(width: Self.railWidth)
                    }
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 6) {
                if keysFlat { flatCaption }
                ForEach(node.steps ?? []) { step in
                    SequenceNodeRow(
                        model: model,
                        editing: editing,
                        node: step,
                        path: path + [step.combo],
                        catalog: catalog,
                        collapsed: $collapsed,
                        fresh: $fresh
                    )
                }
                Button {
                    let key = SequenceTree.newEndKey()
                    editing.edit {
                        SequenceTree.appending(key, to: node.id, in: $0)
                    }
                    fresh = key.id
                } label: {
                    Label(
                        L("shortcuts.sequence.add_key", "Add Key"),
                        systemImage: "plus"
                    )
                }
                .settingsActionButton()
                .accessibilityHint(name)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(name)
    }

    /// A flat branch's first line, at its keys' chord column: the
    /// path shortened, read whole on hover and by VoiceOver (#3425).
    private var flatCaption: some View {
        Text(SequencePathWords.shortened(path))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.leading, SettingsMetrics.shortcutTextIndent)
            .help(SequencePathWords.spoken(path))
            .accessibilityLabel(SequencePathWords.spoken(path))
    }

    private func requestDelete() {
        if node.isSequence, !(node.steps?.isEmpty ?? true) {
            confirmingDelete = true
        } else {
            editing.remove(node.id)
        }
    }
}
