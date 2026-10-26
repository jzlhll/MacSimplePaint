import AppKit
import ImageIO
import UniformTypeIdentifiers

// 以左上角为原点的 RGBA 位图，统一处理绘制、取色和图像变换。
struct Bitmap: Equatable {
    static let maximumDimension = 8192
    static let maximumPixels = 32_000_000
    let width: Int
    let height: Int
    var pixels: [UInt8]

    init(width: Int, height: Int, color: NSColor = .white) {
        self.width = width
        self.height = height
        let rgba = Self.components(color)
        pixels = Array(repeating: 0, count: width * height * 4)
        for index in stride(from: 0, to: pixels.count, by: 4) {
            pixels[index] = rgba.0
            pixels[index + 1] = rgba.1
            pixels[index + 2] = rgba.2
            pixels[index + 3] = rgba.3
        }
    }

    static func validate(width: Int, height: Int) throws {
        guard width > 0, height > 0, width <= maximumDimension, height <= maximumDimension,
              width * height <= maximumPixels else {
            throw PaintError.message(L("画布的宽高须为 1–8192 像素，且总像素不能超过 3200 万。"))
        }
    }

    init(data: Data) throws {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw PaintError.message(L("无法读取这张图片，请选择 PNG、JPEG、TIFF、BMP、GIF、HEIC 或 WebP 图片。"))
        }
        try Self.validate(width: width, height: height)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Swift.max(width, height)
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw PaintError.message(L("图片解码失败。"))
        }
        self.init(width: image.width, height: image.height, color: .clear)
        // Core Graphics 的图像解码保持行顺序，后续绘制使用左上角坐标。
        pixels.withUnsafeMutableBytes { bytes in
            guard let context = Self.context(bytes.baseAddress, width: image.width, height: image.height) else { return }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
    }

    static func context(_ data: UnsafeMutableRawPointer?, width: Int, height: Int) -> CGContext? {
        CGContext(data: data, width: width, height: height, bitsPerComponent: 8,
                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
    }

    var image: CGImage {
        let data = Data(pixels) as CFData
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
                       provider: CGDataProvider(data: data)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }

    mutating func draw(_ body: (CGContext) -> Void) {
        let w = width
        let h = height
        pixels.withUnsafeMutableBytes { bytes in
            guard let context = Self.context(bytes.baseAddress, width: w, height: h) else { return }
            context.translateBy(x: 0, y: CGFloat(h))
            context.scaleBy(x: 1, y: -1)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            body(context)
        }
    }

    static func components(_ color: NSColor) -> (UInt8, UInt8, UInt8, UInt8) {
        let rgb = color.usingColorSpace(.deviceRGB) ?? .black
        let alpha = rgb.alphaComponent
        return (UInt8((rgb.redComponent * alpha * 255).rounded()),
                UInt8((rgb.greenComponent * alpha * 255).rounded()),
                UInt8((rgb.blueComponent * alpha * 255).rounded()), UInt8((alpha * 255).rounded()))
    }

    func color(at point: CGPoint) -> NSColor? {
        let x = Int(point.x), y = Int(point.y)
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        let index = (y * width + x) * 4
        let alpha = CGFloat(pixels[index + 3]) / 255
        guard alpha > 0 else { return .clear }
        return NSColor(deviceRed: CGFloat(pixels[index]) / 255 / alpha,
                       green: CGFloat(pixels[index + 1]) / 255 / alpha,
                       blue: CGFloat(pixels[index + 2]) / 255 / alpha, alpha: alpha)
    }

    mutating func floodFill(at point: CGPoint, color: NSColor) {
        let x = Int(point.x), y = Int(point.y)
        guard x >= 0, y >= 0, x < width, y < height else { return }
        let start = y * width + x
        let offset = start * 4
        let target = Array(pixels[offset..<(offset + 4)])
        let c = Self.components(color)
        let replacement = [c.0, c.1, c.2, c.3]
        guard target != replacement else { return }
        func matches(_ index: Int) -> Bool {
            let p = index * 4
            return pixels[p] == target[0] && pixels[p + 1] == target[1]
                && pixels[p + 2] == target[2] && pixels[p + 3] == target[3]
        }
        var stack = [start]
        while let seed = stack.popLast() {
            guard matches(seed) else { continue }
            let row = seed / width
            var left = seed % width
            while left > 0 && matches(row * width + left - 1) { left -= 1 }
            var column = left
            var above = false, below = false
            while column < width && matches(row * width + column) {
                let pixel = row * width + column
                pixels.replaceSubrange((pixel * 4)..<(pixel * 4 + 4), with: replacement)
                if row > 0 {
                    let match = matches(pixel - width)
                    if match && !above { stack.append(pixel - width) }
                    above = match
                }
                if row + 1 < height {
                    let match = matches(pixel + width)
                    if match && !below { stack.append(pixel + width) }
                    below = match
                }
                column += 1
            }
        }
    }

    func cropped(to rect: CGRect) -> Bitmap? {
        let area = rect.integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard area.width >= 1, area.height >= 1 else { return nil }
        var result = Bitmap(width: Int(area.width), height: Int(area.height), color: .clear)
        for y in 0..<result.height {
            let from = ((Int(area.minY) + y) * width + Int(area.minX)) * 4
            let to = y * result.width * 4
            result.pixels.replaceSubrange(to..<(to + result.width * 4), with: pixels[from..<(from + result.width * 4)])
        }
        return result
    }

    mutating func paste(_ bitmap: Bitmap, at point: CGPoint) {
        let image = bitmap.image
        draw { context in
            context.saveGState()
            context.translateBy(x: point.x, y: point.y + CGFloat(bitmap.height))
            context.scaleBy(x: 1, y: -1)
            context.draw(image, in: CGRect(x: 0, y: 0, width: bitmap.width, height: bitmap.height))
            context.restoreGState()
        }
    }

    func resized(width: Int, height: Int, scaleImage: Bool) -> Bitmap {
        var output = Bitmap(width: width, height: height, color: .clear)
        if scaleImage {
            let source = image
            output.draw { context in
                context.interpolationQuality = .high
                context.translateBy(x: 0, y: CGFloat(height))
                context.scaleBy(x: 1, y: -1)
                context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
        } else {
            output.paste(self, at: .zero)
        }
        return output
    }

    func transformed(clockwise: Bool = false, horizontal: Bool? = nil) -> Bitmap {
        let newWidth = horizontal == nil ? height : width
        let newHeight = horizontal == nil ? width : height
        var output = Bitmap(width: newWidth, height: newHeight, color: .clear)
        for y in 0..<height {
            for x in 0..<width {
                let dx: Int, dy: Int
                if let horizontal {
                    dx = horizontal ? width - 1 - x : x
                    dy = horizontal ? y : height - 1 - y
                } else {
                    dx = clockwise ? height - 1 - y : y
                    dy = clockwise ? x : width - 1 - x
                }
                let from = (y * width + x) * 4
                let to = (dy * newWidth + dx) * 4
                output.pixels[to..<(to + 4)] = pixels[from..<(from + 4)]
            }
        }
        return output
    }

    func encoded(type: String) throws -> Data {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type as CFString, 1, nil) else {
            throw PaintError.message(L("无法保存此图片格式。"))
        }
        // JPEG 和 BMP 没有透明通道，保存前合成为白色底图。
        var flattened = Bitmap(width: width, height: height)
        flattened.paste(self, at: .zero)
        let opaque = type == UTType.jpeg.identifier || type == UTType.bmp.identifier
        CGImageDestinationAddImage(destination, opaque ? flattened.image : image,
                                  [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw PaintError.message(L("图片写入失败。")) }
        return output as Data
    }
}

enum PaintError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let text): return text }
    }
}
