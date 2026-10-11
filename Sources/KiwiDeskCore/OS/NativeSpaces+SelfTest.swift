extension NativeSpaces {
    /// The display-UUID symbol as `self_test` probes it (#1889).
    /// Liveness only: no public reader names a display's UUID.
    @MainActor
    static func selfTestProbes() -> [PrivatePathProbe] {
        [
            .read(displayUUIDResolution, home: "NativeSpaces") {
                let uuid = mainDisplayUUID()
                return PrivatePathVerify.answered(
                    uuid,
                    "main display \(uuid ?? "")"
                )
            }
        ]
    }
}
