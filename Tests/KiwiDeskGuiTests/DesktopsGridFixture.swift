import CoreGraphics
import KiwiDeskCore

@testable import KiwiDesk

/// Shared Desktops on two screens (#3602): Built-in (here, split
/// Left 0..<2 / Right 2..<4 on Desktop 1) and DELL (unsplit, three
/// lines on Desktop 1). Desktop 2 holds one line on Built-in and
/// two on DELL, and binds profile "Work".
@MainActor
enum DesktopsGridFixture {
    typealias T = DesktopsStateTests

    static func area(_ id: Int, _ lines: Range<Int>) -> DesktopOverview.Area {
        DesktopOverview.Area(
            key: ScreenAreaKey(fingerprint: "Wide:3440x1440", areaID: id),
            name: nil,
            position: id == 0 ? [.left] : [.right],
            isHere: id == 0,
            lines: lines
        )
    }

    static func desktop(
        _ label: Int,
        lines: Int,
        areas: [DesktopOverview.Area] = [],
        profile: String? = nil
    ) -> DesktopOverview.Desktop {
        DesktopOverview.Desktop(
            native: UInt64(label),
            label: label,
            number: label,
            isShown: label == 1,
            profile: profile,
            spaces: (0..<lines).map {
                T.line("\(label)\($0)", [], shown: $0 == 0)
            },
            areas: areas
        )
    }

    /// `rows` overrides the rows Core would read off the screens.
    static func overview(
        shared: Bool = true,
        rows: [DesktopOverview.Row]? = nil
    ) -> DesktopOverview {
        let here = DesktopOverview.Screen(
            display: DisplayID(1),
            name: "Built-in",
            isMain: true,
            isHere: true,
            desktops: [
                desktop(1, lines: 4, areas: [area(0, 0..<2), area(1, 2..<4)]),
                desktop(2, lines: 1, profile: "Work"),
            ]
        )
        let other = DesktopOverview.Screen(
            display: DisplayID(2),
            name: "DELL",
            isMain: false,
            isHere: false,
            desktops: [
                desktop(1, lines: 3),
                desktop(2, lines: 2, profile: "Work"),
            ]
        )
        return DesktopOverview(
            screens: [here, other],
            yours: nil,
            rows: shared
                ? rows ?? [
                    row(1, profile: nil, shown: true),
                    row(2, profile: "Work", shown: false),
                ]
                : []
        )
    }

    static func row(
        _ label: Int,
        profile: String?,
        shown: Bool
    ) -> DesktopOverview.Row {
        DesktopOverview.Row(
            native: UInt64(label),
            label: label,
            profile: profile,
            isShown: shown
        )
    }

    /// Seven points a character: a title's width without AppKit.
    nonisolated static func measure(_ title: String) -> CGFloat {
        CGFloat(title.count * 7)
    }

    static func geometry(
        _ overview: DesktopOverview = overview(),
        width: CGFloat = 900,
        cap: CGFloat = 1000,
        measure: (String) -> CGFloat = measure
    ) -> DesktopsGeometry {
        DesktopsGeometry(
            overview: overview,
            width: width,
            cap: cap,
            gutter: DesktopsGeometry.gutter(of: overview, measure: measure)
        )
    }

    static func state(_ overview: DesktopOverview = overview())
        -> DesktopsState
    {
        DesktopsState(overview: overview, geometry: geometry(overview))
    }
}
