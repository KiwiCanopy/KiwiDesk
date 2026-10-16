import AppKit
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// A View-side chip and its line stand at their text's height
/// whatever height they are offered: the line is a horizontal
/// scroller, which offers its content the panel's leftover height.
@Suite("KiwiHub chip height")
@MainActor
struct ViewChipHeightTests {
    private static let offered = CGSize(width: 1000, height: 600)

    private func chip(showsNumber: Bool) -> ViewChip {
        ViewChip(
            item: ViewPickList.Item(
                pick: .profile("Laptop"),
                name: "Laptop",
                isCurrent: true
            ),
            line: .profile,
            number: 1,
            isSelected: true,
            isDimmed: false,
            showsNumber: showsNumber,
            onActivate: {},
            onHover: {}
        )
    }

    private func height(_ view: some View) -> CGFloat {
        NSHostingController(rootView: view)
            .sizeThatFits(in: Self.offered).height
    }

    @Test("a chip keeps its text's height, number shown or not")
    func chipHugsItsText() {
        for shows in [false, true] {
            let height = height(chip(showsNumber: shows))
            #expect(height > 0 && height < 30, "\(shows): \(height) pt")
        }
    }

    @Test("a chip line keeps its chips' height")
    func lineHugsItsChips() {
        let line = ViewLine(selected: nil) {
            chip(showsNumber: false)
        }
        let height = height(line)
        #expect(height > 0 && height < 30, "\(height) pt")
    }
}
