import KiwiDeskCore

/// The Bars area's greying, resolved from the census (#678
/// Phase 2), folded onto the reason-case shape the redesigned
/// areas share (`GapsBordersGates`, `GeneralGates`,
/// `LayoutDefaultsGates`, 2026-08-03 convergence): the block gate
/// returns a REASON case rather than a Bool, so the grey and the
/// sentence explaining it are one decision (`BarsGateHelp.sentence`
/// renders it), never two that can disagree.
///
/// Each card's block gate is its census container's own greying
/// condition, and a row escapes it exactly when its
/// `SettingPlacement.exemptFromContainerGate` says so — the census
/// is the one copy of who may. Row-specific gates keep their
/// predicates here as WIRING (the census names the owning setting;
/// the exact predicate lives with the wiring), because they read
/// the bars actually SHOWN, which a per-layout Lua override can
/// change and no single declared owner can answer.
///
/// Every "shown bar" predicate asks about the bars actually SHOWN
/// rather than the global value (#520): per-layout overrides are
/// Lua-only now (GUI_REMOVED_2026-08) but still resolve, so a gate
/// keyed on the global would grey the only editor for a value an
/// overriding layout still reads.
struct BarsGates {
    let settings: TilingSettings

    /// Why a bar block — or a shown-bar-gated colour row — is
    /// inert. The two block reasons plus `.gapOnly`, whose
    /// PREDICATE is wiring (a resolved shown-bar value) but whose
    /// sentence belongs with the rest, authored once.
    enum InertReason: Hashable {
        /// No layout shows an App Bar.
        case noBarShown
        /// The Space Bar is switched off.
        case spaceBarOff
        /// The active indicator is Gap — it hides the active item
        /// instead of marking it, so the highlight/active colours
        /// are never painted.
        case gapOnly
    }

    /// Resolves a bar container's block gate to a reason, or nil
    /// while it is live. The two bar containers are the only ones
    /// this area renders; a Bars row placed in a new container
    /// fails the render-parity guard before this is reached.
    func containerReason(
        for container: SettingsContainer
    ) -> InertReason? {
        switch container {
        case .appBar:
            return anyBarShown ? nil : .noBarShown
        case .spaceBar:
            return settings.spaceBarStyle.enabled
                ? nil : .spaceBarOff
        default:
            return nil
        }
    }

    // MARK: - App Bar row predicates (wiring)

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

/// The inline sentence each `BarsGates.InertReason` renders — the
/// "why you can't edit this" a greyed block or row shows on hover.
/// Split from the resolver so the resolver stays assertable off the
/// main actor; the reason and its sentence are one decision, never
/// two that can disagree (#678, gui.md). Every key here is reused
/// from the hand-wired gate this conversion replaced, so the
/// English is unchanged and no translation is dropped.
///
/// Advanced Colours needs the two block conditions worded
/// differently — its sentences must say WHICH page to go to — so it
/// authors its own in `AdvancedColorsHelp` and shares only the
/// `.gapOnly` sentence, whose wording is about the indicator
/// rather than a place.
@MainActor
enum BarsGateHelp {
    static func sentence(for reason: BarsGates.InertReason) -> String {
        switch reason {
        case .noBarShown:
            return L(
                "app_bar.no_layout.help",
                "No layout shows an App Bar — turn one on below."
            )
        case .spaceBarOff:
            return L(
                "space_bar.disabled.help",
                "Turn on Show Space Bar to edit these settings."
            )
        case .gapOnly:
            // The indicator style is INTERPOLATED from the picker
            // entry's own key rather than named as text (#818):
            // a sentence quoting a label is a hand-kept mirror
            // every locale must keep in step with nothing
            // checking that it does.
            return L(
                "app_bar.color.gap_only",
                "The \u{201C}%1$@\u{201D} indicator hides the "
                    + "active item instead of marking it, so "
                    + "these colors aren't drawn.",
                L("app_bar.active_indicator.gap", "Gap")
            )
        }
    }
}
