import Foundation

/// Whether something outside KiwiDesk installs its updates — a
/// package manager whose copy Sparkle must not replace (#2909).
enum ExternalUpdates {
    /// String default a package manager writes into KiwiDesk's
    /// domain, naming itself; the Home Manager module sets it.
    static let managerKey = "KiwiDeskUpdatesManagedBy"

    /// String default: the folder holding that manager's copy.
    /// Defaults outlive the module that wrote them (#2909).
    static let folderKey = "KiwiDeskUpdatesManagedFolder"

    /// The manager's name to show, or nil when Sparkle owns
    /// updates: "Nix" for a store-path bundle, else `declared`
    /// for a bundle inside `folder`.
    static func manager(
        declared: String?,
        folder: String?,
        bundlePath: String
    ) -> String? {
        if bundlePath.hasPrefix("/nix/store/") { return "Nix" }
        let named = declared?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard let named, !named.isEmpty, let folder, !folder.isEmpty
        else { return nil }
        let inside = URL(fileURLWithPath: folder).standardized.path
        let bundle = URL(fileURLWithPath: bundlePath).standardized.path
        return bundle.hasPrefix(inside + "/") ? named : nil
    }

    /// `manager(declared:folder:bundlePath:)` for the running copy.
    static func current(
        defaults: UserDefaults = .standard,
        bundlePath: String = Bundle.main.bundlePath
    ) -> String? {
        manager(
            // `string(forKey:)` would read a Bool as "1".
            declared: defaults.object(forKey: managerKey) as? String,
            folder: defaults.object(forKey: folderKey) as? String,
            bundlePath: bundlePath
        )
    }
}
