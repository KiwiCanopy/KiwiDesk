import KiwiDeskCore
import SwiftUI

/// Colours & Motion ▸ Animations (#678 Phase 3, turn 12a). Moved
/// here whole from Behavior: the census places every one of its
/// rows in `.coloursAndMotion`, and a card split across two
/// destinations is a half-rendered area the parity guard cannot
/// see.
///
/// Rendered from the census: `ColorsRowOrder` gives the order and
/// the tiers decide what the disclosure hides — the master switch
/// at rest, the four per-event toggles and the duration behind it.
/// The drawer is named for what it holds rather than "more" or
/// "advanced": this area's Nerd twin is a whole separate card,
/// and one word must never mean both a row tier and mode depth.
struct MotionCard: View {
    @ObservedObject var model: SettingsModel
    /// macOS Reduce Motion forces animations off system-wide, so
    /// the whole card reads as a control with no effect and greys
    /// (#171) — the `.motion` container's census gate, which is a
    /// `.runtime` tag precisely because no setting owns it.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var moreExpanded = false

    var body: some View {
        // Reduce Motion greys the card CONTENT, not the header, so
        // the header `?` stays a live #527 anchor.
        SettingsSection(
            SettingsCatalog.colors.motionCard,
            caption: caption,
            help: reduceMotion ? reduceMotionHelp : nil
        ) {
            VStack(alignment: .leading, spacing: 8) {
                rows(ColorsRowOrder.motionAtRest)
                disclosure
                CrossReferenceRow(
                    prose: L(
                        "behavior.animations.scrolling_xref",
                        "Scrolling-layout focus shifts have "
                            + "their own toggle and speed in"
                    ),
                    linkTitle: L(
                        "behavior.animations.scrolling_xref_link",
                        "Layout Defaults ▸ Scrolling"
                    ),
                    destination: .layoutDefaults
                )
            }
            .modifier(GreyOut(active: reduceMotion))
        }
    }

    private var disclosure: some View {
        SettingsDisclosure(
            SettingsCatalog.colors.motionMore,
            chrome: .inline(font: .subheadline),
            isExpanded: $moreExpanded,
            scrollHoisted: true
        ) {
            // The master gates every row inside; the
            // non-compounding `GreyOut` dims once however this
            // nests inside the Reduce-Motion gate above.
            rows(ColorsRowOrder.motionMore)
                .padding(.top, 8)
                .modifier(
                    GreyOut(
                        active: !animationsMasterBinding
                            .wrappedValue
                    )
                )
        }
    }

    @ViewBuilder private func rows(
        _ keys: [SettingKey]
    ) -> some View {
        ForEach(keys, id: \.id) { key in
            row(for: key)
        }
    }

    @ViewBuilder private func row(
        for key: SettingKey
    ) -> some View {
        switch key {
        case .colours(let k):
            motionRow(k)
        default:
            let _ = assertionFailure(
                "unrendered Motion census key: \(key.id)"
            )
            EmptyView()
        }
    }

    /// Master switch over the per-event animation toggles shown
    /// in this card. Derived, not a stored field (a second
    /// persisted on/off would re-create the removed global
    /// `enable_animations` and a drift hazard): on when any of
    /// the four animates; off silences all four; on restores
    /// their shipped defaults (space switch stays opt-in).
    /// Deliberately excludes `onScrolling` — the scrolling slide
    /// has its own toggle on the Scrolling card (linked above),
    /// so folding it in here would let the master read on with
    /// every visible box off, and silently revert a choice made
    /// on a card the user can't see from here.
    var animationsMasterBinding: Binding<Bool> {
        Binding(
            get: {
                let a = model.config.settings.animations
                return a.onSpaceChange || a.onWindowResize
                    || a.onWindowSwap || a.onRelayout
            },
            set: { on in
                let defaults = AnimationSettings()
                var a = model.config.settings.animations
                a.onSpaceChange = on ? defaults.onSpaceChange : false
                a.onWindowResize = on ? defaults.onWindowResize : false
                a.onWindowSwap = on ? defaults.onWindowSwap : false
                a.onRelayout = on ? defaults.onRelayout : false
                model.config.settings.animations = a
            }
        )
    }

    private var caption: String {
        L(
            "motion.caption",
            "How windows move when the layout changes."
        )
    }

    private var reduceMotionHelp: String {
        L(
            "behavior.animations.reduce_motion.help",
            "System Settings ▸ Accessibility ▸ Reduce "
                + "Motion is on, so animations stay off "
                + "regardless of this setting."
        )
    }
}
