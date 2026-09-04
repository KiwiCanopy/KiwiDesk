import KiwiDeskCore
import SwiftUI

/// The board's status slot (#798) — split from the panel at
/// §2.1's target, not at the hard ceiling. The slot is the
/// panel's, so it stays an extension rather than a view of its
/// own: it reads `shown`, `selected`, `claims` and `liveScope`,
/// and a separate view would take all four as parameters that
/// could drift from the caps.
extension KeyboardPreviewPanel {
    /// One slot, two readings: the tally at rest, the hovered
    /// key's actions under the pointer (#798). Bimodal rather
    /// than a fifth line — the panel already stacks four under
    /// the board, and a strip that appears on hover shoves them
    /// all down under the user's own pointer.
    ///
    /// It ANNOUNCES the tally either way: the hover reading is
    /// pointer state, and a board that already describes itself
    /// must not be read a second time beside it.
    var statusSlot: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(slotLines.enumerated()), id: \.offset) {
                _,
                line in
                Text(line)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: slotHeight,
            alignment: .topLeading
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tallyText)
    }

    var slotLines: [String] {
        guard let hovered else { return [tallyText] }
        return liveReading(hovered).lines
    }

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

    /// Reserved from what the slot can ACTUALLY be asked to
    /// draw, never a constant: under `.all` a seeded install
    /// already puts three claims on a digit (`⌃⌥1` go-to-Space,
    /// `⌃⌥⇧1` move-to-Space, `⌃⌥⌘1` follow), so a fixed
    /// two-line reservation nudges the panel on the COMMON case.
    ///
    /// Measured from the READINGS rather than from a claim
    /// count: a ringed key draws a cost sentence under each
    /// claim, so two bindings on one chord is four lines, not
    /// two — counting claims understated exactly the case the
    /// feature exists for (code review, #798).
    ///
    /// A floor, not a cap: a longer reading grows the slot
    /// rather than truncating, because a half-said conflict is
    /// worse than a nudge.
    var slotHeight: CGFloat {
        CGFloat(max(deepestReading, 1)) * Self.slotLine
    }

    /// Lines the deepest key on the board would draw.
    var deepestReading: Int {
        let read = reader
        return claims.keys.map { read($0).lines.count }.max() ?? 1
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
        return { code in
            KeyboardHoverReading.of(
                code,
                in: layers,
                scope: scope,
                selected: selection,
                config: config,
                disabled: disabled
            )
        }
    }

    func liveReading(_ code: UInt32) -> KeyboardHoverReading {
        reader(code)
    }

    var tallyText: String {
        let taken = KeyboardCensus.takenKeyCount(claims: claims)
        return L("keyboard.tally", "Keys taken: %1$d", taken)
    }

    /// One caption line at the panel's own metrics.
    static let slotLine: CGFloat = 15
}
