import Foundation
import KiwiDeskCore
import SwiftUI

/// What an area's menu or the editor's rows hand the Screens page
/// to present: the two popovers, which hang off the editor's own
/// buttons (#3517 ruling 24).
enum ScreenAreaAction: Equatable {
    case rename(ScreenSelection)
    case adjust(ScreenSelection)
    /// A merge moved the selection onto the area that survived.
    case select(ScreenSelection)
}

/// An area's context menu: the editor's own actions, on every route
/// a row's menu takes (`rowActions`).
struct AreaMenu: ViewModifier {
    @ObservedObject var model: SettingsModel
    let display: Display
    let area: Int?
    let act: (ScreenAreaAction) -> Void

    func body(content: Content) -> some View {
        content.rowActions { items }
    }

    private var here: ScreenSelection {
        ScreenSelection(display: display.id, area: area)
    }

    @ViewBuilder private var items: some View {
        if area != nil {
            Button(L("monitors.split.rename", "Rename…")) {
                act(.rename(here))
            }
            Divider()
        }
        ForEach(ScreenAreaEditing.axes(of: model, display), id: \.self) {
            axis in
            Button(ScreenAreaEditing.menuTitle(axis)) {
                model.splitArea(area ?? 0, on: display, axis)
            }
            .disabled(!model.canSplit(area ?? 0, on: display, axis))
        }
        if let area {
            let neighbours = model.mergeNeighbours(of: area, on: display)
            if !neighbours.isEmpty { Divider() }
            ForEach(neighbours, id: \.self) { other in
                Button(ScreenAreaEditing.mergeTitle(other, model, display)) {
                    if let kept = model.mergeArea(
                        area,
                        with: other,
                        on: display
                    ) {
                        act(
                            .select(
                                ScreenSelection(
                                    display: display.id,
                                    area: model.areaSplit(of: display) == nil
                                        ? nil : kept
                                )
                            )
                        )
                    }
                }
            }
            Divider()
            Button(L("monitors.sizes.menu.adjust", "Adjust Sizes…")) {
                act(.adjust(here))
            }
            Button(L("monitors.sizes.even_out", "Even Out")) {
                model.evenOutAreas(on: display)
            }
            .disabled(model.areaSplit(of: display)?.isEven ?? true)
        }
    }
}

/// The words and offers the editor's rows and the area menu share.
@MainActor
enum ScreenAreaEditing {
    /// The directions a selection may split along: both on a whole
    /// screen, only the one its areas run once split — the other is
    /// removed, not greyed, until nested splits ship (ruling 24).
    static func axes(
        of model: SettingsModel,
        _ display: Display
    ) -> [ScreenAreaCut.Axis] {
        if let axis = model.areaSplit(of: display)?.axis { return [axis] }
        return [.sideBySide, .stacked]
    }

    static func buttonTitle(_ axis: ScreenAreaCut.Axis) -> String {
        switch axis {
        case .sideBySide:
            L("monitors.split.side_by_side", "Side by Side")
        case .stacked:
            L("monitors.split.stacked", "Stacked")
        }
    }

    static func menuTitle(_ axis: ScreenAreaCut.Axis) -> String {
        switch axis {
        case .sideBySide:
            L("monitors.split.menu.side_by_side", "Split Side by Side")
        case .stacked:
            L("monitors.split.menu.stacked", "Split Stacked")
        }
    }

    static func mergeTitle(
        _ other: Int,
        _ model: SettingsModel,
        _ display: Display
    ) -> String {
        L(
            "monitors.merge.with",
            "Merge with %1$@",
            model.areaLabel(other, on: display) ?? ""
        )
    }

    /// Why a Split button is greyed: either half would fall under
    /// the floor along `axis`.
    static func floorReason(
        _ axis: ScreenAreaCut.Axis,
        floor: Int
    ) -> String {
        switch axis {
        case .sideBySide:
            L(
                "monitors.split.floor.side_by_side",
                "Each half would be narrower than the largest minimum "
                    + "window size, %1$d pt.",
                floor
            )
        case .stacked:
            L(
                "monitors.split.floor.stacked",
                "Each half would be shorter than the largest minimum "
                    + "window size, %1$d pt.",
                floor
            )
        }
    }
}
