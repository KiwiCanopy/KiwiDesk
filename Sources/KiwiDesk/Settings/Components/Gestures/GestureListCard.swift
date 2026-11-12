import KiwiDeskCore
import SwiftUI

/// One device's gesture list (#3199 ▸ Ruling): Natural scrolling
/// first, then a row per bound gesture, the seeds included as real
/// rows, then Add and Restore Defaults. Rows are sorted when the
/// card appears (gesture, then keys) and never re-sorted while
/// editing; a new row stays at the bottom until the page reopens.
struct GestureListCard: View {
    @ObservedObject var model: SettingsModel
    let device: GestureInput.Device
    /// The card's title and search anchor: the Natural scrolling
    /// row it leads with names the device.
    let control: SettingsControl
    let catalog: SequenceActionCatalog

    @State private var entries: [GestureListEntry] = []
    @State private var open: Set<UUID> = []
    /// Rows with no action yet, which the map does not hold.
    @State private var pending: Set<UUID> = []
    /// The row whose recorder arms as it appears.
    @State private var fresh: UUID?
    @State private var seeded = false

    private var offered: [GestureInput] {
        GestureListEdits.inputs(on: device)
    }

    var body: some View {
        SettingsSection(control, help: help) {
            VStack(alignment: .leading, spacing: 10) {
                naturalRow
                Divider()
                ForEach($entries) { $entry in
                    GestureListRow(
                        model: model,
                        entry: $entry,
                        others: entries.filter { $0.id != entry.id }
                            .map(\.key),
                        offered: offered,
                        catalog: catalog,
                        open: $open,
                        armsOnAppear: fresh == entry.id,
                        onUnbound: { pending.insert(entry.id) },
                        onRemove: { remove(entry) }
                    )
                }
                footer
            }
        }
        .onAppear(perform: snapshot)
        .onChange(of: model.config.gesture) { _, base in
            entries = GestureListEdits.reconcile(
                entries,
                pending: pending,
                in: base,
                on: device
            )
            // A row that took an action is the map's from here on.
            pending = pending.filter { id in
                entries.first { $0.id == id }.map {
                    GestureListEdits.action(of: $0.key, in: base) == nil
                } ?? false
            }
        }
    }

    /// Apple's own name over System · On · Off (#3200), with the
    /// value's "Applies to" checklist trailing.
    private var naturalRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            naturalPicker
            Spacer(minLength: 8)
            naturalReach
        }
    }

    @ViewBuilder private var naturalReach: some View {
        let field: ScrollGestureField =
            device == .mouse ? .naturalMouse : .naturalTrackpad
        if model.offersReachColumn,
            let reading = model.scrollReach(field.rawValue)
        {
            RuleReachControl(
                model: model,
                family: .scroll,
                app: field.rawValue,
                subject: ScrollGestureWords.label(field),
                reading: reading,
                value: ScrollGestureWords.value(
                    field.value(in: model.config.scrollGesture)
                )
            )
        }
    }

    private var naturalPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            SegmentedPicker(
                ScrollGestureWords.natural,
                spokenLabel: L(
                    "shortcuts.gestures.scroll.natural_spoken",
                    "%1$@, %2$@",
                    GestureListWords.device(device),
                    ScrollGestureWords.natural
                ),
                hugsLabels: true,
                selection: natural,
                options: NaturalScrolling.allCases.map {
                    (ScrollGestureWords.natural($0), $0)
                }
            )
            if device == .trackpad {
                Text(GestureListWords.magicMouseCaption)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink3)
            }
        }
    }

    private var natural: Binding<NaturalScrolling> {
        switch device {
        case .mouse: $model.config.scrollGesture.naturalMouse
        case .trackpad: $model.config.scrollGesture.naturalTrackpad
        }
    }

    private var footer: some View {
        HStack {
            Button(action: add) {
                Label(GestureListWords.add, systemImage: "plus")
            }
            .settingsActionButton()
            Spacer()
            Button(GestureListWords.restoreDefaults, action: restore)
                .settingsActionButton()
                .disabled(
                    !GestureListEdits.differsFromDefaults(
                        on: device,
                        in: model.config.gesture
                    )
                )
        }
        .padding(.top, 4)
    }

    private var help: String {
        switch device {
        case .mouse:
            L(
                "shortcuts.gestures.list.mouse_help",
                "Bind a drag, a move or a scroll with keys held to an "
                    + "action. With one action for every direction, a "
                    + "scroll steps as far as you scroll; give one "
                    + "direction its own action and each direction acts "
                    + "once per scroll instead."
            )
        case .trackpad:
            L(
                "shortcuts.gestures.list.trackpad_help",
                "Bind a tap or a swipe to an action; a tap may take "
                    + "no keys. With one action for every direction, a "
                    + "swipe slides with your fingers and steps as far "
                    + "as you swipe; give one direction its own action "
                    + "and each direction acts once per swipe instead."
            )
        }
    }

    // MARK: - Rows

    /// The rows as the map binds them; mixed rows open, the rest
    /// closed (#3199 ▸ Ruling).
    private func snapshot() {
        guard !seeded else { return }
        seeded = true
        reload()
    }

    private func reload() {
        entries = GestureListEdits.rows(in: model.config.gesture, on: device)
            .map { GestureListEntry($0) }
        open = Set(
            entries.filter {
                if case .split = GestureListEdits.action(
                    of: $0.key,
                    in: model.config.gesture
                ) {
                    return true
                }
                return false
            }
            .map(\.id)
        )
        fresh = nil
        pending = []
    }

    /// A new row suggests the last gesture and arms its recorder.
    private func add() {
        let last = entries.last?.key.input
        let candidates = (last.map { [$0] } ?? []) + offered
        guard
            let key = candidates.map({ GestureKey($0) }).first(where: {
                key in !entries.contains { $0.key == key }
            })
        else { return }
        let entry = GestureListEntry(key)
        entries.append(entry)
        pending.insert(entry.id)
        fresh = entry.id
    }

    private func remove(_ entry: GestureListEntry) {
        if GestureListEdits.action(of: entry.key, in: model.config.gesture)
            != nil
        {
            GestureListEdits.remove(entry.key, in: &model.config.gesture)
        }
        entries.removeAll { $0.id == entry.id }
        open.remove(entry.id)
        pending.remove(entry.id)
    }

    private func restore() {
        GestureListEdits.restoreDefaults(
            on: device,
            in: &model.config.gesture
        )
        reload()
    }
}
