import AppKit

// 保存选中内容与原始底图，连续移动时不会反复截取已经合成的背景。
struct FloatingSelection {
    let content: Bitmap
    let background: Bitmap
    var origin: CGPoint
    let tool: PaintTool?
    var rotationCenter: CGPoint?
}

// 单次手势使用位图快照撤销；选区在松开鼠标后继续保留。
final class CanvasView: NSView {
    weak var editor: EditorController?
    var selection: CGRect? {
        didSet {
            if selection == nil { floatingSelection = nil }
            needsDisplay = true
            updateSelectionControls()
            editor?.updateStatus()
        }
    }
    private(set) var floatingSelection: FloatingSelection? {
        didSet { updateSelectionControls() }
    }
    private let rotationButton = SelectionRotationButton(frame: .zero)
    private var gestureBitmap: Bitmap?
    private var gestureShape: (content: Bitmap, origin: CGPoint)?
    private var gestureSelection: CGRect?
    private var gestureFloatingSelection: FloatingSelection?
    private var start: CGPoint = .zero
    private var previous: CGPoint = .zero
    private var moving = false
    private var selectionOrigin: CGPoint = .zero
    private var tracking: NSTrackingArea?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        rotationButton.target = self
        rotationButton.action = #selector(rotateBubble(_:))
        rotationButton.isHidden = true
        addSubview(rotationButton)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard let editor, let context = NSGraphicsContext.current?.cgContext else { return }
        let bitmap = editor.paintDocument.bitmap
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: bounds)
        NSColor.white.setFill()
        bounds.fill()
        let cell: CGFloat = 12
        NSColor(white: 0.94, alpha: 1).setFill()
        for row in Int(dirtyRect.minY / cell)...Int(dirtyRect.maxY / cell) {
            for column in Int(dirtyRect.minX / cell)...Int(dirtyRect.maxX / cell) where (row + column) % 2 == 0 {
                NSRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell).fill()
            }
        }
        context.saveGState()
        context.interpolationQuality = editor.zoom >= 1 ? .none : .high
        context.translateBy(x: 0, y: CGFloat(bitmap.height))
        context.scaleBy(x: 1, y: -1)
        context.draw(bitmap.image, in: CGRect(x: 0, y: 0, width: bitmap.width, height: bitmap.height))
        context.restoreGState()
        if let selection {
            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(2 / editor.zoom)
            context.stroke(selection)
            context.setStrokeColor(Theme.accent.cgColor)
            context.setLineWidth(1 / editor.zoom)
            context.setLineDash(phase: 0, lengths: [5 / editor.zoom, 4 / editor.zoom])
            context.stroke(selection)
        }
    }

    func makeFloatingSelection(content: Bitmap, background: Bitmap, at origin: CGPoint, tool: PaintTool? = nil, rotationCenter: CGPoint? = nil) {
        floatingSelection = FloatingSelection(content: content, background: background, origin: origin, tool: tool, rotationCenter: rotationCenter)
        selection = CGRect(origin: origin, size: CGSize(width: content.width, height: content.height))
    }

    func updateSelectionControls() {
        guard let editor, let selection, floatingSelection?.tool?.isBubble == true else {
            rotationButton.isHidden = true
            return
        }
        let visible = visibleRect.intersection(bounds)
        let diameter = 28 / editor.zoom
        guard visible.width >= diameter, visible.height >= diameter, visible.intersects(selection) else {
            rotationButton.isHidden = true
            return
        }
        let x = Swift.max(visible.minX, Swift.min(visible.maxX - diameter, selection.maxX - diameter / 2))
        let y = Swift.max(visible.minY, Swift.min(visible.maxY - diameter, selection.minY - diameter - 8 / editor.zoom))
        rotationButton.frame = CGRect(x: x, y: y, width: diameter, height: diameter)
        rotationButton.isHidden = false
    }

    @objc private func rotateBubble(_ sender: Any?) {
        finishGesture()
        guard let editor, let floating = floatingSelection, floating.tool?.isBubble == true else { return }
        let previous = editor.paintDocument.bitmap
        let content = floating.content.transformed(clockwise: true)
        let width = Swift.max(floating.background.width, content.width)
        let height = Swift.max(floating.background.height, content.height)
        do { try Bitmap.validate(width: width, height: height) }
        catch { window?.presentError(error); return }
        var background = floating.background
        if background.width != width || background.height != height {
            background = background.resized(width: width, height: height, scaleImage: false)
        }
        let center = floating.rotationCenter ?? CGPoint(x: floating.origin.x + CGFloat(floating.content.width) / 2,
                             y: floating.origin.y + CGFloat(floating.content.height) / 2)
        let origin = CGPoint(x: Swift.max(0, Swift.min(CGFloat(width - content.width), center.x - CGFloat(content.width) / 2)).rounded(),
                             y: Swift.max(0, Swift.min(CGFloat(height - content.height), center.y - CGFloat(content.height) / 2)).rounded())
        var bitmap = background
        bitmap.paste(content, at: origin)
        editor.paintDocument.bitmap = bitmap
        editor.paintDocument.commit(previous: previous, action: L("旋转气泡"), preserveSelection: true)
        makeFloatingSelection(content: content, background: background, at: origin, tool: floating.tool, rotationCenter: center)
        window?.makeFirstResponder(self)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: .zero, options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        addTrackingArea(tracking!)
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: editor?.tool == .text ? .iBeam : .crosshair) }
    override func mouseMoved(with event: NSEvent) { editor?.updateStatus(point: convert(event.locationInWindow, from: nil)) }
    override func mouseExited(with event: NSEvent) { editor?.updateStatus() }

    override func mouseDown(with event: NSEvent) {
        guard let editor else { return }
        window?.makeFirstResponder(self)
        let point = constrained(convert(event.locationInWindow, from: nil))
        start = point
        previous = point
        if editor.tool == .picker {
            if let color = editor.paintDocument.bitmap.color(at: point) { editor.chooseColor(color, remember: true) }
            return
        }
        if editor.tool == .text { editor.insertText(at: point); return }
        gestureBitmap = editor.paintDocument.bitmap
        gestureShape = nil
        gestureSelection = selection
        gestureFloatingSelection = floatingSelection
        if editor.tool == .selection {
            if let selection, selection.contains(point) {
                if floatingSelection == nil, let part = editor.paintDocument.bitmap.cropped(to: selection) {
                    var background = editor.paintDocument.bitmap
                    background.draw { context in
                        context.setFillColor(NSColor.white.cgColor)
                        context.fill(selection)
                    }
                    makeFloatingSelection(content: part, background: background, at: selection.origin)
                }
                moving = floatingSelection != nil
                selectionOrigin = selection.origin
            } else {
                floatingSelection = nil
                moving = false
                selection = CGRect(origin: point, size: .zero)
            }
            return
        }
        selection = nil
        if editor.tool == .fill {
            editor.paintDocument.bitmap.floodFill(at: point, color: editor.color)
        } else if [.brush, .pencil, .eraser].contains(editor.tool) {
            stroke(from: point, to: point)
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let editor, let snapshot = gestureBitmap else { return }
        var point = constrained(convert(event.locationInWindow, from: nil))
        if event.modifierFlags.contains(.shift) && (editor.tool.isShape || editor.tool.isLine) {
            let dx = point.x - start.x, dy = point.y - start.y
            if editor.tool.isLine {
                let length = hypot(dx, dy)
                let angle = (atan2(dy, dx) / (.pi / 4)).rounded() * (.pi / 4)
                point = CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
            } else {
                let length = Swift.max(abs(dx), abs(dy))
                point = CGPoint(x: start.x + (dx < 0 ? -length : length), y: start.y + (dy < 0 ? -length : length))
            }
        }
        if editor.tool == .selection {
            if moving, var floating = floatingSelection {
                let x = Swift.max(0, Swift.min(CGFloat(snapshot.width - floating.content.width), selectionOrigin.x + point.x - start.x)).rounded()
                let y = Swift.max(0, Swift.min(CGFloat(snapshot.height - floating.content.height), selectionOrigin.y + point.y - start.y)).rounded()
                floating.origin = CGPoint(x: x, y: y)
                floating.rotationCenter = nil
                var bitmap = floating.background
                bitmap.paste(floating.content, at: floating.origin)
                editor.paintDocument.bitmap = bitmap
                floatingSelection = floating
                selection = CGRect(origin: floating.origin, size: CGSize(width: floating.content.width, height: floating.content.height))
            } else {
                selection = rectangle(from: start, to: point).integral.intersection(bounds)
            }
        } else if [.brush, .pencil, .eraser].contains(editor.tool) {
            stroke(from: previous, to: point)
        } else if editor.tool.isShape || editor.tool.isLine {
            drawShape(to: point, on: snapshot)
        }
        previous = point
        needsDisplay = true
        editor.updateStatus(point: point)
    }

    override func mouseUp(with event: NSEvent) { finishGesture() }
    func finishGesture() {
        guard let editor, let snapshot = gestureBitmap else { return }
        let action = moving ? L("移动选区") : editor.tool.title
        let shape = gestureShape
        let shapeTool = editor.tool
        gestureBitmap = nil
        gestureShape = nil
        gestureFloatingSelection = nil
        gestureSelection = nil
        moving = false
        if let selection, selection.width < 1 || selection.height < 1 { self.selection = nil }
        editor.paintDocument.commit(previous: snapshot, action: action, preserveSelection: editor.tool == .selection)
        if let shape {
            editor.selectTool(.selection)
            makeFloatingSelection(content: shape.content, background: snapshot, at: shape.origin, tool: shapeTool)
        }
    }

    func cancelGesture() {
        if let snapshot = gestureBitmap {
            editor?.paintDocument.bitmap = snapshot
            selection = gestureSelection
            floatingSelection = gestureFloatingSelection
        } else {
            selection = nil
        }
        gestureBitmap = nil
        gestureShape = nil
        gestureSelection = nil
        gestureFloatingSelection = nil
        moving = false
        needsDisplay = true
    }
    private func constrained(_ point: CGPoint) -> CGPoint {
        CGPoint(x: Swift.max(0, Swift.min(bounds.width - 1, point.x)), y: Swift.max(0, Swift.min(bounds.height - 1, point.y)))
    }
    private func rectangle(from: CGPoint, to: CGPoint) -> CGRect {
        CGRect(x: Swift.min(from.x, to.x), y: Swift.min(from.y, to.y), width: abs(to.x - from.x), height: abs(to.y - from.y))
    }
    private func stroke(from: CGPoint, to: CGPoint) {
        guard let editor else { return }
        let eraser = editor.tool == .eraser
        let size: CGFloat = editor.tool == .pencil ? 1 : editor.brushSize
        let color = eraser ? NSColor.white : editor.color
        let pencil = editor.tool == .pencil
        editor.paintDocument.bitmap.draw { context in
            context.setShouldAntialias(!pencil)
            context.setStrokeColor(color.cgColor)
            context.setFillColor(color.cgColor)
            context.setLineWidth(size)
            if from == to {
                context.fillEllipse(in: CGRect(x: from.x - size / 2, y: from.y - size / 2, width: size, height: size))
            } else {
                context.move(to: from); context.addLine(to: to); context.strokePath()
            }
        }
    }
    private func drawShape(to point: CGPoint, on background: Bitmap) {
        guard let editor else { return }
        let rect = rectangle(from: start, to: point)
        let tool = editor.tool, color = editor.color, width = editor.brushSize, filled = editor.fillShapes
        let origin = start
        let arrowPadding: CGFloat = tool == .arrow || tool == .doubleArrow ? Swift.max(14, width * 3) : 0
        let padding = arrowPadding + width / 2 + 2
        let area = rect.insetBy(dx: -padding, dy: -padding).integral.intersection(bounds)
        guard area.width >= 1, area.height >= 1 else { return }
        // 单独绘制透明内容，移动时恢复底图，不带走形状下方的已有笔迹。
        var content = Bitmap(width: Int(area.width), height: Int(area.height), color: .clear)
        content.draw { context in
            context.translateBy(x: -area.minX, y: -area.minY)
            if tool.isLine {
                if tool == .dashedLine {
                    context.setLineDash(phase: 0, lengths: [Swift.max(8, width * 3), Swift.max(5, width * 2)])
                }
                context.setStrokeColor(color.cgColor)
                context.setLineWidth(width)
                context.move(to: origin); context.addLine(to: point)
                if tool == .arrow || tool == .doubleArrow {
                    let angle = atan2(point.y - origin.y, point.x - origin.x)
                    let length = Swift.max(14, width * 3)
                    func arrowHead(at tip: CGPoint, direction: CGFloat) {
                        context.move(to: CGPoint(x: tip.x - cos(direction - .pi / 6) * length, y: tip.y - sin(direction - .pi / 6) * length))
                        context.addLine(to: tip)
                        context.addLine(to: CGPoint(x: tip.x - cos(direction + .pi / 6) * length, y: tip.y - sin(direction + .pi / 6) * length))
                    }
                    arrowHead(at: point, direction: angle)
                    if tool == .doubleArrow { arrowHead(at: origin, direction: angle + .pi) }
                }
                context.strokePath()
            } else {
                ShapeRenderer.draw(tool, in: rect, context: context, filled: filled, color: color, lineWidth: width)
            }
        }
        gestureShape = (content: content, origin: area.origin)
        var bitmap = background
        bitmap.paste(content, at: area.origin)
        editor.paintDocument.bitmap = bitmap
    }
    override func keyDown(with event: NSEvent) {
        guard let editor else { return }
        if event.keyCode == 53 { cancelGesture(); return }
        if event.keyCode == 51 || event.keyCode == 117 { editor.deleteSelection(nil); return }
        let modifiers = event.modifierFlags.intersection([.command, .shift, .control, .option])
        if modifiers == .command && event.charactersIgnoringModifiers?.lowercased() == "k" {
            editor.cropSelection(nil)
            return
        }
        if modifiers == [.command, .shift] && event.charactersIgnoringModifiers?.lowercased() == "r" {
            editor.resizeCanvas(nil)
            return
        }
        if !event.modifierFlags.contains(.command), !event.modifierFlags.contains(.control),
           let character = event.charactersIgnoringModifiers?.uppercased(),
           let tool = PaintTool.allCases.first(where: { !$0.shortcut.isEmpty && $0.shortcut == character }) {
            editor.selectTool(tool); return
        }
        if event.characters == "[" { editor.setBrushSize(Swift.max(1, editor.brushSize - 1)); return }
        if event.characters == "]" { editor.setBrushSize(Swift.min(48, editor.brushSize + 1)); return }
        super.keyDown(with: event)
    }
    @objc func copy(_ sender: Any?) { editor?.copySelection(sender) }
    @objc func cut(_ sender: Any?) { editor?.cutSelection(sender) }
    @objc func paste(_ sender: Any?) { editor?.pasteImage(sender) }
    override func selectAll(_ sender: Any?) { editor?.selectAll(sender) }
}

final class CanvasStage: NSView {
    override var isFlipped: Bool { true }
    weak var editor: EditorController?
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .png, .tiff])
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self, NSImage.self], options: nil) ? .copy : []
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let board = sender.draggingPasteboard
        if let urls = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            for url in urls {
                NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
                    if let error { NSApplication.shared.presentError(error) }
                }
            }
            return true
        }
        return editor?.paste(from: board) ?? false
    }
}
