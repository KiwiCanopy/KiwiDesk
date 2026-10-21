import KiwiDeskCore
import SwiftUI

/// Animations settings card (#678). Moved whole from Behavior —
/// the census places every row in `.coloursAndMotion`, and a
/// card split across two destinations is a half-rendered area
/// the parity guard cannot see. "Motion" in this type's NAME is
/// frozen while the noun is "animation" (#1017, scoped to
/// labels — a census re-key has its own blast radius): prose
/// naming what is on screen says "the Animations card", and
/// *motion* survives only quoting Apple's "Reduce Motion".
struct MotionCard: View {
    @ObservedObject var model: SettingsModel
    /// macOS Reduce Motion forces animations off system-wide (#171).
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var moreExpanded = false

    var body: some View {
        // Section header help provides the gate anchor (#527).
        SettingsSection(
            SettingsCatalog.colors.motionCard,
            caption: caption,
            help: reduceMotion ? reduceMotionHelp : nil
        ) {
            VStack(alignment: .leading, spacing: 8) {
                // A whole card an OS switch greys says so in a box
                // with its one fix, beside the header's `?` (owner
                // ruling, 2026-10-21).
                if reduceMotion {
                    WarningBox(text: Self.reduceMotionWarning) {
                        Button(Self.openAccessibilityTitle) {
                            Self.openAccessibilityDisplay()
                        }
                        .settingsActionButton()
                    }
                }
                // Reduce Motion greys the CONTENT, never the
                // header, so the `?` stays a live #527 anchor —
                // the `.motion` container's `.runtime` census
                // gate (#171) — per row, less the census's
                // exemption; parallel `GreyOut`s, never nested
                // (gui.md).
                ForEach(ColorsRowOrder.motionAtRest, id: \.id) { key in
                    row(for: key).modifier(GreyOut(active: greyed(key)))
                }
                disclosure.modifier(GreyOut(active: reduceMotion))
                // Signpost stays outside the Reduce Motion gate
                // (#171; `LinkedCaption`).
                CrossReferenceRow(
                    prose: Self.scrollingXrefProse,
                    linkTitle: L(
                        "behavior.animations.scrolling_xref_link",
                        "Layout Defaults ▸ Scrolling"
                    ),
                    destination: .layoutDefaults
                )
                CrossReferenceRow(
                    prose: Self.barsXrefProse,
                    // The destination's own title, which is the card's.
                    linkTitle: SettingsDestination.bars.title,
                    destination: .bars
                )
            }
        }
    }

    /// Whether `key` greys: the card's Reduce Motion gate, less the
    /// census's exemption, one `GreyOut` per row, never nested
    /// (gui.md).
    private func greyed(_ key: SettingKey) -> Bool {
        reduceMotion && !key.placement.exemptFromContainerGate
    }

    private var disclosure: some View {
        SettingsDisclosure(
            SettingsCatalog.colors.motionMore,
            isExpanded: $moreExpanded,
            scrollHoisted: true
        ) {
            VStack(alignment: .leading, spacing: 8) {
                rows(ColorsRowOrder.motionMore)
                    .modifier(
                        GreyOut(
                            active: !animationsMasterBinding
                                .wrappedValue
                        )
                    )
            }
            .padding(.top, 8)
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
                "unrendered Animations census key: \(key.id)"
            )
            EmptyView()
        }
    }

    /// Master switch over per-event animation toggles; excludes scrolling.
    var animationsMasterBinding: Binding<Bool> {
        Binding(
            get: {
                model.config.settings.animations.anyEnabled
            },
            set: { on in
                let defaults = AnimationSettings()
                var a = model.config.settings.animations
                a.onWindowResize = on ? defaults.onWindowResize : false
                a.onWindowSwap = on ? defaults.onWindowSwap : false
                a.onRelayout = on ? defaults.onRelayout : false
                model.config.settings.animations = a
            }
        )
    }

    /// Static string for slot verification (`CrossReferenceRowSlotTests`,
    /// `CrossReferenceRow.linkSlot`, `LayoutSchematicCountTests`).
    static var scrollingXrefProse: String {
        L(
            "behavior.animations.scrolling_xref",
            "Scrolling-layout focus shifts have their own "
                + "toggle and duration in %1$@.",
            CrossReferenceRow.linkSlot
        )
    }

    /// The bars' reveal and expand moved to their own card (owner
    /// ruling, 2026-10-21).
    static var barsXrefProse: String {
        L(
            "behavior.animations.bars_xref",
            "The bars' animations are in %1$@.",
            CrossReferenceRow.linkSlot
        )
    }

    static var reduceMotionWarning: String {
        L(
            "behavior.animations.reduce_motion.warning",
            "Reduce Motion is on in System Settings, so these "
                + "animations don't play."
        )
    }

    static var openAccessibilityTitle: String {
        L(
            "behavior.animations.reduce_motion.open",
            "Open Accessibility Settings"
        )
    }

    /// System Settings ▸ Accessibility ▸ Display, where Reduce
    /// Motion lives; the pane alone, then the app, if refused.
    static let accessibilityDisplayPane = URL(
        string: "x-apple.systempreferences:"
            + "com.apple.Accessibility-Settings.extension?Display"
    )!

    @MainActor static func openAccessibilityDisplay() {
        if NSWorkspace.shared.open(accessibilityDisplayPane) { return }
        if let app = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.systempreferences"
        ) {
            NSWorkspace.shared.openApplication(
                at: app,
                configuration: .init()
            )
        }
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
