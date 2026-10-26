import AppKit

enum Theme {
    static let accent = NSColor(hex: "303030")
    static let accentPressed = NSColor(hex: "171717")
    static let selectionBorder = NSColor(hex: "666666")
    static let controlBackground = NSColor(hex: "F4F4F4")
    static let controlHover = NSColor(hex: "E8E8E8")
    static let toolSelectionBackground = NSColor(hex: "DDDDDD")
    static let ink = NSColor(hex: "272727")
    static let secondary = NSColor(hex: "858585")
    static let line = NSColor(hex: "E5E5E5")
    static let sliderProgress = NSColor(hex: "B5B5B5")
    static let workspace = NSColor(hex: "F2F2F2")
    static let palette = ["263843", "FFFFFF", "84909C", "E96563", "ED9A50", "E9C955",
                          "75AE72", "33998C", "63B7D0", "5685CA", "9880BC", "D685A5"]
}

extension NSColor {
    convenience init(hex: String) {
        let value = UInt32(hex.replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0
        self.init(srgbRed: CGFloat((value >> 16) & 255) / 255,
                  green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1)
    }
    var hex: String {
        let color = usingColorSpace(.sRGB) ?? .black
        return String(format: "%02X%02X%02X", Int((color.redComponent * 255).rounded()),
                      Int((color.greenComponent * 255).rounded()), Int((color.blueComponent * 255).rounded()))
    }
}

final class FlippedContainer: NSView {
    override var isFlipped: Bool { true }
}

extension NSView {
    func fixed(width: CGFloat? = nil, height: CGFloat? = nil) {
        translatesAutoresizingMaskIntoConstraints = false
        if let width { widthAnchor.constraint(equalToConstant: width).isActive = true }
        if let height { heightAnchor.constraint(equalToConstant: height).isActive = true }
    }
    func pin(to parent: NSView, inset: CGFloat = 0) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: inset),
            trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -inset),
            topAnchor.constraint(equalTo: parent.topAnchor, constant: inset),
            bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -inset)
        ])
    }
}

func label(_ text: String, size: CGFloat = 12, weight: NSFont.Weight = .regular, color: NSColor = Theme.ink) -> NSTextField {
    let field = NSTextField(labelWithString: text)
    field.font = .systemFont(ofSize: size, weight: weight)
    field.textColor = color
    return field
}

func stack(_ views: [NSView] = [], vertical: Bool = false, spacing: CGFloat = 8) -> NSStackView {
    let view = NSStackView(views: views)
    view.orientation = vertical ? .vertical : .horizontal
    view.alignment = vertical ? .leading : .centerY
    view.spacing = spacing
    return view
}

func separator(vertical: Bool = false) -> NSView {
    let view = NSView()
    view.wantsLayer = true
    view.layer?.backgroundColor = Theme.line.cgColor
    view.fixed(width: vertical ? 1 : nil, height: vertical ? nil : 1)
    return view
}

final class ActionButton: NSButton {
    enum Style { case standard, primary, quiet, selected, plain }
    var style: Style = .standard { didSet { needsDisplay = true } }
    var foregroundColor: NSColor? { didSet { needsDisplay = true } }
    var actionHandler: (() -> Void)?
    private var hovered = false
    private var hoverTracking: NSTrackingArea?

    init(_ title: String, symbol: String? = nil, symbolWeight: NSFont.Weight = .medium, action: @escaping () -> Void) {
        super.init(frame: .zero)
        self.title = title
        isBordered = false
        font = .systemFont(ofSize: 12, weight: .medium)
        if let symbol {
            image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)?
                .withSymbolConfiguration(.init(pointSize: 13, weight: symbolWeight))
            imagePosition = title.isEmpty ? .imageOnly : .imageLeading
        }
        actionHandler = action
        target = self
        self.action = #selector(invoke)
        setAccessibilityLabel(title)
    }
    required init?(coder: NSCoder) { fatalError() }
    override var intrinsicContentSize: NSSize {
        let size = (title as NSString).size(withAttributes: [.font: font ?? NSFont.systemFont(ofSize: 12)])
        return NSSize(width: title.isEmpty ? 34 : size.width + (image == nil ? 28 : 48), height: 34)
    }
    @objc private func invoke() { actionHandler?() }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTracking { removeTrackingArea(hoverTracking) }
        hoverTracking = NSTrackingArea(rect: .zero, options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        addTrackingArea(hoverTracking!)
    }
    override func mouseEntered(with event: NSEvent) { hovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovered = false; needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let rect = bounds.insetBy(dx: 1, dy: 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        let active = hovered || isHighlighted
        let foreground: NSColor
        context.saveGState()
        switch style {
        case .primary:
            foreground = .white
            if isEnabled { context.setShadow(offset: CGSize(width: 0, height: -1), blur: 4, color: Theme.accent.withAlphaComponent(0.18).cgColor) }
            (active ? Theme.accentPressed : Theme.accent).setFill()
            path.fill()
        case .plain:
            foreground = Theme.ink
            if active {
                Theme.controlBackground.setFill()
                path.fill()
            }
        case .selected:
            foreground = Theme.ink
            Theme.selectionBorder.setStroke()
            path.lineWidth = 2
            path.stroke()
        case .standard:
            foreground = Theme.ink
            (active ? Theme.controlBackground : NSColor.white).setFill()
            path.fill()
            (active ? Theme.accent.withAlphaComponent(0.4) : Theme.line).setStroke()
            path.lineWidth = 1
            path.stroke()
        case .quiet:
            foreground = Theme.ink
            (active ? Theme.controlHover : Theme.controlBackground).setFill()
            path.fill()
        }
        context.restoreGState()
        let tint = isEnabled ? (foregroundColor ?? foreground) : Theme.secondary.withAlphaComponent(0.45)
        let textAttributes: [NSAttributedString.Key: Any] = [.font: font ?? NSFont.systemFont(ofSize: 12), .foregroundColor: tint]
        let textSize = (title as NSString).size(withAttributes: textAttributes)
        let iconWidth: CGFloat = image == nil ? 0 : 15
        let gap: CGFloat = image != nil && !title.isEmpty ? 7 : 0
        let total = iconWidth + gap + textSize.width
        let rightToLeft = userInterfaceLayoutDirection == .rightToLeft
        var x = (bounds.width - total) / 2
        if let image {
            let tinted = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { iconRect in
                image.draw(in: iconRect)
                tint.setFill()
                iconRect.fill(using: .sourceIn)
                return true
            }
            // 保留符号的原始比例，避免减号等扁平图标被拉伸成粗块。
            let scale = Swift.min(15 / image.size.width, 15 / image.size.height)
            let iconSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
            let iconX = rightToLeft ? x + textSize.width + gap : x
            tinted.draw(in: NSRect(x: iconX + (15 - iconSize.width) / 2, y: (bounds.height - iconSize.height) / 2,
                                  width: iconSize.width, height: iconSize.height))
            if !rightToLeft { x += iconWidth + gap }
        }
        (title as NSString).draw(at: NSPoint(x: x, y: (bounds.height - textSize.height) / 2), withAttributes: textAttributes)
    }
}

// 沿用系统滑块的拖动、键盘和辅助功能行为，仅将轨道与滑块绘制为灰阶。
final class GrayscaleSliderCell: NSSliderCell {
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        let track = NSRect(x: rect.minX, y: rect.midY - 2, width: rect.width, height: 4)
        Theme.line.setFill()
        NSBezierPath(roundedRect: track, xRadius: 2, yRadius: 2).fill()
        let width = Swift.max(0, Swift.min(track.width, knobRect(flipped: flipped).midX - track.minX))
        (isEnabled ? Theme.sliderProgress : Theme.line).setFill()
        NSBezierPath(roundedRect: NSRect(x: track.minX, y: track.minY, width: width, height: track.height),
                     xRadius: 2, yRadius: 2).fill()
    }

    override func drawKnob(_ knobRect: NSRect) {
        let knob = NSBezierPath(ovalIn: knobRect.insetBy(dx: 1, dy: 1))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.cgContext.setShadow(offset: CGSize(width: 0, height: -1), blur: 3, color: NSColor.black.withAlphaComponent(0.12).cgColor)
        NSColor.white.setFill()
        knob.fill()
        NSGraphicsContext.restoreGraphicsState()
        Theme.line.setStroke()
        knob.lineWidth = 1
        knob.stroke()
    }
}

extension NSSlider {
    func applyGrayscaleStyle() {
        let styledCell = GrayscaleSliderCell()
        styledCell.minValue = minValue
        styledCell.maxValue = maxValue
        styledCell.doubleValue = doubleValue
        styledCell.isContinuous = isContinuous
        styledCell.target = target
        styledCell.action = action
        cell = styledCell
    }
}

final class SwatchButton: NSButton {
    var swatch: NSColor?
    var selected = false { didSet { needsDisplay = true } }
    var handler: (() -> Void)?
    init(color: NSColor?, size: CGFloat = 30) {
        swatch = color
        super.init(frame: .zero)
        fixed(width: size, height: size)
        isBordered = false
        target = self
        action = #selector(invoke)
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func invoke() { handler?() }
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
        let pixel = 1 / (window?.backingScaleFactor ?? 1)
        let rect = backingAlignedRect(bounds.insetBy(dx: 3, dy: 3), options: .alignAllEdgesNearest)
        let radius = Swift.min(8, rect.width / 4)

        // 用物理像素对齐的内描边代替跨边界描边，保持色块边缘清晰。
        func drawOutline(in rect: NSRect, radius: CGFloat, width: CGFloat, color: NSColor) {
            let outline = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            let innerRadius = Swift.max(0, radius - width)
            outline.append(NSBezierPath(roundedRect: rect.insetBy(dx: width, dy: width),
                                       xRadius: innerRadius, yRadius: innerRadius))
            outline.windingRule = .evenOdd
            color.setFill()
            outline.fill()
        }

        if let swatch {
            swatch.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            drawOutline(in: rect, radius: radius, width: pixel, color: NSColor.black.withAlphaComponent(0.16))
            if selected {
                let outlineRect = backingAlignedRect(bounds.insetBy(dx: 0.5, dy: 0.5), options: .alignAllEdgesNearest)
                drawOutline(in: outlineRect, radius: radius + 2.5, width: 1, color: Theme.accent)
            }
        } else {
            Theme.line.setStroke()
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: pixel / 2, dy: pixel / 2),
                                    xRadius: radius, yRadius: radius)
            path.lineWidth = pixel
            path.setLineDash([2, 2], count: 2, phase: 0)
            path.stroke()
        }
    }
}

// 工具图标直接以矢量路径绘制，与参考程序的图标形状、编排均独立。
final class ToolButton: NSButton {
    let tool: PaintTool
    private var showsTitle: Bool { !tool.isLine && !tool.isShape && tool != .more }
    var selected = false {
        didSet {
            needsDisplay = true
            setAccessibilityValue(selected ? L("已选择") : L("未选择"))
        }
    }
    private var hovered = false
    private var hoverTracking: NSTrackingArea?
    var handler: (() -> Void)?
    init(tool: PaintTool) {
        self.tool = tool
        super.init(frame: .zero)
        fixed(width: 44, height: showsTitle ? 46 : 36)
        isBordered = false
        title = ""
        toolTip = tool.title + (tool.shortcut.isEmpty ? "" : " · " + tool.shortcut)
        setAccessibilityLabel(tool.title)
        target = self
        action = #selector(invoke)
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func invoke() { handler?() }
    override var isFlipped: Bool { true }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTracking { removeTrackingArea(hoverTracking) }
        hoverTracking = NSTrackingArea(rect: .zero, options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        addTrackingArea(hoverTracking!)
    }
    override func mouseEntered(with event: NSEvent) { hovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovered = false; needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        if selected {
            Theme.toolSelectionBackground.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 11, yRadius: 11).fill()
        } else if hovered || isHighlighted {
            Theme.accent.withAlphaComponent(0.07).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 11, yRadius: 11).fill()
        }
        let tint = Theme.ink
        if showsTitle {
            let text = tool.title as NSString
            let weight: NSFont.Weight = selected ? .semibold : .regular
            var attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10, weight: weight), .foregroundColor: tint]
            let naturalWidth = text.size(withAttributes: attributes).width
            if naturalWidth > bounds.width - 4 {
                let size = Swift.max(7, 10 * (bounds.width - 4) / naturalWidth)
                attributes[.font] = NSFont.systemFont(ofSize: size, weight: weight)
            }
            let size = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: (bounds.width - size.width) / 2, y: 32), withAttributes: attributes)
        }
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.translateBy(x: 10, y: showsTitle ? 5 : (bounds.height - 25) / 2)
        context.setStrokeColor(tint.cgColor)
        context.setFillColor(tint.cgColor)
        context.setLineWidth(1.6)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        func lines(_ points: [CGPoint], close: Bool = false) {
            guard let first = points.first else { return }
            context.move(to: first)
            points.dropFirst().forEach { context.addLine(to: $0) }
            if close { context.closePath() }
            context.strokePath()
        }
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
        switch tool {
        case .brush:
            lines([p(10, 15), p(18, 3), p(21, 5), p(13, 17)], close: true)
            context.move(to: p(10, 14)); context.addCurve(to: p(4, 21), control1: p(2, 13), control2: p(10, 21))
            context.addCurve(to: p(13, 17), control1: p(9, 24), control2: p(14, 22)); context.strokePath()
        case .pencil:
            lines([p(4, 16), p(16, 4), p(21, 9), p(9, 21), p(3, 22)], close: true)
            lines([p(13, 7), p(18, 12)]); lines([p(4, 16), p(9, 21)])
        case .eraser:
            lines([p(4, 15), p(13, 4), p(22, 11), p(13, 22), p(10, 22)], close: true)
            lines([p(8, 11), p(17, 18)]); lines([p(10, 22), p(23, 22)])
        case .fill:
            lines([p(5, 8), p(13, 2), p(22, 12), p(13, 20), p(3, 11)], close: true)
            lines([p(6, 11), p(20, 11)]); lines([p(9, 6), p(6, 2)])
            context.fillEllipse(in: CGRect(x: 1, y: 19, width: 4, height: 5))
        case .picker:
            lines([p(8, 15), p(18, 5), p(21, 8), p(11, 18), p(5, 21), p(6, 17)], close: true)
            lines([p(13, 5), p(21, 13)])
        case .text:
            lines([p(4, 6), p(4, 3), p(22, 3), p(22, 6)])
            lines([p(13, 3), p(13, 22)]); lines([p(9, 22), p(17, 22)])
        case .line: lines([p(3, 21), p(22, 3)])
        case .dashedLine:
            context.setLineDash(phase: 0, lengths: [3, 3])
            lines([p(3, 21), p(22, 3)])
        case .doubleArrow:
            lines([p(3, 21), p(21, 3), p(12, 3)])
            lines([p(21, 3), p(21, 12)])
            lines([p(3, 12), p(3, 21), p(12, 21)])
        case .arrow: lines([p(3, 21), p(21, 4), p(11, 4)]); lines([p(21, 4), p(21, 14)])
        case .rectangle: context.stroke(CGRect(x: 3, y: 5, width: 19, height: 15))
        case .roundedRectangle:
            context.addPath(CGPath(roundedRect: CGRect(x: 3, y: 5, width: 19, height: 15), cornerWidth: 4, cornerHeight: 4, transform: nil)); context.strokePath()
        case .ellipse: context.strokeEllipse(in: CGRect(x: 3, y: 4, width: 19, height: 17))
        case .triangle: lines([p(12, 3), p(23, 21), p(2, 21)], close: true)
        case .more:
            for point in [p(5, 5), p(18, 5), p(5, 18), p(18, 18)] {
                context.strokeEllipse(in: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6))
            }
        case .selection:
            context.setLineDash(phase: 0, lengths: [3, 3])
            context.stroke(CGRect(x: 3, y: 3, width: 19, height: 19))
        default:
            ShapeRenderer.draw(tool, in: CGRect(x: 2, y: 2, width: 20, height: 20), context: context, filled: false, color: tint, lineWidth: 1.5)
        }
        context.restoreGState()
    }
}

// 两个紧凑选项共用一行，通过图形和小圆点表示形状模式。
final class ShapeStyleControl: NSView {
    var onChange: ((Bool) -> Void)?
    private var buttons: [ShapeStyleButton] = []
    private var filled = false
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let outline = ShapeStyleButton(filled: false) { [weak self] in self?.select(filled: false) }
        let fill = ShapeStyleButton(filled: true) { [weak self] in self?.select(filled: true) }
        buttons = [outline, fill]
        let row = stack(buttons, spacing: 4)
        row.distribution = .fillEqually
        addSubview(row)
        row.pin(to: self)
        buttons.forEach { $0.fixed(height: 46) }
        updateSelection()
    }
    required init?(coder: NSCoder) { fatalError() }
    private func select(filled: Bool) {
        self.filled = filled
        updateSelection()
        onChange?(filled)
    }
    private func updateSelection() {
        for (index, button) in buttons.enumerated() {
            let selected = (index == 1) == filled
            button.state = selected ? .on : .off
            button.needsDisplay = true
            button.setAccessibilityValue(selected ? L("已选择") : L("未选择"))
        }
    }
}

private final class ShapeStyleButton: NSButton {
    private let filled: Bool
    private let handler: () -> Void
    init(filled: Bool, action: @escaping () -> Void) {
        self.filled = filled
        handler = action
        super.init(frame: .zero)
        title = L(filled ? "填充" : "描边")
        toolTip = title
        setButtonType(.radio)
        isBordered = false
        setAccessibilityLabel(title)
        target = self
        self.action = #selector(invoke)
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isFlipped: Bool { true }
    @objc private func invoke() { handler() }
    override func draw(_ dirtyRect: NSRect) {
        let selected = state == .on
        let color = selected ? Theme.ink : Theme.secondary
        color.setFill()
        color.setStroke()
        let shape = NSBezierPath(roundedRect: NSRect(x: bounds.midX - 8, y: 5, width: 16, height: 14),
                                 xRadius: 3, yRadius: 3)
        if filled { shape.fill() }
        else { shape.lineWidth = 1.5; shape.stroke() }
        let weight: NSFont.Weight = selected ? .semibold : .regular
        var font = NSFont.systemFont(ofSize: 10, weight: weight)
        let naturalWidth = (title as NSString).size(withAttributes: [.font: font]).width
        if naturalWidth > bounds.width - 4 {
            font = .systemFont(ofSize: Swift.max(7, 10 * (bounds.width - 4) / naturalWidth), weight: weight)
        }
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let textSize = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(at: NSPoint(x: (bounds.width - textSize.width) / 2, y: 24), withAttributes: attributes)
        if selected {
            color.setFill()
            NSBezierPath(ovalIn: NSRect(x: bounds.midX - 2, y: 40, width: 4, height: 4)).fill()
        }
        if window?.firstResponder === self {
            NSColor.keyboardFocusIndicatorColor.setStroke()
            let focus = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
            focus.lineWidth = 1
            focus.stroke()
        }
    }
}

// 选区组的操作按钮使用无背景图标，不显示持续选中状态。
final class RailActionButton: NSButton {
    enum Kind { case clear, crop, more }
    private let kind: Kind
    private let handler: (NSButton) -> Void
    private let caption: String
    private let symbol: NSImage?
    init(kind: Kind, action: @escaping (NSButton) -> Void) {
        self.kind = kind
        handler = action
        let description: String
        switch kind {
        case .clear:
            caption = L("清空")
            description = L("清空画布")
            symbol = nil
        case .crop:
            caption = L("裁剪")
            description = L("裁剪到选区")
            symbol = NSImage(systemSymbolName: "crop", accessibilityDescription: nil)
        case .more:
            caption = L("更多")
            description = L("画布操作")
            symbol = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: nil)
        }
        super.init(frame: .zero)
        isBordered = false
        title = ""
        fixed(width: 44, height: 46)
        toolTip = description
        setAccessibilityLabel(description)
        target = self
        self.action = #selector(invoke)
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isFlipped: Bool { true }
    @objc private func invoke() { handler(self) }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let color = isEnabled ? (isHighlighted ? Theme.secondary : Theme.ink) : Theme.secondary.withAlphaComponent(0.45)
        context.saveGState()
        context.translateBy(x: 10, y: 4)
        if kind == .clear {
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(1.6)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            func lines(_ points: [CGPoint], close: Bool = false) {
                guard let first = points.first else { return }
                context.move(to: first)
                points.dropFirst().forEach { context.addLine(to: $0) }
                if close { context.closePath() }
                context.strokePath()
            }
            lines([CGPoint(x: 13, y: 12), CGPoint(x: 22, y: 3)])
            lines([CGPoint(x: 9, y: 11), CGPoint(x: 16, y: 18), CGPoint(x: 10, y: 23), CGPoint(x: 3, y: 16)], close: true)
            lines([CGPoint(x: 7, y: 15), CGPoint(x: 13, y: 21)])
            lines([CGPoint(x: 5, y: 5), CGPoint(x: 5, y: 9)])
            lines([CGPoint(x: 3, y: 7), CGPoint(x: 7, y: 7)])
            lines([CGPoint(x: 17, y: 23), CGPoint(x: 23, y: 23)])
        } else if let symbol {
            let scale = Swift.min(24 / symbol.size.width, 24 / symbol.size.height)
            let size = NSSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
            let image = NSImage(size: size, flipped: true) { rect in
                symbol.draw(in: rect)
                color.setFill()
                rect.fill(using: .sourceIn)
                return true
            }
            image.draw(in: NSRect(x: (24 - size.width) / 2, y: (25 - size.height) / 2, width: size.width, height: size.height))
        }
        context.restoreGState()
        let text = caption as NSString
        var attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: color]
        let width = text.size(withAttributes: attributes).width
        if width > bounds.width - 4 {
            attributes[.font] = NSFont.systemFont(ofSize: Swift.max(7, 10 * (bounds.width - 4) / width))
        }
        let size = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: (bounds.width - size.width) / 2, y: 32), withAttributes: attributes)
    }
}

// 旋转控件只覆盖在选区上，不写入画布像素或导出的图片。
final class SelectionRotationButton: NSButton {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        title = ""
        toolTip = L("顺时针旋转 90°")
        setAccessibilityLabel(L("旋转气泡"))
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        let inset = bounds.width / 28
        let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: inset, dy: inset))
        NSColor(hex: isHighlighted ? "E7B936" : "F5CF59").setFill()
        circle.fill()
        NSColor(hex: "C99E29").setStroke()
        circle.lineWidth = inset
        circle.stroke()
        if let image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .medium)) {
            let side = bounds.width * 0.52
            image.draw(in: NSRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side))
        }
    }
}
