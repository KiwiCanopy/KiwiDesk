import KiwiDeskCore
import SwiftUI

/// The global App Bar editor's grey-out predicates (#520),
/// split from `AppBarGroups.swift` for the file ceiling.
///
/// Every one asks about the bars actually SHOWN rather than the
/// global value, because a per-layout override is what renders:
/// a gate keyed on the global greys the only editor for a value
/// an overriding layout still reads — the worse failure, since
/// the control is live and looks dead.
///
/// They are also all false when no bar shows, so none can
/// compound with the editor-wide gate: nested `GreyOut`s
/// multiply their 0.5 opacity to 0.25 and read as broken rather
/// than disabled. Keep that property when adding one.
extension GlobalAppBarGroup {
    var shownBars: [LayoutAppBar] {
        layoutBars.filter(\.enabled)
    }

    var anyBarShown: Bool { !shownBars.isEmpty }

    /// True when NO shown bar draws a shared plate to size.
    var everyShownBarBoxed: Bool {
        anyBarShown
            && shownBars.allSatisfy {
                $0.resolved(with: style).tabBackground == .boxed
            }
    }

    /// True when EVERY shown bar renders on a vertical edge,
    /// where names would need stacked or rotated text.
    var everyShownBarVertical: Bool {
        anyBarShown
            && shownBars.allSatisfy {
                !$0.resolved(with: style).edge.isHorizontal
            }
    }

    /// True when no shown bar renders an icon at all.
    var everyShownBarNameOnly: Bool {
        anyBarShown
            && shownBars.allSatisfy {
                let bar = $0.resolved(with: style)
                return bar.content.rendered(
                    horizontal: bar.edge.isHorizontal
                ) == .name
            }
    }

    /// Under `activeIndicator = .gap` the active tab's view is
    /// hidden outright (`AppBarOverlay`) and `accentMode`
    /// returns `.none` (`AppBarItemView`), so neither the
    /// highlight nor the active-item ink is ever painted.
    var gapOnly: Bool {
        anyBarShown
            && shownBars.allSatisfy {
                $0.resolved(with: style).activeIndicator == .gap
            }
    }

    var gapHelp: String {
        L(
            "app_bar.color.gap_only",
            "The Gap indicator hides the active tab instead of "
                + "marking it, so these colors aren't drawn."
        )
    }

    var noBarHelp: String {
        L(
            "app_bar.no_layout.help",
            "No layout shows an App Bar — turn one on below."
        )
    }
}
