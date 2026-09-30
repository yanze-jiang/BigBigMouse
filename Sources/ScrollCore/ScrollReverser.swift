import CoreGraphics

public enum ScrollReverser {
    /// Ordinary wheel mice send discrete scroll events. Trackpad scrolling,
    /// including momentum, is continuous and must pass through untouched.
    /// This is an event-format distinction, not a Bluetooth device identity.
    public static func apply(to event: CGEvent, enabled: Bool = true) {
        guard enabled,
              event.type == .scrollWheel,
              event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0,
              event.getIntegerValueField(.scrollWheelEventScrollPhase) == 0,
              event.getIntegerValueField(.scrollWheelEventMomentumPhase) == 0
        else { return }

        // Read all representations before writing: applications can use line,
        // pixel, or fractional deltas. Preserve horizontal motion and flags.
        let lines = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let points = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        let fractional = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: negated(lines))
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: negated(points))
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -fractional)
    }

    private static func negated(_ value: Int64) -> Int64 {
        value == .min ? .max : -value
    }
}
