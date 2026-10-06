import KiwiDeskCore

/// The boot count in words — the one author of the sentence the
/// grant screen, the relaunched "What's new" and the slow-boot
/// notice read (design-decisions ▸ Boot: the wait is narrated,
/// never hidden; #1715).
@MainActor
enum BootCountText {
    /// Nil unless boot is still going through the open apps.
    static func line(for phase: BootPhase) -> String? {
        guard case .scanning(let scanned, let total) = phase else {
            return nil
        }
        return L(
            "onboarding.grant.arranging.count",
            "Going through your open apps: %1$d of %2$d",
            scanned,
            total
        )
    }
}
