import Foundation

/// A press's Lua call scope for KeybindingManager (#184): the one
/// place `isFiring` is raised.
extension KeybindingManager {
    /// Runs `ref` inside a fire's scope (#184): the one place
    /// `isFiring` is raised for a press. The error a failing call
    /// returns, nil for none.
    func call(ref: Int32) -> LuaError? {
        guard let lua else { return nil }
        let wasFiring = isFiring
        isFiring = true
        defer { isFiring = wasFiring }
        if case .failure(let error) = lua.call(ref: ref) { return error }
        return nil
    }

    #if DEBUG
        /// Test-only: runs `body` inside a fire's scope (#804).
        func simulatingFire(_ body: () -> Void) {
            let wasFiring = isFiring
            isFiring = true
            defer { isFiring = wasFiring }
            body()
        }
    #endif
}
