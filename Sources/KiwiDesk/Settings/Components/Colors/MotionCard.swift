import KiwiDeskCore
import SwiftUI

/// Settings card for window animations (#171, #678, #1017).
struct MotionCard: View {
    @ObservedObject var model: SettingsModel
    /// macOS Reduce Motion forces animations off system-wide (#171).
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var moreExpanded = false

    var body: some View {
        // Section header help provides the gate anchor (#527).
        SettingsSection(
            SettingsCatalog.colors.motionCard,
            caption: caption,
            help: reduceMotion ? reduceMotionHelp : nil
        ) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    rows(ColorsRowOrder.motionAtRest)
                    disclosure
                }
                .modifier(GreyOut(active: reduceMotion))
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
            }
        }
    }

    private var disclosure: some View {
        SettingsDisclosure(
            SettingsCatalog.colors.motionMore,
            isExpanded: $moreExpanded,
            scrollHoisted: true
        ) {
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
                a.onSpaceChange = on ? defaults.onSpaceChange : false
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
