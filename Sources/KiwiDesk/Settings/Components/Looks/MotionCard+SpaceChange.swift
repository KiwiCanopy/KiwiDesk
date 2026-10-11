import KiwiDeskCore
import SwiftUI

/// The Space switch picker (#2143): Instant, Show the Space or
/// Slide, its own row above the window master and outside Reduce
/// Motion's grey. The caption follows the selection.
extension MotionCard {
    var spaceChangeRow: some View {
        let style = animations.spaceChange
        return VStack(alignment: .leading, spacing: 4) {
            DropdownRow(
                label: Self.spaceChangeLabel,
                spokenValue: Self.spaceChangeTitle(style.wrappedValue)
            ) {
                Picker(Self.spaceChangeLabel, selection: style) {
                    ForEach(SpaceChangeStyle.allCases, id: \.self) {
                        Text(Self.spaceChangeTitle($0)).tag($0)
                    }
                }
            }
            Text(spaceChangeCaption(style.wrappedValue))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    static var spaceChangeLabel: String {
        L("behavior.animations.space_change_style", "Space switches")
    }

    /// The option's title, drawn and spoken alike.
    static func spaceChangeTitle(_ style: SpaceChangeStyle) -> String {
        switch style {
        case .instant:
            return L("behavior.animations.space_change.instant", "Instant")
        case .cue:
            return L(
                "behavior.animations.space_change.cue",
                "Show the Space"
            )
        case .slide:
            return L("behavior.animations.space_change.slide", "Slide")
        }
    }

    /// What the selection does; under Reduce Motion, Slide names
    /// the Space instead, which its caption says.
    func spaceChangeCaption(_ style: SpaceChangeStyle) -> String {
        switch style {
        case .instant:
            return L(
                "behavior.animations.space_change.instant.caption",
                "The screen changes at once."
            )
        case .cue:
            return L(
                "behavior.animations.space_change.cue.caption",
                "The screen changes at once, and the Space you "
                    + "arrived on is named for a moment. A screen "
                    + "that draws a Space Bar skips it, since the "
                    + "bar already names the Space."
            )
        case .slide where reduceMotion:
            return L(
                "behavior.animations.space_change.slide_reduced",
                "Plates cover your windows and slide to the Space "
                    + "you're switching to. Reduce Motion is on, so "
                    + "the Space is named instead."
            )
        case .slide:
            return L(
                "behavior.animations.space_change.caption",
                "Plates cover your windows and slide to the "
                    + "Space you're switching to."
            )
        }
    }
}
