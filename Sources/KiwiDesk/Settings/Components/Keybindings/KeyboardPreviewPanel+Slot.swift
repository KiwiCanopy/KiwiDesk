import KiwiDeskCore
import SwiftUI

/// The board's status slot (#798) — split from the panel at the
/// §2.1 ceiling when the hover reading landed, not at the hard
/// limit. The slot is the panel's, so it stays an extension
/// rather than a view of its own: it reads `shown`, `selected`,
/// `claims` and `liveScope`, and a separate view would take all
/// four as parameters that could drift from the caps.
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

    /// Every conflicted key read aloud, through the SAME
    /// builder the pointer uses — the spoken half of #798's
    /// answer to "the ring cannot say which two".
    var conflictDetail: [String] {
        let ringed = collisions.union(
            KeyboardCensus.overwrittenReserved(
                claims: claims,
                scope: liveScope
            )
        )
        return ringed.sorted().flatMap {
            hoverReading($0)?.lines ?? []
        }
    }

    var slotLines: [String] {
        guard let hovered, let reading = hoverReading(hovered)
        else { return [tallyText] }
        return reading.lines
    }

    /// Reserved from what the slot can ACTUALLY be asked to
    /// draw, never a constant: under `.all` a seeded install
    /// already puts three claims on a digit (`⌃⌥1` go-to-Space,
    /// `⌃⌥⇧1` move-to-Space, `⌃⌥⌘1` follow), so a fixed
    /// two-line reservation nudges the panel on the COMMON
    /// case. The deepest key in the shown scope sets the floor,
    /// plus a line per conflict sentence it would carry.
    ///
    /// It is a floor, not a cap: a reading longer than this
    /// grows the slot rather than truncating, because a
    /// half-said conflict is worse than a nudge.
    var slotHeight: CGFloat {
        CGFloat(max(deepestReading, 1)) * Self.slotLine
    }

    /// Lines the deepest key under the shown scope would draw.
    private var deepestReading: Int {
        let ringed = collisions.union(
            KeyboardCensus.overwrittenReserved(
                claims: claims,
                scope: liveScope
            )
        )
        let deepestClaim =
            claims.values.map(\.count).max() ?? 1
        // A ringed key adds its cost sentence under the claims.
        return deepestClaim + (ringed.isEmpty ? 0 : 1)
    }

    /// One caption line at the panel's own metrics.
    private static let slotLine: CGFloat = 15

    func hoverReading(
        _ code: UInt32
    ) -> KeyboardHoverReading? {
        KeyboardHoverReading.of(
            code,
            in: shown,
            selected: selected,
            config: model.config,
            // One live read per PANEL render (#1105 bans one per
            // ROW): the panel is the section's sibling, so the
            // `disabledSystemShortcuts` environment it wires
            // never reaches here and would answer the empty
            // DEFAULT — narrating a dormant chord as dead.
            disabled: model.disabledSystemShortcuts(),
            labels: SettingsValueReadout.shortcutsActionLabels(
                old: model.config,
                new: model.config
            )
        )
    }

    var tallyText: String {
        let taken = KeyboardCensus.takenKeyCount(claims: claims)
        return L("keyboard.tally", "Keys taken: %1$d", taken)
    }

}
