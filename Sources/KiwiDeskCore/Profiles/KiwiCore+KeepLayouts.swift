import Foundation

/// Keep Layout in Profile (#1179, re-ruled by #1790): the one
/// write both Keep rows take.
extension KiwiCore {
    /// Writes the live mode of each Space the live profile declares
    /// whose mode differs from the saved one, and nothing else —
    /// never which Spaces exist, their order or pins, and never a
    /// temporary or held Space. Non-adopting; an open draft's
    /// baseline follows through `onCapturedLive`. A no-op with no
    /// profile live or nothing to keep.
    public func keepLayouts() throws {
        guard let name = profiles.currentName else { return }
        var profile = try profiles.read(name: name)
        let declared = profile.declaredSpaces
        var kept = false
        for space in capturedSpaces
        where declared.contains(space.id)
            && (profile.spaceModes[space.id] ?? .bsp) != space.mode
        {
            profile.spaceModes[space.id] = space.mode
            kept = true
        }
        guard kept else { return }
        profile.savedAt = .now
        try profiles.write(profile)
        refreshConfigIssues()
        profiles.onCapturedLive(name, .layouts)
    }
}
