import Foundation

/// The channel of a copy a package manager installs (#2909): no
/// Sparkle, since the manager's next switch would undo its install,
/// but the same What's new after an update as a Sparkle copy
/// (#2911), read from the bundle's own feed.
@MainActor
final class ManagedUpdater: AppUpdating {
    var canCheckForUpdates: Bool { false }
    func checkForUpdates() {}
    var updatePending: Bool { false }
    var onUpdatePendingChanged: () -> Void = {}
    let updates: UpdateStateStore
    let whatsNew: WhatsNewCoordinator?
    let autoInstall: AutoInstallSetting
    var onWillRelaunch: () -> Void = {}

    /// `manager` names who installs updates, for the footer and the
    /// automatic-install row.
    init(
        manager: String,
        host: Bundle = .main,
        record: WhatsNewRecord = WhatsNewRecord()
    ) {
        updates = UpdateStateStore(.managed(by: manager))
        autoInstall = .inert(.managed(by: manager))
        let feed = Self.feedURL(of: host)
        whatsNew = WhatsNewCoordinator(
            record: record,
            host: host,
            feedURL: { feed }
        )
    }

    /// The feed Sparkle would read: a `SUFeedURL` default first, as
    /// Sparkle resolves it, else the bundle's.
    static func feedURL(
        of host: Bundle,
        defaults: UserDefaults = .standard
    ) -> URL? {
        let spelled =
            defaults.string(forKey: "SUFeedURL")
            ?? host.object(forInfoDictionaryKey: "SUFeedURL") as? String
        return spelled.flatMap(URL.init(string:))
    }
}
