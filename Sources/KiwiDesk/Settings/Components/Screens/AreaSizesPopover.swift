import Foundation
import KiwiDeskCore
import SwiftUI

/// Adjust… (#3517 ruling 26): one field per member of the run the
/// selection sits in (#3541), in points or percent. A commit —
/// Return, Tab or leaving a field — writes the typed member and the
/// one giving way, clamped by Core; Escape restores the sizes it
/// opened on.
struct AreaSizesPopover: View {
    @ObservedObject var model: SettingsModel
    let display: Display
    let request: AreaSizesRequest
    /// The areas giving way, which their panes wear too.
    @Binding var givingWay: Set<ScreenSelection>
    /// Whether it types in percent: held by the Screens page, so a
    /// switch lasts while Settings stays open and is never stored.
    @Binding var percent: Bool
    let dismiss: () -> Void
    @State private var typed: [Int] = []
    @State private var drafts: [Int: String] = [:]
    @FocusState private var focus: Int?

    private var split: ScreenSplit {
        model.areaSplit(of: display) ?? request.seed
    }

    /// The run the selection sits in; empty where the split went.
    private var run: ScreenAreaRun? { split.run(holding: request.area) }

    /// The run's members, by index in reading order.
    private var order: [Int] { run.map { Array($0.members.indices) } ?? [] }

    private var rest: Int? {
        AreaGiveWay.pick(order: order, typed: typed, excluding: focus)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SettingsGroupHeading(
                    title: L("monitors.sizes.title", "Area sizes")
                )
                Spacer()
                SegmentedPicker(
                    spokenLabel: L("slot_size.unit", "Size unit"),
                    selection: $percent,
                    options: [
                        (L("slot_size.points", "Points"), false),
                        (L("slot_size.percent", "Percent"), true),
                    ]
                )
                .fixedSize()
            }
            Grid(alignment: .leading, horizontalSpacing: 8) {
                ForEach(order, id: \.self) { id in
                    fieldRow(id)
                }
            }
        }
        .padding(12)
        .frame(width: 300)
        .onAppear { publishRest() }
        .onChange(of: focus) { old, _ in
            if let old { commit(old) }
            publishRest()
        }
        // A draft typed in the other unit is not this unit's number.
        .onChange(of: percent) { drafts = [:] }
        // A size that lines two segments up can re-root the walk, so
        // the run's members change: the typing order no longer names
        // them (#3541).
        .onChange(of: run?.members.map(\.areas)) {
            typed = []
            drafts = [:]
            focus = nil
        }
        .onExitCommand(perform: cancel)
        .onDisappear { givingWay = [] }
    }

    @ViewBuilder private func fieldRow(_ id: Int) -> some View {
        let label = model.memberLabel(id, of: run, on: display)
        let gives = rest == id
        GridRow {
            Text(label)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 120, alignment: .leading)
            TextField("", text: text(for: id))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 72)
                .foregroundStyle(
                    gives ? SettingsTheme.ink2 : SettingsTheme.ink
                )
                .focused($focus, equals: id)
                .onSubmit {
                    commit(id)
                    dismiss()
                }
                .accessibilityLabel(spokenName(label))
                .accessibilityValue(spokenValue(id, gives: gives))
            Text(
                percent
                    ? L("layout_defaults.maximize.custom.percent", "%")
                    : L("layout_defaults.maximize.custom.points", "pt")
            )
            .foregroundStyle(SettingsTheme.ink2)
            // Reserved on every row, so the mark moving shifts nothing.
            Text(L("monitors.sizes.rest", "the rest"))
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink2)
                .opacity(gives ? 1 : 0)
                .accessibilityHidden(true)
        }
    }

    private func shown(_ index: Int) -> Int {
        guard let run, run.members.indices.contains(index) else {
            return 0
        }
        return percent ? run.percents[index] : run.lengths[index]
    }

    private func text(for id: Int) -> Binding<String> {
        Binding(
            get: { drafts[id] ?? "\(shown(id))" },
            set: { drafts[id] = $0 }
        )
    }

    /// Writes field `id`, if it was typed: Core sets it and the area
    /// giving way, clamped at the floor, and the change is spoken.
    private func commit(_ id: Int) {
        guard let raw = drafts.removeValue(forKey: id),
            let number = Double(raw.trimmingCharacters(in: .whitespaces)),
            let other = AreaGiveWay.pick(
                order: order,
                typed: typed,
                excluding: id
            ),
            let run
        else { return }
        let asked =
            percent
            ? run.points(percent: number) : Int(number.rounded())
        guard asked != shown(id) || percent,
            let set = split.setting(
                member: id,
                of: run,
                to: asked,
                givingWay: other,
                floor: model.areaFloor(run.axis)
            )
        else { return }
        model.writeAreaSplit(set.split, on: display)
        typed = AreaGiveWay.typing(id, after: typed)
        announce(
            id,
            set.split,
            run: run,
            clamped: set.length != asked,
            other: other
        )
    }

    private func cancel() {
        model.writeAreaSplit(request.seed, on: display)
        typed = []
        drafts = [:]
        dismiss()
    }

    private func publishRest() {
        let areas =
            rest.flatMap { index in
                run.flatMap {
                    $0.members.indices.contains(index)
                        ? $0.members[index].areas : nil
                }
            } ?? []
        givingWay = Set(
            areas.map { ScreenSelection(display: display.id, area: $0) }
        )
    }

    private func announce(
        _ id: Int,
        _ split: ScreenSplit,
        run: ScreenAreaRun,
        clamped: Bool,
        other: Int
    ) {
        func length(_ member: Int) -> Int {
            split.memberLength(run.members[member], along: run.axis)
        }
        func name(_ member: Int) -> String {
            model.memberLabel(member, of: run, on: display)
        }
        // A clamp moved the typed area too, so it is said first.
        let spoken =
            clamped
            ? L(
                "monitors.sizes.now_pair.ax",
                "%1$@ is now %2$d points, %3$@ is now %4$d points",
                name(id),
                length(id),
                name(other),
                length(other)
            )
            : L(
                "monitors.sizes.now.ax",
                "%1$@ is now %2$d points",
                name(other),
                length(other)
            )
        AccessibilityNotification.Announcement(spoken).post()
    }

    private func points(_ length: Int) -> String {
        L("layout_defaults.maximize.points.ax", "%1$@ points", "\(length)")
    }

    private func spokenName(_ label: String) -> String {
        run?.axis == .stacked
            ? L("monitors.sizes.height.ax", "%1$@ height", label)
            : L("monitors.sizes.width.ax", "%1$@ width", label)
    }

    private func spokenValue(_ id: Int, gives: Bool) -> String {
        let value =
            percent
            ? L("monitors.sizes.percent.ax", "%1$d percent", shown(id))
            : points(shown(id))
        return gives
            ? L("monitors.sizes.rest.ax", "%1$@, the rest", value)
            : value
    }
}
