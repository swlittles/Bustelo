import AppKit
// Usage: swift scripts/make-icon.swift <output-dir> [--development]
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let fm = FileManager.default
try fm.createDirectory(at: output, withIntermediateDirectories: true)
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor { NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a) }
let espresso = color(52, 30, 18), crema = color(255, 250, 238), red = color(206, 38, 48)

let logo = NSImage(size: NSSize(width: 1024, height: 1024))
logo.lockFocus()
let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
NSGradient(starting: color(255, 214, 72), ending: color(245, 166, 0))!.draw(in: tile, angle: -90)

// Steam
crema.withAlphaComponent(0.92).setStroke()
for x: CGFloat in [410, 512, 614] {
    let steam = NSBezierPath()
    steam.move(to: NSPoint(x: x, y: 650))
    steam.curve(to: NSPoint(x: x, y: 820), controlPoint1: NSPoint(x: x - 46, y: 710), controlPoint2: NSPoint(x: x + 46, y: 760))
    steam.lineWidth = 30; steam.lineCapStyle = .round; steam.stroke()
}

// Saucer
espresso.setFill()
NSBezierPath(ovalIn: NSRect(x: 232, y: 236, width: 560, height: 92)).fill()

// Handle, drawn first so the cup covers its inner half
espresso.setStroke()
let handle = NSBezierPath(ovalIn: NSRect(x: 628, y: 408, width: 170, height: 150))
handle.lineWidth = 42; handle.stroke()

// Cup with a red band
let cup = NSBezierPath()
cup.move(to: NSPoint(x: 292, y: 620))
cup.line(to: NSPoint(x: 732, y: 620))
cup.curve(to: NSPoint(x: 590, y: 300), controlPoint1: NSPoint(x: 732, y: 420), controlPoint2: NSPoint(x: 680, y: 300))
cup.line(to: NSPoint(x: 434, y: 300))
cup.curve(to: NSPoint(x: 292, y: 620), controlPoint1: NSPoint(x: 344, y: 300), controlPoint2: NSPoint(x: 292, y: 420))
cup.close()
espresso.setFill(); cup.fill()
NSGraphicsContext.saveGraphicsState()
cup.addClip()
red.setFill(); NSRect(x: 0, y: 468, width: 1024, height: 70).fill()
NSGraphicsContext.restoreGraphicsState()

if CommandLine.arguments.contains("--development") {
    let badge = NSBezierPath(roundedRect: NSRect(x: 560, y: 110, width: 340, height: 150), xRadius: 40, yRadius: 40)
    espresso.setFill(); badge.fill()
    NSString(string: "DEV").draw(at: NSPoint(x: 612, y: 128), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 100), .foregroundColor: crema])
}
logo.unlockFocus()

func png(_ image: NSImage, size: Int, url: URL) throws {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
    context.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}
try png(logo, size: 1024, url: output.appendingPathComponent("logo-1024.png"))
let iconset = output.appendingPathComponent("Bustelo.iconset")
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try png(logo, size: size, url: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try png(logo, size: size * 2, url: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
