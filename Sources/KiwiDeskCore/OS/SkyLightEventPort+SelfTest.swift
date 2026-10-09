extension SkyLightEventPort {
    /// The port's symbols as `self_test` probes them (#1889),
    /// reading the RUNNING port only: `shared` would install one.
    /// Its own file, so the owner file still spells each symbol
    /// once (`SkyLightEventPortSeamTests`).
    static func selfTestProbes() -> [PrivatePathProbe] {
        let home = "SkyLightEventPort"
        let running: @MainActor () -> PrivatePathVerdict = {
            active == nil
                ? .inconclusive("no event port is running")
                : .works("the running port uses it")
        }
        return [
            .read(
                "SLSGetEventPort",
                home: home,
                resolved: { getEventPort != nil },
                verify: running
            ),
            .read(
                "SLEventCreateNextEvent",
                home: home,
                resolved: { nextEvent != nil },
                verify: running
            ),
            .read(
                "_CFMachPortSetOptions",
                home: home,
                resolved: { setMachPortOptions != nil },
                verify: running
            ),
            .read(
                "SLSRegisterNotifyProc",
                home: home,
                resolved: { registerNotify != nil },
                verify: {
                    let codes = active?.registeredCodeCount ?? 0
                    return codes == 0
                        ? .inconclusive("no code is registered")
                        : .works("\(codes) codes registered")
                }
            ),
        ]
    }
}
