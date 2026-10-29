import AppKit

// 应用级偏好由所有文档共享；nil 外观让 AppKit 持续跟随系统变化。
enum AppearanceMode: String, CaseIterable {
    case dark, light, system
    static let didChange = Notification.Name("PaintAppearanceModeDidChange")
    static var current: AppearanceMode {
        AppearanceMode(rawValue: UserDefaults.standard.string(forKey: "appearanceMode") ?? "") ?? .system
    }
    var title: String {
        switch self {
        case .dark: return L("深色模式")
        case .light: return L("浅色模式")
        case .system: return L("跟随系统")
        }
    }
    func apply() {
        switch self {
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .system: NSApp.appearance = nil
        }
    }
    func select() {
        UserDefaults.standard.set(rawValue, forKey: "appearanceMode")
        apply()
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }
}

// 直接绘制动态颜色，避免 CGColor 缓存在图层上导致系统切换后不更新。
final class ThemeSurfaceView: NSView {
    private let color: NSColor
    init(color: NSColor) {
        self.color = color
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        bounds.fill()
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

final class AppearanceButton: NSButton {
    private let mode: AppearanceMode
    init(mode: AppearanceMode) {
        self.mode = mode
        super.init(frame: .zero)
        fixed(width: 24, height: 26)
        isBordered = false
        title = ""
        toolTip = mode.title
        setAccessibilityLabel(mode.title)
        target = self
        action = #selector(selectMode)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: AppearanceMode.didChange, object: nil)
        refresh()
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { NotificationCenter.default.removeObserver(self) }
    @objc private func selectMode() { mode.select() }
    @objc private func refresh() {
        setAccessibilityValue(mode == AppearanceMode.current ? L("已选择") : L("未选择"))
        needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        if mode == AppearanceMode.current || isHighlighted {
            Theme.toolSelectionBackground.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 2), xRadius: 5, yRadius: 5).fill()
        }
        let rect = NSRect(x: bounds.midX - 7, y: bounds.midY - 7, width: 14, height: 14)
        let block = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
        NSGraphicsContext.saveGraphicsState()
        block.addClip()
        (mode == .dark ? NSColor(hex: "171717") : NSColor.white).setFill()
        rect.fill()
        if mode == .system {
            NSColor(hex: "171717").setFill()
            let half = NSBezierPath()
            half.move(to: NSPoint(x: rect.minX, y: rect.minY))
            half.line(to: NSPoint(x: rect.minX, y: rect.maxY))
            half.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
            half.close()
            half.fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        Theme.secondary.setStroke()
        block.lineWidth = 0.75
        block.stroke()
        if window?.firstResponder === self {
            NSColor.keyboardFocusIndicatorColor.setStroke()
            let focus = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5)
            focus.lineWidth = 1
            focus.stroke()
        }
    }
}
