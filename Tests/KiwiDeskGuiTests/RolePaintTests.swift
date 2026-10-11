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

    /// The shipped default splits the ring and the ghost off the
    /// bar's green on purpose (stroke contrast, the drag-pair
    /// floor), so only the bar's two rows start ticked — a seed
    /// by meaning would paint the bar green onto the ring.
    @Test("a fresh page ticks the rows the palette draws alike")
    func seedFollowsThePalette() {
        let settings = TilingSettings()
        #expect(
            RolePaint.seed(.accent, settings)
                == [
                    .kiwishelf(.activeItemColor),
                    .kiwishelf(.highlightColor),
                ]
        )
        // Second accent: the drop zone shares the focused amber at
        // its own alpha; the follower never takes a tick.
        #expect(
            RolePaint.seed(.secondAccent, settings)
                == [
                    .spaceBar(.spaceBarFocusedItemColor),
                    .borders(.dragDropZoneBorderColor),
                    .borders(.dragDropZoneFillColor),
                ]
        )
    }

    @Test("a pick writes every target at its own alpha")
    func pickKeepsEachAlpha() throws {
        var settings = TilingSettings()
        settings.kiwishelf.hoverFillColor = "#AACB5D80"
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
        #expect(out.dragDropZone.fillColor == settings.dragDropZone.fillColor)
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

    @Test("the well shows the first target and says when they differ")
    func wellAndMixed() {
        let settings = TilingSettings()
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
}
