import KiwiDeskCore
import SwiftUI

/// The board's status slot (#798) — split from the panel at
/// §2.1's target, not at the hard ceiling. The slot is the
/// panel's, so it stays an extension rather than a view of its
/// own: it reads `shown`, `selected`, `claims` and `liveScope`,
/// and a separate view would take all four as parameters that
/// could drift from the caps.
extension KeyboardPreviewPanel {
    /// The tally line under the board (#798). It ANNOUNCES the
    /// tally even while a hover reading covers it: the reading
    /// is pointer state, and a board that already describes
    /// itself must not be read a second time beside it.
    var statusSlot: some View {
        Text(tallyText)
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(tallyText)
    }

    /// The hovered key's actions, drawn over the tally and the lines
    /// under it, down to the panel's visible bottom and never past
    /// it; a capped reading fills that height and ends on a "more"
    /// line. Pointer-only and silent, as the tally speaks (#2532).
    @ViewBuilder var hoverReading: some View {
        if let hovered {
            let groups = liveReading(hovered).groups
            GeometryReader { geometry in
                let top = geometry.frame(in: .global).minY
                let height = max(
                    viewportBottom.map { $0 - top }
                        ?? geometry.size.height,
                    0
                )
                let shown = shownGroups(
                    groups,
                    width: geometry.size.width,
                    height: height
                )
                VStack(alignment: .leading, spacing: Self.lineGap) {
                    ForEach(
                        Array(groups.prefix(shown).joined().enumerated()),
                        id: \.offset
                    ) { _, line in
                        readingLine(line)
                    }
                    if shown < groups.count {
                        readingLine(moreText(groups.count - shown))
                    }
                }
                .padding(.bottom, Self.readingPad)
                .frame(
                    maxWidth: .infinity,
                    minHeight: shown < groups.count ? height : nil,
                    alignment: .topLeading
                )
                .background(SettingsTheme.panel)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func readingLine(_ line: String) -> some View {
        Text(line)
            .font(Font(KeyboardHoverFit.font as CTFont))
            .foregroundStyle(SettingsTheme.ink2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func moreText(_ count: Int) -> String {
        L("keyboard.hover.more", "More shortcuts on this key: %1$d", count)
    }

    /// Each claim measured whole — its lines and the gaps between
    /// them — so the cut falls between claims, never inside one.
    private func shownGroups(
        _ groups: [[String]],
        width: CGFloat,
        height: CGFloat
    ) -> Int {
        KeyboardHoverFit.shown(
            heights: groups.map { group in
                group.map {
                    KeyboardHoverFit.height(of: $0, width: width)
                }
                .reduce(0, +)
                    + Self.lineGap * CGFloat(max(group.count - 1, 0))
            },
            more: KeyboardHoverFit.height(
                of: moreText(groups.count),
                width: width
            ),
            spacing: Self.lineGap,
            available: height - Self.readingPad
        )
    }

    private static let lineGap: CGFloat = 2
    private static let readingPad: CGFloat = 8

    /// Every ringed key read aloud, through the SAME builder the
    /// pointer uses and over the ONE ringed set the caps are
    /// drawn from — the spoken half of #798's answer to "the
    /// ring cannot say which two".
    ///
    /// Intersected with the keys the board actually DRAWS: a
    /// binding on an F-key or the keypad rings nothing on this
    /// picture, so a sentence about it would describe a cap that
    /// is not here.
    var conflictDetail: [String] {
        let read = reader
        return ringedKeys.intersection(drawnCodes).sorted()
            .flatMap { read($0).lines }
    }

    /// The keys the board rings, from the census's one
    /// derivation — never a second union beside the drawing.
    var ringedKeys: Set<UInt32> {
        KeyboardCensus.ringedKeys(
            in: shown,
            selected: selected,
            scope: liveScope
        )
    }

    private var drawnCodes: Set<UInt32> {
        Set(
            KeyboardMatrix.rows(
                for: KeyboardMatrix.PhysicalType.current()
            )
            .joined()
            .compactMap(\.code)
        )
    }

    /// ONE live preference read and one config capture per panel
    /// render, closed over for every key the slot and the spoken
    /// clause ask about.
    ///
    /// #1105 bans one read per ROW; this was one per RINGED KEY
    /// on every body evaluation — a full `AppleSymbolicHotKeys`
    /// sweep per cap the pointer crossed (code review, #798).
    ///
    /// The read is taken HERE because the panel is the section's
    /// SIBLING: the `disabledSystemShortcuts` environment the
    /// section wires never reaches this column and would answer
    /// the empty DEFAULT, narrating a dormant chord as dead.
    private var reader: (UInt32) -> KeyboardHoverReading {
        let disabled = model.disabledSystemShortcuts()
        let layers = shown
        let scope = liveScope
        let selection = selected
        let config = model.config
        let sides = model.appWide.modifierSides
        return { code in
            KeyboardHoverReading.of(
                code,
                in: layers,
                scope: scope,
                selected: selection,
                config: config,
                disabled: disabled,
                sides: sides
            )
        }
    }

    func liveReading(_ code: UInt32) -> KeyboardHoverReading {
        reader(code)
    }

    /// The caption as drawn: the hover hint leads it (#2532).
    /// Drawn and never spoken — VoiceOver cannot hover, and the
    /// board's own description already reads every key.
    var drawnCaption: String {
        L(
            "panel.caption.with_hover_hint",
            "%1$@ %2$@",
            L(
                "panel.caption.hover_hint",
                "Hover over a key to see its shortcuts."
            ),
            caption
        )
    }

    var tallyText: String {
        let taken = KeyboardCensus.takenKeyCount(claims: claims)
        return L("keyboard.tally", "Keys taken: %1$d", taken)
    }
}
