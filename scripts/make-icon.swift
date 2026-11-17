// Draws the Lumaware app icon (monitor with a sun) into an .iconset folder.
// Usage: swift scripts/make-icon.swift build/AppIcon.iconset
// The Makefile then runs `iconutil` to turn the folder into AppIcon.icns.
import Cocoa

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let s = CGFloat(px)
    func p(_ v: CGFloat) -> CGFloat { v * s / 100 }     // 100-unit design grid

    // Background tile
    let bg = NSBezierPath(roundedRect: NSRect(x: p(6), y: p(6), width: p(88), height: p(88)),
                          xRadius: p(20), yRadius: p(20))
    NSGradient(starting: NSColor(calibratedRed: 0.09, green: 0.12, blue: 0.22, alpha: 1),
               ending: NSColor(calibratedRed: 0.22, green: 0.36, blue: 0.62, alpha: 1))!
        .draw(in: bg, angle: 90)

    // Monitor
    let white = NSColor(calibratedWhite: 1, alpha: 0.95)
    white.setStroke()
    let screen = NSBezierPath(roundedRect: NSRect(x: p(20), y: p(36), width: p(60), height: p(42)),
                              xRadius: p(5), yRadius: p(5))
    screen.lineWidth = p(4.5)
    screen.stroke()
    let stand = NSBezierPath()
    stand.lineWidth = p(4.5)
    stand.lineCapStyle = .round
    stand.move(to: NSPoint(x: p(50), y: p(36))); stand.line(to: NSPoint(x: p(50), y: p(24)))
    stand.move(to: NSPoint(x: p(36), y: p(24))); stand.line(to: NSPoint(x: p(64), y: p(24)))
    stand.stroke()

    // Sun
    let sun = NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.30, alpha: 1)
    sun.setFill()
    sun.setStroke()
    let c = NSPoint(x: p(50), y: p(57))
    NSBezierPath(ovalIn: NSRect(x: c.x - p(6.5), y: c.y - p(6.5), width: p(13), height: p(13))).fill()
    let rays = NSBezierPath()
    rays.lineWidth = p(3)
    rays.lineCapStyle = .round
    for i in 0..<8 {
        let a = CGFloat(i) * .pi / 4
        rays.move(to: NSPoint(x: c.x + cos(a) * p(11), y: c.y + sin(a) * p(11)))
        rays.line(to: NSPoint(x: c.x + cos(a) * p(16), y: c.y + sin(a) * p(16)))
    }
    rays.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64),
    ("128x128", 128), ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512),
    ("512x512", 512), ("512x512@2x", 1024),
]
for (name, px) in sizes {
    try! render(px).write(to: URL(fileURLWithPath: "\(outDir)/icon_\(name).png"))
}
