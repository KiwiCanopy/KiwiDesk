import Foundation
import KiwiDeskCore

/// The keys step's last row introduces KiwiHub (#2515): its bound
/// sides in J K L order, the chord collapsed over them, and the
/// gateway treatment — the way to every shortcut the step leaves
/// out.
@MainActor
extension OnboardingKeys {
    static func kiwiHubFamily(layer: KeyLayer) -> OnboardingKeyFamily? {
        let bound = KiwiHubSide.allCases.compactMap { side in
            layer.bindings.first {
                $0.lua == side.lua && !$0.combo.isEmpty
            }.map { (side, $0.combo) }
        }
        guard !bound.isEmpty else { return nil }
        let combos = bound.map(\.1)
        let chord =
            combos.count == 1
            ? single(combo: combos[0]) : collapsed(combos) ?? listed(combos)
        guard let chord else { return nil }
        return OnboardingKeyFamily(
            id: "kiwihub",
            label: L(
                "onboarding.keys.kiwihub",
                "%1$@: %2$@",
                KiwiHubSide.panelName,
                joined(bound.map(\.0.title))
            ),
            chord: chord,
            isGateway: true,
            spoken: spoken(bound)
        )
    }

    /// Each side beside its own chord, so VoiceOver need not map
    /// J to Windows by position.
    private static func spoken(_ bound: [(KiwiHubSide, String)]) -> String {
        ([KiwiHubSide.panelName]
            + bound.map { side, combo in
                "\(side.title), \(rendered(combo: combo) ?? combo)"
            })
            .joined(separator: ". ")
    }

    /// The side names joined in the app's own language.
    private static func joined(_ names: [String]) -> String {
        let formatter = ListFormatter()
        formatter.locale = Locale(
            identifier: LocalizationManager.shared.effectiveLocale ?? "en"
        )
        return formatter.string(from: names) ?? names.joined(separator: ", ")
    }
}
