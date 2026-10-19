import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The minimum window size master and its per-layout rows (#2237):
/// what the master WRITES, what each axis SHOWS while layouts
/// differ, and that the master's `?`, its "Mixed" and the drawer's
/// hold-open all read the one verdict (gui.md ▸ A master whose
/// followers disagree).
@MainActor
@Suite("The minimum window size master")
struct MinWindowSizeMasterTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    @Test("the master writes every layout, one axis at a time")
    func masterFansOut() {
        let model = makeTestModel()
        model.config.settings.minWindowSizes.grid =
            MinSize(width: 220, height: 160)
        model.setMinSize(410, axis: .width, for: nil)
        for layout in MinWindowSizes.Layout.allCases {
            #expect(model.minSize(layout, .width) == 410, "\(layout)")
        }
        #expect(model.minSize(.grid, .height) == 160)
        #expect(model.minSize(.stack, .height) == 300)
    }

    @Test("a row writes its own layout alone")
    func rowWritesItsLayout() {
        let model = makeTestModel()
        model.setMinSize(480, axis: .width, for: .scrolling)
        #expect(model.minSize(.scrolling, .width) == 480)
        for layout in MinWindowSizes.Layout.allCases
        where layout != .scrolling {
            #expect(model.minSize(layout, .width) == 300, "\(layout)")
        }
    }

    /// Each axis on its own: a guard that only ever differs both
    /// axes at once is blind to a master that reads one of them.
    @Test("an axis reads Mixed only while the layouts differ on it")
    func mixedPerAxis() {
        for layout in MinWindowSizes.Layout.allCases {
            let model = makeTestModel()
            #expect(model.minSizeShared(.width) == 300)
            #expect(!model.minSizesDiffer)
            model.setMinSize(220, axis: .width, for: layout)
            #expect(model.minSizeShared(.width) == nil, "\(layout)")
            #expect(model.minSizeShared(.height) == 300, "\(layout)")
            #expect(model.minSizesDiffer, "\(layout)")
            // Measured against the most-used layout's value: the
            // one that moved stands apart, or every other does.
            let used = MinWindowSizes.Layout(
                LayoutUsage.mostUsed(in: model.config)
            )
            #expect(
                layout == used
                    ? model.minSizeStandsApart(
                        layout == .stack ? .grid : .stack
                    )
                    : model.minSizeStandsApart(layout),
                "\(layout)"
            )
            model.setMinSize(300, axis: .width, for: layout)
            #expect(!model.minSizesDiffer, "\(layout)")
        }
    }

    @Test("a mixed axis steps from the most-used layout's value")
    func referenceIsTheMostUsed() {
        let model = makeTestModel()
        let used =
            MinWindowSizes.Layout(LayoutUsage.mostUsed(in: model.config))
            ?? .bsp
        model.setMinSize(220, axis: .width, for: used)
        model.setMinSize(480, axis: .width, for: .floating)
        #expect(model.minSizeReference(.width) == 220)
        #expect(!model.minSizeStandsApart(used))
    }
    /// Each axis's search anchor is that layout's own child of the
    /// Per layout drawer, so a hit opens it on the right field.
    @Test("each axis anchors its own drawer child")
    func anchorsAreOneToOne() {
        var ids: Set<String> = []
        for layout in MinWindowSizes.Layout.allCases {
            for axis in MinSizeAxis.allCases {
                let control = MinSizeText.control(layout, axis)
                ids.insert(control.id)
                #expect(
                    control.key
                        == "layout_defaults.min_size."
                        + "\(layout.rawValue)_\(axis)"
                )
            }
        }
        #expect(ids.count == 12)
    }

    /// The master's `?`, both "Mixed" readouts and the drawer's
    /// summary and hold-open are drawn from the model's verdict — never a
    /// comparison re-derived in the view.
    @Test("the master reads one verdict")
    func masterReadsOneVerdict() throws {
        let file = Self.root.appendingPathComponent(
            "Sources/KiwiDesk/Settings/Components/Layouts/"
                + "MinWindowSizeRows.swift"
        )
        let text = try SourceScan.strippedSource(at: file)
        #expect(
            text.components(separatedBy: "model.minSizesDiffer")
                .count - 1 == 3
        )
        #expect(text.contains("width: model.minSizeShared(.width)"))
        #expect(text.contains("height: model.minSizeShared(.height)"))
        #expect(!text.contains("minWindowSizes"))
    }
}
