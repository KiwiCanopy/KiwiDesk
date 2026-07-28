/// Who reported a followed frame — shared by the ring's and the
/// sticky mark's `follow`. The follow guards differ by source
/// (#594): mid-animation the commanded per-tick frame leads
/// every echo on slow-AX apps, so it drives the ring and mark;
/// the echo paths stand down.
public enum FollowSource {
    /// A per-tick commanded frame from `AnimationEngine.apply`.
    case animationTick
    /// An AX `.windowMoved` / `.windowResized` echo.
    case axEcho
}
