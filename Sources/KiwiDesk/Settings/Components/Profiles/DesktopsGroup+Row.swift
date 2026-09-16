import KiwiDeskCore
import SwiftUI

/// One row of the Desktops card: the Desktop's number, the
/// screen it lives on (#1438), its badges and its picker.
extension DesktopsGroup {
    func spaceRow(_ row: DesktopRow) -> some View {
        let number = row.number
        return HStack {
            Image(systemName: DesktopGlyph.symbol)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    L(
                        "desktops.desktop",
                        "Desktop %1$d",
                        number
                    )
                )
                .fontWeight(.medium)
                // Which screen the Desktop lives on (#1438) —
                // for a dormant row, the one it was last seen
                // on, since the number alone cannot say.
                if let screen = row.screen {
                    Text(screen)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            // By the DESKTOP, never its number: a dormant record
            // and a live Desktop can share one, and both rows
            // then claim to be current (owner device QA).
            if row.key == model.currentDesktopKey {
                BadgeChip(
                    label: L("desktops.current", "current")
                )
            }
            // A Desktop that is bound but does NOT live on the
            // main screen: listed because it carries the user's
            // own configuration, badged because a binding there
            // cannot fire in this arrangement — it waits for a
            // display change that makes that Desktop the main
            // screen's.
            //
            // A badge, never a grey: this row's picker is the
            // only way to change or clear that binding, so
            // dimming it would be the trap
            // `docs/design-decisions.md` bans — and the store is
            // valid and already effective, which "grey, don't
            // hide" does not describe (ui-designer, 2026-08-18).
            //
            // A Desktop that is not there AT ALL — its screen
            // unplugged, or the Desktop deleted — is the same
            // ruling one step further: the record is kept
            // (absence is never proof it is gone), the row is
            // labelled with the number it was last seen at, and
            // the badge says why nothing will fire.
            if row.isDormant {
                BadgeChip(
                    label: L(
                        "desktops.absent",
                        "not present"
                    )
                )
                // The badge alone can read as "your binding is
                // lost", which is the one thing this must not
                // mean — the sibling pin badge pairs a help for
                // the same reason.
                .help(
                    L(
                        "desktops.absent.help",
                        "This Desktop isn't in Mission Control "
                            + "right now — its screen is "
                            + "unplugged, or it was removed. The "
                            + "profile stays here and loads "
                            + "again if that Desktop comes back."
                    )
                )
            } else if !model.mainDesktops.contains(number) {
                BadgeChip(
                    label: L(
                        "desktops.not_on_main",
                        "not on main screen"
                    )
                )
            }
            if let count = otherScreenCount(row.key) {
                BadgeChip(
                    label: L(
                        "desktops.other_count",
                        "for %1$d screen(s)",
                        count
                    )
                )
                .help(
                    L(
                        "desktops.other_count.help",
                        "This profile is saved for %1$d "
                            + "screen(s); %2$d connected. Until "
                            + "that many are, the binding stands "
                            + "aside and KiwiDesk picks a profile "
                            + "by your screens instead.",
                        count,
                        model.displays.count
                    )
                )
            }
            Spacer()
            profileMenu(row.key)
        }
    }

}
