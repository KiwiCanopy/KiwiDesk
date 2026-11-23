import CoreGraphics
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Desktops side asks the panel's room for one narrowest column
/// per screen and is built at the width the room grants (#3570
/// ruling 4): a wide area grants every column its floor, a narrow
/// one less, shared by the columns. Main actor for `JumpModel`.
@Suite("Desktops width grant (#3570)")
@MainActor
struct DesktopsWidthGrantTests {
    typealias G = DesktopsGeometry
    typealias T = DesktopsStateTests
    static let cap = T.cap

    static func screen(_ id: UInt32) -> DesktopOverview.Screen {
        DesktopsGeometryTests.screen(id, desktops: 1, spaces: 2)
    }

    @Test("the width the room grants reaches the columns (#3570)")
    func modelWiresTheGrant() {
        let overview = DesktopOverview(
            screens: (1...5).map {
                Self.screen($0)
            },
            yours: nil
        )
        func model(areaWidth: CGFloat) -> JumpModel {
            let frame = CGRect(x: 0, y: 0, width: areaWidth, height: 900)
            let model = JumpModel(
                snapshot: JumpSnapshot(entries: [], here: nil, hereIcon: nil),
                icons: [:],
                rowCap: 9,
                room: JumpPanelRoom(
                    visible: frame,
                    area: frame,
                    topFraction: 0.2
                ),
                sheetCap: Self.cap
            )
            model.loadDesktops = { overview }
            model.setScope(.desktops)
            return model
        }
        // A wide area grants every column its floor; a narrow one
        // grants less, and the columns share what it grants.
        let wide = model(areaWidth: 2560)
        #expect(
            wide.desktopsContentWidth == G.preferredWidth(of: overview)
        )
        #expect(wide.sideWidth(for: .desktops) == wide.desktopsContentWidth)
        #expect(
            wide.desktops?.geometry.columns
                == Array(repeating: G.narrowestColumn, count: 5)
        )
        let narrow = model(areaWidth: 1100)
        let granted = narrow.sideWidth(for: .desktops)
        #expect(granted < G.preferredWidth(of: overview))
        #expect(
            narrow.desktops?.geometry
                == G(overview: overview, width: granted, cap: Self.cap)
        )
    }
}
