import Foundation
import KiwiDeskCore
import SwiftUI

/// The selection's editor under the Screens picture (#3517 ruling
/// 24): a heading naming the selection with Rename… beside it, then
/// Split, Merge and Area sizes. It leaves with the selection.
struct ScreenAreaEditor: View {
    @ObservedObject var model: SettingsModel
    let display: Display
    /// The selected area, nil on a whole screen.
    let area: Int?
    @Binding var rename: AreaRenameRequest?
    @Binding var sizes: AreaSizesRequest?
    @Binding var givingWay: Set<ScreenSelection>
    /// Adjust…'s unit, held by the page while Settings stays open.
    @Binding var percent: Bool
    let select: (ScreenSelection?) -> Void
    /// After a Split or Merge removes the button pressed, focus lands
    /// on the first Split button, always drawn with a selection.
    @FocusState private var focus: EditorFocus?
    /// A Split or Merge pressed: focus lands once the editor redraws
    /// for the new split.
    @State private var landing = false

    private enum EditorFocus: Hashable {
        case split(ScreenAreaCut.Axis)
        case rename
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            heading
            splitRow
            if let area {
                mergeRow(area)
                sizesRow
            }
        }
        .onChange(of: model.config.settings.displayAreas) {
            if landing { DispatchQueue.main.async { land() } }
        }
    }

    private var id: Int { area ?? 0 }

    private var heading: some View {
        HStack(alignment: .firstTextBaseline) {
            SettingsGroupHeading(title: model.areaName(area, on: display))
            Spacer()
            if let area {
                Button(L("monitors.split.rename", "Rename…")) {
                    rename = AreaRenameRequest(
                        display: display.id,
                        area: area
                    )
                }
                .settingsActionButton()
                .focused($focus, equals: .rename)
                .popover(item: $rename) { request in
                    renamePopover(request).settingsPopoverChrome()
                }
            }
        }
    }

    private var splitRow: some View {
        let axes = ScreenAreaEditing.axes
        let rect = model.editableSplit(of: display).areas.first {
            $0.id == id
        }
        let greyed = axes.filter { !model.canSplit(id, on: display, $0) }
        let size = L(
            "monitors.split.size",
            "%1$d × %2$d pt",
            rect?.w ?? 0,
            rect?.h ?? 0
        )
        let reasons = greyed.map {
            ScreenAreaEditing.floorReason($0, floor: model.areaFloor($0))
        }
        return SettingsActionRow(
            title: L("monitors.split.title", "Split"),
            caption: ([size] + reasons).joined(separator: "\n")
        ) {
            HStack(spacing: 6) {
                ForEach(axes, id: \.self) { axis in
                    splitButton(axis, greyed: greyed.contains(axis))
                }
            }
        }
    }

    private func splitButton(
        _ axis: ScreenAreaCut.Axis,
        greyed: Bool
    ) -> some View {
        let name = model.areaName(area, on: display)
        return Button {
            model.splitArea(id, on: display, axis)
            select(ScreenSelection(display: display.id, area: id))
            landFocus()
        } label: {
            Label(
                ScreenAreaEditing.buttonTitle(axis),
                systemImage: ScreenAreaEditing.symbol(axis)
            )
            .labelStyle(.titleAndIcon)
        }
        .settingsActionButton()
        .disabled(greyed)
        .focused($focus, equals: .split(axis))
        .help(
            greyed
                ? ScreenAreaEditing.floorReason(
                    axis,
                    floor: model.areaFloor(axis)
                ) : ""
        )
        .accessibilityLabel(
            axis == .sideBySide
                ? L(
                    "monitors.split.side_by_side.ax",
                    "Split %1$@ side by side",
                    name
                )
                : L(
                    "monitors.split.stacked.ax",
                    "Split %1$@ top to bottom",
                    name
                )
        )
    }

    @ViewBuilder private func mergeRow(_ area: Int) -> some View {
        let neighbours = model.mergeNeighbours(of: area, on: display)
        if !neighbours.isEmpty {
            SettingsActionRow(
                title: L("monitors.merge.title", "Merge"),
                caption: nil
            ) {
                if ScreenAreaEditing.mergePullsDown(neighbours) {
                    mergeMenu(area, neighbours)
                } else {
                    // Long custom names fall back to the pull-down.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 6) {
                            ForEach(neighbours, id: \.self) { other in
                                mergeButton(area, other)
                                    .settingsActionButton()
                            }
                        }
                        mergeMenu(area, neighbours)
                    }
                }
            }
        }
    }

    private func mergeMenu(_ area: Int, _ neighbours: [Int]) -> some View {
        Menu(ScreenAreaEditing.mergeMenuTitle) {
            ForEach(neighbours, id: \.self) { other in
                mergeButton(area, other)
            }
        }
        .menuStyle(.borderlessButton)
        .neutralMenuLabel()
        .fixedSize()
        .menuTriggerHover()
    }

    /// The neighbour's bare name: the row title says Merge, and
    /// VoiceOver, which skips that title, hears the whole action.
    private func mergeButton(_ area: Int, _ other: Int) -> some View {
        let title = ScreenAreaEditing.mergeTitle(other, model, display)
        return Button(model.areaLabel(other, on: display) ?? title) {
            let kept = model.mergeArea(area, with: other, on: display)
            select(
                ScreenSelection(
                    display: display.id,
                    area: model.areaSplit(of: display) == nil ? nil : kept
                )
            )
            landFocus()
        }
        .help(title)
        .accessibilityLabel(title)
    }

    /// The row or column the selection sits in (#3541).
    private func run(_ area: Int) -> ScreenAreaRun? {
        model.areaSplit(of: display)?.run(holding: area)
    }

    @ViewBuilder private var sizesRow: some View {
        if let area, let split = model.areaSplit(of: display),
            let run = run(area)
        {
            SettingsActionRow(
                title: L("monitors.sizes.title", "Area sizes"),
                caption: L(
                    "monitors.sizes.caption",
                    "%1$@ pt",
                    run.lengths.map(String.init).joined(separator: " · ")
                )
            ) {
                HStack(spacing: 6) {
                    Button(L("monitors.sizes.adjust", "Adjust…")) {
                        sizes = AreaSizesRequest(
                            display: display.id,
                            area: area,
                            seed: split
                        )
                    }
                    .settingsActionButton()
                    .popover(item: $sizes) { request in
                        AreaSizesPopover(
                            model: model,
                            display: display,
                            request: request,
                            givingWay: $givingWay,
                            percent: $percent,
                            dismiss: { sizes = nil }
                        )
                        .settingsPopoverChrome()
                    }
                    Button(L("monitors.sizes.even_out", "Even Out")) {
                        model.evenOutAreas(holding: area, on: display)
                    }
                    .settingsActionButton()
                    .disabled(!model.canEvenOut(holding: area, on: display))
                }
            }
        }
    }

    /// Asks for focus to land once the editor redraws: the button
    /// pressed may be gone (gui.md ▸ the keyboard path).
    private func landFocus() { landing = true }

    /// The first enabled Split button, else Rename…, both drawn
    /// while an area is selected; read from the redrawn editor.
    private func land() {
        landing = false
        if let axis = ScreenAreaEditing.axes.first(
            where: { model.canSplit(id, on: display, $0) }
        ) {
            focus = .split(axis)
        } else if area != nil {
            focus = .rename
        }
    }

    private func renamePopover(_ request: AreaRenameRequest) -> some View {
        let area = request.area
        let fallback =
            model.editableSplit(of: display).positions[area]
            .map { ScreenAreaWords.position($0) } ?? ""
        let current =
            model.areaSplit(of: display)?.areas
            .first { $0.id == area }?.name ?? ""
        return NameEditPopover(
            seed: current,
            placeholder: L("monitors.split.rename.placeholder", "Area name"),
            confirmLabel: { _ in
                L("monitors.split.rename.confirm", "Rename")
            },
            isValid: {
                model.areaNameProblem($0, for: area, on: display) == nil
            },
            notice: { name in
                name.isEmpty
                    ? L(
                        "monitors.split.rename.default",
                        "Leave empty to use “%1$@”.",
                        fallback
                    ) : nil
            },
            problem: { name in
                switch model.areaNameProblem(name, for: area, on: display) {
                case .number?:
                    L(
                        "monitors.split.name.number",
                        "A name can't be only digits."
                    )
                case .taken?:
                    L(
                        "monitors.split.name.taken",
                        "Another screen or area already has this name."
                    )
                case nil:
                    nil
                }
            },
            onConfirm: { name in
                model.renameArea(area, on: display, to: name)
                rename = nil
            }
        )
    }
}
