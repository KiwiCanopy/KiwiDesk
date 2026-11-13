import KiwiDeskCore
import SwiftUI

/// The Spaces step's "Start with" control (#3294): Current where
/// the desk changed, then Suggested and the presets the connected
/// screens are offered. A pick redraws the cards and writes nothing.
struct OnboardingStartPicker: View {
    let start: OnboardingStartModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // The title rides above the control, not beside it: five
            // segments fill the page's width in several locales.
            OnboardingRowHeader(text: title)
                .accessibilityHidden(true)
            Picker(title, selection: selection) {
                ForEach(start.options) { option in
                    Text(Self.label(of: option)).tag(option.id)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel(title)
            .accessibilityValue(start.selected.map(Self.label) ?? "")
            if start.replacesCurrent {
                Text(
                    L(
                        "onboarding.start_with.replaces",
                        "Continuing replaces your current Spaces."
                    )
                )
                .font(.system(size: 12.5))
                .foregroundStyle(SettingsTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var title: String {
        L("onboarding.start_with.title", "Start with")
    }

    private var selection: Binding<String> {
        Binding(
            get: { start.selected?.id ?? "" },
            set: { id in
                if let option = start.options.first(where: { $0.id == id }) {
                    start.pick(option)
                }
            }
        )
    }

    /// A segment's words: Current, Suggested, or the preset's name.
    static func label(of option: OnboardingStartOption) -> String {
        switch option {
        case .current:
            return L("onboarding.start_with.current", "Current")
        case .layout(let layout) where layout.starterTitle != nil:
            return L("onboarding.start_with.suggested", "Suggested")
        case .layout(let layout):
            return layout.displayName
        }
    }
}
