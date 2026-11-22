import Foundation
import KiwiDeskCore
import SwiftUI

/// Adjust… (#3517 ruling 26): one field per area of a split screen,
/// in points or percent. A commit — Return, Tab or leaving a field —
/// writes the typed area and the one giving way, clamped by Core;
/// Escape restores the sizes it opened on.
struct AreaSizesPopover: View {
    @ObservedObject var model: SettingsModel
    let display: Display
    let request: AreaSizesRequest
    /// The area giving way, which its pane wears too.
    @Binding var givingWay: ScreenSelection?
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

    private var order: [Int] {
        ScreenArea.readingOrder(split.areas).map(\.id)
    }

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
        .onExitCommand(perform: cancel)
        .onDisappear { givingWay = nil }
    }

    @ViewBuilder private func fieldRow(_ id: Int) -> some View {
        let label = model.areaLabel(id, on: display) ?? ""
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

    private func shown(_ id: Int) -> Int {
        guard let index = order.firstIndex(of: id) else { return 0 }
        return percent ? split.percents[index] : split.lengths[index]
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
            let axis = split.axis
        else { return }
        let asked =
            percent
            ? split.points(percent: number) : Int(number.rounded())
        guard asked != shown(id) || percent,
            let set = split.setting(
                id,
                to: asked,
                givingWay: other,
                floor: model.areaFloor(axis)
            )
        else { return }
        model.writeAreaSplit(set.split, on: display)
        typed = AreaGiveWay.typing(id, after: typed)
        announce(id, set.split, clamped: set.length != asked, other: other)
    }

    private func cancel() {
        model.writeAreaSplit(request.seed, on: display)
        typed = []
        drafts = [:]
        dismiss()
    }

    private func publishRest() {
        givingWay = rest.map {
            ScreenSelection(display: display.id, area: $0)
        }
    }

    private func announce(
        _ id: Int,
        _ split: ScreenSplit,
        clamped: Bool,
        other: Int
    ) {
        func length(_ area: Int) -> Int {
            split.areas.first { $0.id == area }.map {
                split.axis == .stacked ? $0.h : $0.w
            } ?? 0
        }
        func name(_ area: Int) -> String {
            model.areaLabel(area, on: display) ?? ""
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
        split.axis == .stacked
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
