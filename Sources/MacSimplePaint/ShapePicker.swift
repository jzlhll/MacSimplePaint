import AppKit

// 用同一套路径预览附加形状，选择后直接回到画布绘制。
final class ShapePickerController: NSViewController {
    init(selected: PaintTool, lines: Bool = false, onPick: @escaping (PaintTool) -> Void) {
        super.init(nibName: nil, bundle: nil)
        let root = NSView()
        let content = stack([label(L(lines ? "更多线条" : "更多形状"), size: 13, weight: .semibold)], vertical: true, spacing: 8)
        let otherShapes = PaintTool.extraShapes
            .dropFirst(PaintTool.bubbleShapes.count + PaintTool.blockArrowShapes.count)
            .filter { $0 != .hexagon }
        let geometryRows = stride(from: 0, to: otherShapes.count, by: 4).map {
            Array(otherShapes[$0..<Swift.min($0 + 4, otherShapes.count)])
        }
        let shapeRows = [PaintTool.bubbleShapes + [.hexagon]] + Array(geometryRows.prefix(1))
            + [PaintTool.blockArrowShapes] + Array(geometryRows.dropFirst())
        let rows = lines ? stride(from: 0, to: PaintTool.lineTools.count, by: 4).map {
            Array(PaintTool.lineTools[$0..<Swift.min($0 + 4, PaintTool.lineTools.count)])
        } : shapeRows
        for tools in rows {
            let row = stack(tools.map { tool -> NSView in
                let button = ShapeChoiceButton(tool: tool, selected: selected == tool)
                button.handler = { onPick(tool) }
                return button
            }, spacing: 8)
            content.addArrangedSubview(row)
        }
        root.addSubview(content)
        content.pin(to: root, inset: 16)
        root.frame = NSRect(x: 0, y: 0, width: 344, height: 32 + 18 + rows.count * 52)
        view = root
    }
    required init?(coder: NSCoder) { fatalError() }
}

private final class ShapeChoiceButton: NSButton {
    let tool: PaintTool
    let selected: Bool
    var handler: (() -> Void)?
    private var hovered = false
    private var tracking: NSTrackingArea?
    init(tool: PaintTool, selected: Bool) {
        self.tool = tool
        self.selected = selected
        super.init(frame: .zero)
        fixed(width: 72, height: 44)
        isBordered = false
        title = ""
        target = self
        action = #selector(invoke)
        toolTip = tool.title
        setAccessibilityLabel(tool.title)
        setAccessibilityValue(selected ? L("已选择") : L("未选择"))
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func invoke() { handler?() }
    override var isFlipped: Bool { true }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(tracking!)
    }
    override func mouseEntered(with event: NSEvent) { hovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovered = false; needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        if selected {
            Theme.toolSelectionBackground.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 11, yRadius: 11).fill()
        } else if hovered || isHighlighted {
            Theme.controlHover.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 9, yRadius: 9).fill()
        }
        let color = Theme.ink
        if let context = NSGraphicsContext.current?.cgContext {
            if tool.isLine {
                LineRenderer.draw(tool, from: CGPoint(x: 15, y: 32), to: CGPoint(x: 57, y: 12), context: context, color: color, width: 1.3, preview: true)
                return
            }
            ShapeRenderer.draw(tool, in: CGRect(x: 19, y: (bounds.height - 29) / 2, width: 34, height: 29), context: context, filled: false, color: color, lineWidth: 1.3)
        }
    }
}
