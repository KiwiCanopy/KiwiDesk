import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A role group's colour (#1857): what it ticks on a fresh page,
/// what a pick writes, and what it leaves alone. Pure value work
/// over `TilingSettings`, so no model and no main actor.
@Suite("Role group colour")
struct RolePaintTests {
    private func paint(
        _ role: ColorRole,
        _ settings: TilingSettings,
        ticked: Set<SettingKey>? = nil,
        dimmed: Set<SettingKey> = []
    ) -> RolePaint {
        RolePaint(
            role: role,
            settings: settings,
            ticked: ticked ?? RolePaint.seed(role, settings),
            dimmed: dimmed
        )
    }

    /// A palette may split a row off the anchor's colour on
    /// purpose (the ring's stroke contrast, the drag-pair floor),
    /// so a fresh page ticks only the rows drawn alike — a seed by
    /// meaning would paint the bar green onto the ring. Explicit
    /// inputs, so a palette retune moves nothing here.
    @Test("a fresh page ticks the rows the palette draws alike")
    func seedFollowsThePalette() {
        #expect(
            RolePaint.seed(.accent, accentSettings())
                == [
                    .kiwishelf(.activeItemColor),
                    .kiwishelf(.highlightColor),
                ]
        )
        // A follower drawn in the anchor's own colour still takes
        // no tick: a group colour never writes it.
        var settings = TilingSettings()
        settings.spaceBarStyle.focusedItemColor = "#E0A030"
        settings.spaceBarStyle.focusedHighlightColor = "#E0A030"
        let seeded = RolePaint.seed(.secondAccent, settings)
        #expect(seeded.contains(.spaceBar(.spaceBarFocusedItemColor)))
        #expect(
            !seeded.contains(.spaceBar(.spaceBarFocusedHighlightColor))
        )
    }

    /// Explicit inputs: a palette retune must not move these.
    private func accentSettings() -> TilingSettings {
        var settings = TilingSettings()
        settings.kiwishelf.activeItemColor = "#8DB354"
        settings.kiwishelf.highlightColor = "#8DB354"
        settings.kiwishelf.hoverFillColor = "#AACB5D80"
        settings.borderStyle.focusedColor = "#4A9816"
        settings.dragGhost.borderColor = "#347957"
        settings.dragGhost.fillColor = "#34795740"
        return settings
    }

    @Test("a pick writes every target at its own alpha")
    func pickKeepsEachAlpha() throws {
        let settings = accentSettings()
        let all = Set(ColorRole.accent.keys)
        let out = paint(.accent, settings, ticked: all)
            .painted("#2F7FD6CC")
        #expect(out.kiwishelf.activeItemColor == "#2F7FD6")
        #expect(out.kiwishelf.hoverFillColor == "#2F7FD680")
        #expect(out.borderStyle.focusedColor == "#2F7FD6")
        #expect(out.dragGhost.fillColor == "#2F7FD640")
        // Untouched: a colour outside the group.
        #expect(out.kiwishelf.itemColor == settings.kiwishelf.itemColor)
    }

    @Test("a pick leaves unticked, dimmed and follower rows alone")
    func pickSkipsWhatItMustNotWrite() {
        var settings = TilingSettings()
        settings.spaceBarStyle.focusedItemColor = "#C2790A"
        settings.dragDropZone.borderColor = "#C2790A"
        settings.dragDropZone.fillColor = "#C2790A40"
        settings.spaceBarStyle.focusedHighlightColor = ""
        let ticked = Set(ColorRole.secondAccent.keys)
        let out = paint(
            .secondAccent,
            settings,
            ticked: ticked,
            dimmed: [.borders(.dragDropZoneFillColor)]
        ).painted("#123456")
        #expect(out.spaceBarStyle.focusedItemColor == "#123456")
        #expect(out.dragDropZone.borderColor == "#123456")
        #expect(out.dragDropZone.fillColor == "#C2790A40")
        #expect(out.spaceBarStyle.focusedHighlightColor == "")
        // Unticked.
        let none = paint(.accent, settings, ticked: [])
        #expect(none.targets.isEmpty)
        #expect(none.painted("#123456") == settings)
        // An unparseable pick writes nothing.
        #expect(
            paint(.accent, settings).painted("nope") == settings
        )
    }

    /// The well greys with a reason that says which: nothing is
    /// ticked, or every ticked row is dimmed.
    @Test("an idle well says why")
    func idleReason() {
        let settings = accentSettings()
        let active = SettingKey.kiwishelf(.activeItemColor)
        #expect(
            paint(.accent, settings, ticked: []).idle == .nothingTicked
        )
        #expect(
            paint(.accent, settings, ticked: [active], dimmed: [active])
                .idle == .allTickedDimmed
        )
        #expect(paint(.accent, settings, ticked: [active]).idle == nil)
        // A follower's tick is no tick.
        #expect(
            paint(
                .secondAccent,
                settings,
                ticked: [.spaceBar(.spaceBarFocusedHighlightColor)]
            ).idle == .nothingTicked
        )
    }

    @Test("the well shows the first target and says when they differ")
    func wellAndMixed() {
        let settings = accentSettings()
        let seeded = paint(.accent, settings)
        #expect(!seeded.mixed)
        #expect(seeded.wellHex == "#8DB354")
        let withRing = paint(
            .accent,
            settings,
            ticked: RolePaint.seed(.accent, settings)
                .union([.borders(.borderFocusedColor)])
        )
        #expect(withRing.mixed)
        #expect(withRing.wellHex == "#8DB354")
        // After a pick the targets agree again.
        let after = paint(
            .accent,
            withRing.painted("#2F7FD6"),
            ticked: withRing.ticked
        )
        #expect(!after.mixed)
        #expect(after.wellHex == "#2F7FD6")
    }

    /// The mixed answer is drawn: the title's `?` and the
    /// readout both read `RolePaint.mixed`, the third home of a
    /// master's divergence (gui.md, #1857).
    @Test("the card draws the mixed answer on both channels")
    func mixedIsWired() throws {
        let dir = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Colors"
            )
        func squashed(_ name: String) throws -> String {
            try SourceScan.strippedSource(
                at: dir.appendingPathComponent(name)
            ).filter { !$0.isWhitespace }
        }
        #expect(
            try squashed("RoleColorCards.swift").contains(
                "help:paint.mixed?RolePaintRow.mixedHelp:nil"
            )
        )
        #expect(
            try squashed("RolePaintRow.swift").contains(
                "ifpaint.mixed{Text(Self.mixedWord)"
            )
        )
    }
}
