import AppKit

// Original vector artwork, drawn at each native resolution. The monochrome
// mouse matches the menu bar's visual language without embedding an SF Symbol
// as the application's brand artwork.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let transform = AffineTransform(scale: CGFloat(pixels) / 1024)
        (transform as NSAffineTransform).concat()

        NSColor(calibratedWhite: 0.95, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 200, yRadius: 200).fill()
        NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
        let mouse = NSBezierPath()
        mouse.move(to: NSPoint(x: 512, y: 814))
        mouse.curve(to: NSPoint(x: 304, y: 596),
                    controlPoint1: NSPoint(x: 373, y: 814), controlPoint2: NSPoint(x: 304, y: 728))
        mouse.line(to: NSPoint(x: 304, y: 432))
        mouse.curve(to: NSPoint(x: 512, y: 210),
                    controlPoint1: NSPoint(x: 304, y: 289), controlPoint2: NSPoint(x: 383, y: 210))
        mouse.curve(to: NSPoint(x: 720, y: 432),
                    controlPoint1: NSPoint(x: 641, y: 210), controlPoint2: NSPoint(x: 720, y: 289))
        mouse.line(to: NSPoint(x: 720, y: 596))
        mouse.curve(to: NSPoint(x: 512, y: 814),
                    controlPoint1: NSPoint(x: 720, y: 728), controlPoint2: NSPoint(x: 651, y: 814))
        mouse.close()
        mouse.fill()

        // A short center seam and wheel are the only internal details.
        NSColor(calibratedWhite: 0.95, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(x: 499, y: 693, width: 26, height: 121)).fill()
        NSBezierPath(roundedRect: NSRect(x: 484, y: 592, width: 56, height: 136), xRadius: 28, yRadius: 28).fill()
        NSGraphicsContext.restoreGraphicsState()

        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
    }
}
