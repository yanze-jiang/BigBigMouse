import CoreGraphics
import Foundation
import ScrollCore

struct ScrollReverserTests {
    private func wheel(continuous: Bool = false) throws -> CGEvent {
        let event = try require(CGEvent(
            scrollWheelEvent2Source: nil, units: .line, wheelCount: 2,
            wheel1: 3, wheel2: -2, wheel3: 0
        ))
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: continuous ? 1 : 0)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 27)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 2.5)
        event.flags = [.maskShift, .maskControl]
        return event
    }

    func reversesAllVerticalRepresentations() throws {
        let event = try wheel()
        ScrollReverser.apply(to: event)
        try expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == -3)
        try expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == -27)
        try expect(event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1) == -2.5)
        ScrollReverser.apply(to: event)
        try expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == 3)
        try expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == 27)
        try expect(event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1) == 2.5)
    }

    func preservesHorizontalDeltasAndModifierKeys() throws {
        let event = try wheel()
        let horizontalFields: [CGEventField] = [
            .scrollWheelEventDeltaAxis2, .scrollWheelEventPointDeltaAxis2,
            .scrollWheelEventFixedPtDeltaAxis2
        ]
        let before = horizontalFields.map { event.getDoubleValueField($0) }
        let flags = event.flags
        ScrollReverser.apply(to: event)
        try expect(horizontalFields.map { event.getDoubleValueField($0) } == before)
        try expect(event.flags == flags)
    }

    func leavesTrackpadAndMomentumEventsByteForByteUnchanged() throws {
        for momentum in [Int64(0), 1, 2, 3] {
            let event = try wheel(continuous: true)
            event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: momentum)
            let before = try require(event.data) as Data
            ScrollReverser.apply(to: event)
            try expect((event.data as Data?) == before)
        }
    }

    func preservesPhasedGesturesEvenIfContinuousFlagIsMissing() throws {
        for field: CGEventField in [.scrollWheelEventScrollPhase, .scrollWheelEventMomentumPhase] {
            let event = try wheel()
            event.setIntegerValueField(field, value: 1)
            let before = try require(event.data) as Data
            ScrollReverser.apply(to: event)
            try expect((event.data as Data?) == before)
        }
    }

    func disabledLeavesWheelEventUntouched() throws {
        let event = try wheel()
        let before = try require(event.data) as Data
        ScrollReverser.apply(to: event, enabled: false)
        try expect((event.data as Data?) == before)
    }

    func zeroVerticalDeltaDoesNotCreateMovement() throws {
        let event = try wheel()
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 0)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 0)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 0)
        ScrollReverser.apply(to: event)
        try expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == 0)
        try expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == 0)
        try expect(event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1) == 0)
    }

    func unrelatedEventsRemainUnchanged() throws {
        let event = try require(CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                                         mouseCursorPosition: CGPoint(x: 50, y: 80), mouseButton: .left))
        let before = try require(event.data) as Data
        ScrollReverser.apply(to: event)
        try expect((event.data as Data?) == before)
    }
}
