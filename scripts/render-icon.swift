import AppKit

// Original vector artwork. Regenerate the committed PNG/ICNS with build-icon.sh.
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "dist/AppIcon.iconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
}
func drawIcon() {
    let tile = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 192, yRadius: 192)
    NSGradient(starting: color(0.025, 0.13, 0.22), ending: color(0.07, 0.48, 0.53))!.draw(in: tile, angle: 65)
    color(1, 1, 1, 0.12).setStroke()
    tile.lineWidth = 3; tile.stroke()

    // Screen and tapered base, with room for the speaker to read at small sizes.
    let screen = NSBezierPath(roundedRect: NSRect(x: 249, y: 383, width: 526, height: 334), xRadius: 32, yRadius: 32)
    color(0.015, 0.11, 0.17, 0.5).setFill(); screen.fill()
    color(0.91, 0.99, 0.98).setStroke(); screen.lineWidth = 25; screen.stroke()
    let base = NSBezierPath()
    base.move(to: NSPoint(x: 248, y: 390))
    base.line(to: NSPoint(x: 776, y: 390))
    base.line(to: NSPoint(x: 824, y: 322))
    base.curve(to: NSPoint(x: 802, y: 292), controlPoint1: NSPoint(x: 833, y: 306), controlPoint2: NSPoint(x: 823, y: 292))
    base.line(to: NSPoint(x: 222, y: 292))
    base.curve(to: NSPoint(x: 200, y: 322), controlPoint1: NSPoint(x: 201, y: 292), controlPoint2: NSPoint(x: 191, y: 306))
    base.close()
    color(0.91, 0.99, 0.98).setFill(); base.fill()
    color(0.04, 0.31, 0.37).setFill()
    NSBezierPath(roundedRect: NSRect(x: 440, y: 342, width: 144, height: 13), xRadius: 6, yRadius: 6).fill()

    color(0.91, 0.99, 0.98).setFill()
    NSBezierPath(roundedRect: NSRect(x: 407, y: 513, width: 45, height: 62), xRadius: 8, yRadius: 8).fill()
    let speaker = NSBezierPath()
    speaker.move(to: NSPoint(x: 445, y: 574))
    speaker.line(to: NSPoint(x: 501, y: 615))
    speaker.line(to: NSPoint(x: 501, y: 473))
    speaker.line(to: NSPoint(x: 445, y: 514))
    speaker.close(); speaker.fill()
    color(0.62, 0.96, 0.88).setStroke()
    for radius: CGFloat in [62, 103] {
        let wave = NSBezierPath()
        wave.lineWidth = 19; wave.lineCapStyle = .round
        wave.appendArc(withCenter: NSPoint(x: 506, y: 544), radius: radius, startAngle: -46, endAngle: 46, clockwise: false)
        wave.stroke()
    }
}

let images: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]
for (name, size) in images {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current!.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    NSGraphicsContext.current!.imageInterpolation = .high
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
}
