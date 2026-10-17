import Foundation

extension ServiceManager {
    /// Why a copy at `location` must not become the service, nil
    /// if it may (#2267): a translocated copy's path dies at
    /// relaunch, so the agent would never start again. A bare
    /// binary's path is stable and stays allowed.
    static func installRefusal(
        for location: RunningCopy.Location
    ) -> String? {
        switch location {
        case .bundled, .bare:
            return nil
        case .translocated:
            return "KiwiDesk is running from a temporary location "
                + "(opened from Downloads). Move KiwiDesk.app to "
                + "/Applications, open it from there, and run this "
                + "again."
        }
    }
}
