import KiwiDeskCore
import SwiftUI

/// The Bars area's greying, resolved from the census (#678
/// Phase 2): each card's block gate is its census container's
/// `SettingsContainer.gate`, and a row escapes it exactly when
/// its `SettingPlacement.exemptFromContainerGate` says so — the
/// census is the one copy of who may. Row-specific gates keep
/// their predicates here (the census names the owning setting;
/// the exact predicate lives with the wiring).
///
/// Every "shown bar" predicate asks about the bars actually
/// SHOWN rather than the global value (#520): per-layout
/// overrides are Lua-only now (GUI_REMOVED_2026-08) but still
/// resolve, so a gate keyed on the global would grey the only
/// editor for a value an overriding layout still reads.
///
/// All row predicates are also false while their card's block
/// gate is active — not to keep opacity from stacking
/// (`GreyOut` dims once by construction via its
/// `isInsideGreyOut` environment), but so the row's hover help
/// names the *outer* reason while the whole card is off instead
/// of a row-specific one that fixing wouldn't un-grey anything.
struct BarsGateContext {
    let settings: TilingSettings

    /// Resolves a census container's gate to "may edit" against
    /// the live draft. The two bar containers are the only ones
    /// this area renders; a Bars row placed in a new container
    /// fails the render-parity guard before this is reached.
    func allowsEditing(_ container: SettingsContainer) -> Bool {
        switch container.gate {
        case nil:
            return true
        case .setting(let key):
            return isOn(key)
        case .anyOf(let keys):
            return keys.contains { isOn($0) }
        case .runtime:
            // Fail-open in release, loud in debug — the same
            // treatment as the unknown-owner default below: a
            // bar container re-gated onto a runtime condition
            // this resolver cannot read would otherwise un-grey
            // silently forever.
            assertionFailure(
                "unhandled runtime container gate on \(container)"
            )
            return true
        }
    }

    /// The census gate owners this area can resolve — all
    /// boolean switches by construction (a container gate is an
    /// on/off owner, per `SettingsContainer.gate`'s contract).
    private func isOn(_ key: SettingKey) -> Bool {
        switch key {
        case .spaceBar(.spaceBarEnabled):
            return settings.spaceBarStyle.enabled
        case .layoutAppBar(.monocleAppBarEnabled):
            return settings.monocle.appBar.enabled
        case .layoutAppBar(.scrollingAppBarEnabled):
            return settings.scrolling.appBar.enabled
        default:
            // Fail-open in release (a live row beats a locked
            // editor), loud in debug: a census gate re-homed
            // onto an owner this resolver doesn't read would
            // otherwise un-grey silently forever.
            assertionFailure(
                "unhandled census gate owner: \(key.id)"
            )
            return true
        }
    }

    // MARK: - App Bar row predicates

    var shownBars: [LayoutAppBar] {
        settings.appBarHosts.filter(\.enabled)
    }

    var anyBarShown: Bool { !shownBars.isEmpty }

    /// True when NO shown bar draws a shared plate to size.
    var everyShownBarBoxed: Bool {
        anyBarShown
            && shownBars.allSatisfy {
                $0.resolved(with: settings.appBarStyle)
                    .backgroundStyle == .boxed
            }
    }

    /// True when EVERY shown bar renders on a vertical edge,
    /// where names would need stacked or rotated text.
    var everyShownBarVertical: Bool {
        anyBarShown
            && shownBars.allSatisfy {
                !$0.resolved(with: settings.appBarStyle)
                    .edge.isHorizontal
            }
    }

    /// True when no shown bar renders an icon at all.
    var everyShownBarNameOnly: Bool {
        anyBarShown
            && shownBars.allSatisfy {
                let bar = $0.resolved(with: settings.appBarStyle)
                return bar.content.rendered(
                    horizontal: bar.edge.isHorizontal
                ) == .name
            }
    }

    /// Under `activeIndicator = .gap` the active item's view is
    /// hidden outright (`AppBarOverlay`) and `accentMode`
    /// returns `.none` (`AppBarItemView`), so neither the
    /// highlight nor the active-item ink is ever painted.
    var gapOnly: Bool {
        anyBarShown
            && shownBars.allSatisfy {
                $0.resolved(with: settings.appBarStyle)
                    .activeIndicator == .gap
            }
    }
}

/// The block-gate explanations for the Bars page. Advanced
/// Colours needs the same conditions worded differently — its
/// sentences must say WHICH page to go to — so it authors its
/// own in `AdvancedColorsHelp` and shares only `gapOnly`, whose
/// sentence is about the indicator rather than about a place.
@MainActor
enum BarsGateHelp {
    static var noBarShown: String {
        L(
            "app_bar.no_layout.help",
            "No layout shows an App Bar — turn one on below."
        )
    }

    static var spaceBarOff: String {
        L(
            "space_bar.disabled.help",
            "Turn on Show Space Bar to edit these settings."
        )
    }

    static var gapOnly: String {
        L(
            "app_bar.color.gap_only",
            "The Gap indicator hides the active item instead of "
                + "marking it, so these colors aren't drawn."
        )
    }
}
