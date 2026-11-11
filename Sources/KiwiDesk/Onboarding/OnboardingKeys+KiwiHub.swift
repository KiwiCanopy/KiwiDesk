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
            combo(lua: side.lua, in: layer).map { (side, $0) }
        }
        guard !bound.isEmpty else { return nil }
        let combos = bound.map(\.1)
        let chord =
            combos.count == 1
            ? single(combo: combos[0])
            : collapsed(combos) ?? tapsApart(combos) ?? listed(combos)
        guard let chord else { return nil }
        return OnboardingKeyFamily(
            id: "kiwihub",
            label: introduced(LocalizedList.join(bound.map(\.0.title))),
            chord: chord,
            isGateway: true,
            spoken: introduced(
                LocalizedList.join(
                    bound.map { side, combo in
                        L(
                            "onboarding.keys.kiwihub.side",
                            "%1$@ %2$@",
                            side.title,
                            rendered(combo: combo).map(
                                SidedChordWords.label
                            ) ?? combo
                        )
                    }
                )
            )
        )
    }

    /// The chords collapsed over their shared modifiers on one
    /// keycap, at the first chord's place, and each modifier tap on
    /// a keycap of its own in side order — `⌃⌥ J K L` and a `⌘⌘`
    /// the user set (#1229); nil where no tap stands apart or the
    /// chords share no prefix.
    private static func tapsApart(_ combos: [String]) -> OnboardingChord? {
        let isTap = { KeyCombo.parse($0)?.isTap == true }
        let chords = combos.filter { !isTap($0) }
        guard chords.count > 1, chords.count < combos.count,
            let shared = collapsed(chords)
        else { return nil }
        var keycaps: [String] = []
        for combo in combos {
            if !isTap(combo) {
                if combo == chords[0] { keycaps.append(shared.glyphs) }
            } else if let tap = rendered(combo: combo) {
                keycaps.append(tap)
            }
        }
        return .mixed(keycaps)
    }

    /// KiwiHub's name before what follows it — the row's sides,
    /// or for VoiceOver each side beside its own chord, so a key's
    /// meaning is never left to position.
    private static func introduced(_ sides: String) -> String {
        L(
            "onboarding.keys.kiwihub",
            "%1$@: %2$@",
            KiwiHubSide.panelName,
            sides
        )
    }
}
