import Foundation

extension HyperKeyRemap {
    /// Takes over a mapping another tool set that is exactly
    /// KiwiDesk's own entry for `want` (#2471). The user's consent
    /// writes the ownership record and nothing else, so `stop()`
    /// clears the entry as one KiwiDesk wrote; the shape only ever
    /// decides the offer, never ownership. The mapping is re-read
    /// here, since it may have changed since the offer, and any
    /// other mapping takes the ordinary `apply`.
    @MainActor
    static func claim(
        _ want: HyperSourceKey,
        on host: Host
    ) -> HyperKeyStatus {
        guard
            let listing = host.run(
                ["property", "--get", "UserKeyMapping"]
            )
        else { return .failed }
        let ours = pair(for: want)
        guard want != .f18, pairs(inHidutilOutput: listing) == [ours]
        else { return apply(want, on: host) }
        host.writeWritten(ours)
        return .on
    }
}
