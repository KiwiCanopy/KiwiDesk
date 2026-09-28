import Foundation
import Testing

@testable import KiwiDeskCore

/// Looks carry the focus border's shape and the global gaps
/// (#1739): through the commands' own parsers, the ruled bundled
/// values, and never a Space's own gap override.
@Suite("Look border and gaps")
struct LookBorderGapTests {
    private func look(_ style: [String: JSONValue]) -> ShelfLook {
        ShelfLook(name: "T", palette: nil, style: style)
    }

    private func gaps(_ outer: Double, _ inner: Double) -> JSONValue {
        let side = JSONValue.number(outer)
        let axis = JSONValue.number(inner)
        return .object([
            "outer": .object([
                "top": side, "bottom": side, "left": side, "right": side,
            ]),
            "inner": .object(["horizontal": axis, "vertical": axis]),
        ])
    }

    /// The command and the look write the same value for every
    /// argument, refusals and clamps included.
    @Test(
        "a look's border value is the command's",
        arguments: [
            ("width", JSONValue.number(99)),
            ("width", .number(0)),
            ("width", .number(2)),
            ("width", .string("thin")),
            ("corner_style", .string("square")),
            ("corner_style", .string("bevelled")),
            ("glow", .bool(true)),
            ("glow", .number(1)),
            ("glow_size", .number(-3)),
            ("glow_size", .number(500)),
            ("glow_size", .number(12)),
        ]
    )
    @MainActor
    func borderMatchesTheCommand(field: String, value: JSONValue) {
        let core = makeTestCore()
        let before = core.tiler.settings.borderStyle
        _ = core.execute("border.set_\(field)", args: [value])
        var settings = TilingSettings()
        settings.borderStyle = before
        look(["border.\(field)": value]).apply(to: &settings)
        #expect(settings.borderStyle == core.tiler.settings.borderStyle)
    }

    /// A look stores the config's own spelling of the gaps and
    /// reads it back through the config's decoder.
    @Test("a look's gaps are the config's")
    func gapsRoundTripTheConfig() {
        var source = TilingSettings()
        source.gapsGlobal = Gaps(
            outer: .init(top: 1, bottom: 2, left: 3, right: 4),
            inner: .init(horizontal: 5, vertical: 6)
        )
        let stored = LookKeys.extract(from: source)["gap.global"]
        var settings = TilingSettings()
        look(["gap.global": stored ?? .null]).apply(to: &settings)
        #expect(settings.gapsGlobal == source.gapsGlobal)
        // A partial or wrongly typed value is skipped, never guessed.
        look(["gap.global": .object(["outer": .number(3)])])
            .apply(to: &settings)
        look(["gap.global": .number(3)]).apply(to: &settings)
        #expect(settings.gapsGlobal == source.gapsGlobal)
    }

    /// The command keeps its own flat spelling; a missing key is
    /// the uniform 10.
    @Test("the gap command reads the flat table")
    @MainActor
    func commandReadsTheFlatTable() {
        let core = makeTestCore()
        let flat = JSONValue.object([
            "top": .number(3), "left": .number(4),
            "inner_vertical": .number(6),
        ])
        #expect(core.execute("set_gap_global", args: [flat]).isSuccess)
        #expect(
            core.tiler.settings.gapsGlobal
                == Gaps(
                    outer: .init(top: 3, bottom: 10, left: 4, right: 10),
                    inner: .init(horizontal: 10, vertical: 6)
                )
        )
    }

    /// One look, one stroke style (owner ruling 2026-09-28): the
    /// width and corners are every window stroke's (#1742).
    @Test("the ring's width and corners are every stroke's")
    func strokesFollowTheLook() {
        var settings = TilingSettings()
        look([
            "border.width": .number(2),
            "border.corner_style": .string("square"),
        ]).apply(to: &settings)
        #expect(
            settings.windowStroke
                == WindowStroke(width: 2, cornerRadius: 0)
        )
        look(["border.corner_style": .string("rounded")])
            .apply(to: &settings)
        #expect(
            settings.windowStroke.cornerRadius
                == GeometryUtils.systemWindowCornerRadius
        )
    }

    @Test("a look keeps a Space's own gap override")
    func overrideStays() {
        var settings = TilingSettings()
        settings.gapsOverride["1"] = .uniform(20)
        look(["gap.global": gaps(4, 4)]).apply(to: &settings)
        #expect(settings.gapsGlobal == .uniform(4))
        #expect(settings.gapsOverride["1"] == .uniform(20))
    }

    @Test("the enabled switches and the stacking never ride a look")
    func functionalityIsSkipped() {
        var settings = TilingSettings()
        look([
            "border.enabled": .bool(false),
            "border.unfocused_enabled": .bool(true),
            "border.draw_order": .string("front"),
        ]).apply(to: &settings)
        #expect(settings == TilingSettings())
    }

    /// Owner ruling 2026-09-28: Glass the shipped defaults, Tiler
    /// thin, square, no glow and tight gaps.
    @Test("the border and gap column")
    func column() throws {
        let column: [String: (Double, BorderStyle.CornerStyle, Bool, Double)] =
            [
                "Glass": (5, .rounded, false, 10),
                "Taskbar": (3, .rounded, false, 8),
                "Classic": (2, .square, false, 6),
                "Tiler": (2, .square, false, 4),
                "Pill": (4, .rounded, true, 14),
            ]
        let bundled = LookCatalog.bundled()
        #expect(Set(column.keys) == Set(bundled.map(\.name)))
        for look in bundled {
            let row = try #require(column[look.name])
            var settings = TilingSettings()
            look.apply(to: &settings)
            let border = settings.borderStyle
            #expect(Double(border.width) == row.0, "\(look.name)")
            #expect(border.cornerStyle == row.1, "\(look.name)")
            #expect(border.glow == row.2, "\(look.name)")
            #expect(settings.gapsGlobal == .uniform(row.3), "\(look.name)")
        }
    }

    /// Each look's gaps clear its rings, unfocused rings on too, so
    /// a look never makes two neighbours' rings overlap.
    @Test("every bundled look's gaps clear its rings")
    func gapsClearTheRings() {
        for look in LookCatalog.bundled() {
            var settings = TilingSettings()
            look.apply(to: &settings)
            settings.borderStyle.unfocusedEnabled = true
            let needed = settings.borderStyle.fittingGaps()
            let inner = settings.gapsGlobal.inner
            #expect(
                inner.horizontal >= needed.inner.horizontal
                    && inner.vertical >= needed.inner.vertical,
                "\(look.name) needs \(needed.inner.horizontal)"
            )
        }
    }
}
