import Foundation

/// Whether something outside KiwiDesk installs its updates — a
/// package manager whose copy Sparkle must not replace (#2909).
enum ExternalUpdates {
    /// Defaults key a package manager writes into KiwiDesk's
    /// domain, naming itself; the Home Manager module sets it.
    static let managerKey = "KiwiDeskUpdatesManagedBy"

    /// The manager's name to show, or nil when Sparkle owns
    /// updates. A store-path bundle is Nix's even without the
    /// key; a Home Manager COPY is outside the store, so only the
    /// key can name it.
    static func manager(
        declared: String?,
        bundlePath: String
    ) -> String? {
        let named = declared?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if let named, !named.isEmpty { return named }
        return bundlePath.hasPrefix("/nix/store/") ? "Nix" : nil
    }

    /// `manager(declared:bundlePath:)` for the running copy.
    static func current() -> String? {
        manager(
            declared: UserDefaults.standard.string(forKey: managerKey),
            bundlePath: Bundle.main.bundlePath
        )
    }
}
