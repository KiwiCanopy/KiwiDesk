import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The Space dots a hidden Space Bar's handle peeks (#761, #3349):
/// at most six, following the current Space and sliding only when
/// it would land on an end dot, small end dots where Spaces
/// continue, and its whole place for VoiceOver.
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
            key: Self.key
        )
        let dots = try #require(built)
        guard case .dots(let shown) = dots.peek else {
            Issue.record("Spaces draw dots")
            return
        }
        #expect(shown.count == ShelfDotWindow.cap)
        #expect(shown.first?.small == true)
        #expect(shown.last?.small == true)
        #expect(shown.dropFirst().dropLast().allSatisfy { !$0.small })
        #expect(shown.filter(\.current).count == 1)
        #expect(dots.position == .init(index: 7, count: 10))
        let built3 = hiding.spaceDots(
            items(3, active: 1),
            key: Self.key
        )
        let few = try #require(built3)
        guard case .dots(let all) = few.peek else { return }
        #expect(all.count == 3)
        #expect(all.allSatisfy { !$0.small })
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
        let view = ShelfHandleView()
        view.render(
            ShelfHandleSpec(
                peek: .dots([.init(current: true, occupied: true)]),
                frame: CGRect(x: 0, y: 0, width: 20, height: 8),
                edge: .top,
                fill: GlassFill(hex: "#000000"),
                currentInk: "#FFFFFF",
                ink: "#AAAAAA",
                emptyInk: "#555555",
                shown: false,
                hovered: false,
                reveal: .slide,
                position: .init(index: 7, count: 10)
            ),
            animated: false
        )
        #expect(
            view.accessibilityValue() as? String == "Hidden, Space 7 of 10"
        )
    }
}
