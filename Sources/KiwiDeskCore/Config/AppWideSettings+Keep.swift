import Foundation

extension AppWideSettings {
    /// The app-wide values as `gui.json` stores them, group by
    /// group (#1685): the keep document's `app_wide` root, so a
    /// change report names a value by its stored key.
    /// `AppWideKeepGroupsTests` holds every member to a leaf here.
    var groupsJSON: JSONValue {
        let groups = Groups(
            refusal: refusal,
            quit: quit,
            desktop: desktop,
            space: space,
            mode: mode,
            kiwivision: vision,
            hyper: hyper,
            kiwihub: kiwihub,
            modifier: modifier
        )
        return JSONValue(encoding: groups) ?? .object([:])
    }

    private struct Groups: Encodable {
        let refusal: Refusal
        let quit: Quit
        let desktop: Desktop
        let space: Space
        let mode: Mode
        let kiwivision: Vision
        let hyper: Hyper
        let kiwihub: KiwiHub
        let modifier: Modifier
    }
}
