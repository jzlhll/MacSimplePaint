import AppKit

// 将银杏叶画笔原图制作成统一白底的 macOS 圆角图标。
let output = CommandLine.arguments[1]
let source = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "Resources/AppIcon-source.png"
guard let artwork = NSImage(contentsOfFile: source) else {
    fatalError("Cannot load icon artwork: " + source)
}
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        graphics.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        graphics.imageInterpolation = .high
        let tile = NSRect(x: 76, y: 76, width: 872, height: 872)
        let background = NSBezierPath(roundedRect: tile, xRadius: 190, yRadius: 190)
        NSColor.white.setFill()
        background.fill()
        background.addClip()
        artwork.draw(in: tile, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(output)/icon_\(size)x\(size)\(suffix).png"))
    }
}
