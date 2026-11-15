import KiwiDeskCore
import SwiftUI

/// The boxed-in offer under the Screens picture (#2756): what
/// happens to the hidden windows and why, with one button for the
/// arrangement's one offer; the line a yes leaves; and the
/// fallback where no move helps. Draws nothing on a desk where
/// every screen has a free corner.
struct ScreenShiftNote: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        let state = model.screenShift
        if let offer = state.offer {
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                if offer.shifts.isEmpty {
                    HStack(alignment: .firstTextBaseline) {
                        sentences(offer, state)
                        Spacer()
                        HelpButton(
                            explanation: ScreenShiftText.help,
                            subject: ScreenShiftText.helpSubject
                        )
                    }
                    caption(ScreenShiftText.unfixable)
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        sentences(offer, state)
                        Spacer()
                        HelpButton(
                            explanation: ScreenShiftText.help,
                            subject: ScreenShiftText.helpSubject
                        )
                        Button(ScreenShiftText.button(offer)) {
                            model.askScreenShift(offer)
                        }
                        .settingsActionButton()
                    }
                }
            }
        } else if case .shifted(let ids) = state.answer {
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                caption(ScreenShiftText.shifted(ids, in: state))
            }
        }
    }

    /// One title and cause per boxed-in screen, read as one element.
    private func sentences(
        _ offer: ScreenOffer,
        _ state: ScreenShiftState
    ) -> some View {
        ScreenShiftSentences(offer: offer, state: state)
    }

    private func caption(_ frame: String) -> some View {
        let (leading, trailing) = CrossReferenceRow.split(frame)
        return LinkedCaption(
            leading: leading,
            linkTitle: ScreenShiftText.displaysPath,
            trailing: trailing,
            navigate: ScreenShiftText.openDisplays
        )
    }
}

/// Each boxed-in screen's title over its cause, the block one
/// VoiceOver element; shared by Screens and the Mac Checklist.
struct ScreenShiftSentences: View {
    let offer: ScreenOffer
    let state: ScreenShiftState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(offer.boxed, id: \.screen) { boxed in
                VStack(alignment: .leading, spacing: 2) {
                    Text(ScreenShiftText.title(boxed, in: state))
                        .font(.callout)
                        .foregroundStyle(SettingsTheme.ink)
                    Text(ScreenShiftText.cause(boxed, in: state))
                        .font(.caption)
                        .foregroundStyle(SettingsTheme.ink2)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

@MainActor
extension ScreenShiftText {
    /// System Settings ▸ Displays, plainly if the pane URL is
    /// refused.
    @MainActor static func openDisplays() {
        MacSettingRead.openPane(
            URL(
                string: "x-apple.systempreferences:"
                    + "com.apple.Displays-Settings.extension"
            )!
        )
    }
}
