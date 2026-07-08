import Foundation

extension KiwiCore {
    /// Renames a saved profile and chases the references the
    /// core owns: the file + adopted name (`ProfileManager`)
    /// and the runtime native-Space bindings. The GUI-config
    /// copy of the bindings regenerates from the runtime map
    /// on the next `loadGuiConfig`, so the caller reloads and
    /// persists to make the sidecar/init.lua follow.
    public func renameProfile(
        from old: String,
        to new: String
    ) throws {
        try profiles.rename(from: old, to: new)
        for (number, name) in nativeSpaceBindings
        where name == old {
            nativeSpaceBindings[number] = new
        }
    }
}
