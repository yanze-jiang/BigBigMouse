import ApplicationServices
import ScrollCore

@MainActor
final class ScrollEventTap {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    var onInterruption: (() -> Void)?

    func start() -> Bool {
        if let tap, CFMachPortIsValid(tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
            return CGEvent.tapIsEnabled(tap: tap)
        }
        stop()

        let mask = CGEventMask(1) << CGEventType.scrollWheel.rawValue
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                // The source is installed exclusively on the main run loop.
                MainActor.assumeIsolated {
                    let owner = Unmanaged<ScrollEventTap>.fromOpaque(context).takeUnretainedValue()
                    if type == .tapDisabledByTimeout {
                        if let tap = owner.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                    } else if type == .tapDisabledByUserInput {
                        // Defer any teardown until this callback has returned.
                        DispatchQueue.main.async { [weak owner] in owner?.onInterruption?() }
                    } else if type == .scrollWheel {
                        ScrollReverser.apply(to: event)
                    }
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        guard let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
            CFMachPortInvalidate(newTap)
            return false
        }
        tap = newTap
        source = newSource
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        return CGEvent.tapIsEnabled(tap: newTap)
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            CFRunLoopSourceInvalidate(source)
        }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil
        tap = nil
    }
}
