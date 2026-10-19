import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// A hidden Space Bar's mark always fits its band (#761, owner
/// 2026-10-19): at most six dots, following the current Space and
/// sliding only when it would land on an end dot, small end dots
/// where Spaces continue, the current Space's identifier for its
/// hovered pill and its whole place for VoiceOver.
@Suite("Shelf Space dots (#761)")
@MainActor
struct ShelfDotWindowTests {
    private static let key = ShelfRevealer.Key(
        shelf: ShelfManager.Key(display: DisplayID(1), edge: .top),
        bar: .space
    )

    private func items(_ count: Int, active: Int) -> [SpaceBarOverlay.Item] {
        (1...count).map {
            SpaceBarOverlay.Item(
                space: SpaceID("\($0)"),
                spaceGlyph: .text("\($0)", tinted: true),
                apps: [],
                active: $0 == active,
                after: .none
            )
        }
    }

    @Test("a mark never outgrows its band, at any Space count")
    func markFitsTheBand() {
        var hiding = KiwiCore.HidingShelves()
        for count in 1...20 {
            for active in [1, count / 2 + 1, count] {
                let dots = hiding.spaceDots(
                    items(count, active: active),
                    key: Self.key,
                    settings: TilingSettings()
                )
                guard let mark = dots?.mark else {
                    Issue.record("Spaces draw dots")
                    return
                }
                #expect(
                    ShelfIndicatorSpec.length(of: mark)
                        <= ShelfMarkPlacement.bandLength
                )
            }
        }
    }

    @Test("the dots slide only when the current Space reaches an end")
    func slidesOnlyAtTheEnds() {
        // Ten Spaces, on the fourth: the row starts at the first.
        #expect(ShelfDotWindow.start(count: 10, current: 3, previous: 0) == 0)
        // On the sixth, the last slot: one in from the end.
        #expect(ShelfDotWindow.start(count: 10, current: 5, previous: 0) == 1)
        // Back to the third: inside the row, nothing moves.
        #expect(ShelfDotWindow.start(count: 10, current: 2, previous: 1) == 1)
        // The first Space is the row's own end.
        #expect(ShelfDotWindow.start(count: 10, current: 0, previous: 1) == 0)
        #expect(ShelfDotWindow.start(count: 10, current: 9, previous: 0) == 4)
        #expect(ShelfDotWindow.start(count: 4, current: 3, previous: 2) == 0)
    }

    @Test("an end with Spaces beyond it draws small; VoiceOver hears all")
    func smallEndsAndPosition() throws {
        var hiding = KiwiCore.HidingShelves()
        let built = hiding.spaceDots(
            items(10, active: 7),
            key: Self.key,
            settings: TilingSettings()
        )
        let dots = try #require(built)
        guard case .dots(let shown) = dots.mark else {
            Issue.record("Spaces draw dots")
            return
        }
        #expect(shown.count == ShelfDotWindow.cap)
        #expect(shown.first?.small == true)
        #expect(shown.last?.small == true)
        #expect(shown.dropFirst().dropLast().allSatisfy { !$0.small })
        #expect(shown.filter(\.current).count == 1)
        #expect(dots.position == .init(index: 7, count: 10))
        #expect(dots.label?.glyph == .text("7", tinted: true))
        let built3 = hiding.spaceDots(
            items(3, active: 1),
            key: Self.key,
            settings: TilingSettings()
        )
        let few = try #require(built3)
        guard case .dots(let all) = few.mark else { return }
        #expect(all.count == 3)
        #expect(all.allSatisfy { !$0.small })
    }

    @Test("the hovered pill takes the label's room; the plate widens")
    func pillTakesTheLabel() {
        let label = ShelfIndicatorSpec.label(
            .text("MA", tinted: true),
            font: NSFont.systemFont(ofSize: 8)
        )
        #expect(label.width > 0)
        let mark = CGRect(x: 10, y: 0, width: 40, height: 8)
        let extra =
            label.width + 2 * ShelfIndicatorSpec.labelPad
            - ShelfIndicatorSpec.currentDot
        let plate = BarMotion.hoverPlate(
            mark: mark,
            widen: extra,
            hovered: true,
            reduceMotion: true
        )
        // Content, not motion: the room is taken under Reduce
        // Motion too.
        #expect(
            plate.width == mark.width + extra + 2
                * ShelfIndicatorSpec.hoverGrowth
        )
        #expect(
            BarMotion.hoverPlate(mark: mark, hovered: true, reduceMotion: true)
                == mark
        )
    }
}

/// The mark's VoiceOver value names the whole place, since the dots
/// may not all show (#761).
@Suite("Shelf Space dots spoken (#761)")
@MainActor
struct ShelfDotSpokenTests {
    @Test("the value names the Space and the count")
    func valueNamesThePlace() {
        LocalizationManager.shared.select("en")
        let view = ShelfIndicatorView()
        view.render(
            ShelfIndicatorSpec(
                mark: .dots([.init(current: true, occupied: true)]),
                frame: CGRect(x: 0, y: 0, width: 20, height: 8),
                horizontal: true,
                fill: "#000000",
                currentInk: "#FFFFFF",
                ink: "#AAAAAA",
                emptyInk: "#555555",
                highlight: "#FF9900",
                shown: false,
                hovered: false,
                position: .init(index: 7, count: 10)
            ),
            animated: false
        )
        #expect(
            view.accessibilityValue() as? String == "Hidden, Space 7 of 10"
        )
    }
}
