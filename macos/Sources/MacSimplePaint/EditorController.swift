import AppKit
import UniformTypeIdentifiers

// 组装独立文档窗口，连接工具、颜色、文件和画布操作。
final class EditorController: NSWindowController, NSWindowDelegate, NSMenuItemValidation, NSTextFieldDelegate {
    let paintDocument: PaintDocument
    let canvas = CanvasView()
    let stage = CanvasStage(frame: .zero)
    let scrollView = NSScrollView()
    var tool: PaintTool = .brush
    var color = NSColor(hex: Theme.palette[0])
    var brushSize: CGFloat = 6
    var fillShapes = false
    var fontSize: CGFloat = 32
    private var textFontFamily: String?
    private let railWidth: CGFloat = 113.4
    private let inspectorWidth: CGFloat = 129
    private let brushControls = stack([], vertical: true, spacing: 6)
    private let textControls = stack([], vertical: true, spacing: 6)
    private var drawingFont: NSFont {
        if let textFontFamily,
           let font = NSFontManager.shared.font(withFamily: textFontFamily, traits: [], weight: 5, size: fontSize) {
            return font
        }
        return .systemFont(ofSize: fontSize)
    }
    var zoom: CGFloat = 0.75
    private var toolButtons: [PaintTool: ToolButton] = [:]
    private var paletteButtons: [SwatchButton] = []
    private var recentButtons: [SwatchButton] = []
    private var recentColors: [String] = []
    private let currentSwatch = SwatchButton(color: NSColor(hex: Theme.palette[0]), size: 40)
    private let hexField = NSTextField(string: "#" + Theme.palette[0])
    private let sizeSlider = NSSlider(value: 6, minValue: 1, maxValue: 48, target: nil, action: nil)
    private let sizeLabel = label("6 px", size: 12, weight: .medium, color: Theme.sizeText)
    private let fontSizeLabel = label("32 px", size: 12, weight: .medium, color: Theme.sizeText)
    private let statusLabel = label(L("画笔 · 拖动开始绘画"), size: 11, color: Theme.secondary)
    private let tipLabel = label("", size: 10, color: Theme.secondary)
    private var tipTimer: Timer?
    private let usageTips = [
        L("⌘V 可直接粘贴图片"),
        L("按 [ / ] 调整笔画粗细"),
        L("将图片拖入窗口即可打开"),
        L("选中的内容可以连续拖动"),
        L("按住 Shift 约束形状比例或角度"),
        L("⌘Z 撤销，⇧⌘Z 重做")
    ]
    private let dimensionLabel = label("1200 × 800 px", size: 11, color: Theme.secondary)
    private let zoomLabel = label("75%", size: 11, weight: .medium)
    private let toolLabel = label(L("画笔"), size: 15, weight: .semibold)
    private let toolTaglineLabel = label(PaintTool.brush.tagline, size: 10, color: Theme.secondary)
    private var boundsObserver: NSObjectProtocol?
    private var undoObservers: [NSObjectProtocol] = []
    private var historyButtons: [NSButton] = []
    private var cropButton: NSButton?
    private var hasShownWindow = false
    private var shapePopover: NSPopover?
    private let documentNameField = NSTextField(labelWithString: "")
    private let documentExtensionLabel = label("", size: 11, color: Theme.secondary)
    private var renameButton: ActionButton?
    private let headerView = NSView()
    private var renameSourceURL: URL?
    private var isEditingDocumentName = false

    init(document: PaintDocument) {
        paintDocument = document
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1320, height: 900),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        super.init(window: window)
        window.minSize = NSSize(width: 980, height: 760)
        window.title = L("轻绘")
        window.backgroundColor = Theme.panel
        window.contentView = ThemeSurfaceView(color: Theme.panel)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.delegate = self
        window.center()
        canvas.editor = self
        stage.editor = self
        let storedColors = UserDefaults.standard.stringArray(forKey: "recentCustomColors") ?? []
        recentColors = Array(storedColors.filter {
            $0.count == 6 && UInt32($0, radix: 16) != nil
        }.prefix(3))
        if recentColors != storedColors {
            UserDefaults.standard.set(recentColors, forKey: "recentCustomColors")
        }
        buildInterface()
        refreshColors()
        refreshCanvas()
        window.makeFirstResponder(canvas)
        scrollView.contentView.postsBoundsChangedNotifications = true
        boundsObserver = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView, queue: .main) { [weak self] _ in self?.layoutCanvas() }
        for name in [Notification.Name.NSUndoManagerDidCloseUndoGroup, .NSUndoManagerDidUndoChange, .NSUndoManagerDidRedoChange] {
            undoObservers.append(NotificationCenter.default.addObserver(forName: name, object: document.undoManager,
                queue: .main) { [weak self] _ in self?.updateHistory() })
        }
    }

    required init?(coder: NSCoder) { fatalError() }
    deinit {
        tipTimer?.invalidate()
        if let boundsObserver { NotificationCenter.default.removeObserver(boundsObserver) }
        undoObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        if !hasShownWindow {
            hasShownWindow = true
            window?.contentView?.layoutSubtreeIfNeeded()
            fitCanvas(nil)
            window?.makeFirstResponder(canvas)
            if NSApplication.shared.isActive { showRandomTip() }
        }
    }

    func showRandomTip() {
        tipTimer?.invalidate()
        guard let message = usageTips.filter({ $0 != tipLabel.stringValue }).randomElement() else { return }
        tipLabel.stringValue = message
        tipLabel.isHidden = false
        let timer = Timer(timeInterval: 45, repeats: false) { [weak self] _ in self?.hideTip() }
        tipTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func hideTip() {
        tipTimer?.invalidate()
        tipTimer = nil
        tipLabel.isHidden = true
    }

    func windowWillClose(_ notification: Notification) { hideTip() }

    override func windowTitle(forDocumentDisplayName displayName: String) -> String {
        displayName + (paintDocument.fileURL == nil || paintDocument.isDocumentEdited ? " *" : "")
    }

    override func synchronizeWindowTitleWithDocumentName() {
        super.synchronizeWindowTitleWithDocumentName()
        updateDocumentTitle()
    }

    private func updateDocumentTitle() {
        guard !isEditingDocumentName else { return }
        documentNameField.stringValue = windowTitle(forDocumentDisplayName: paintDocument.displayName)
        documentNameField.toolTip = paintDocument.fileURL?.path ?? paintDocument.displayName
        documentNameField.isEditable = false
        documentNameField.isSelectable = false
        documentNameField.drawsBackground = false
        documentNameField.textColor = paintDocument.fileURL == nil ? Theme.secondary : Theme.documentName
        documentNameField.alignment = .right
        documentNameField.lineBreakMode = .byTruncatingMiddle
        documentExtensionLabel.isHidden = true
        renameButton?.isHidden = paintDocument.fileURL == nil
        renameButton?.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .regular))
        renameButton?.toolTip = L("重命名")
        renameButton?.setAccessibilityLabel(L("重命名"))
    }

    private func beginRename() {
        guard let url = paintDocument.fileURL, let window, window.attachedSheet == nil else { return }
        canvas.finishGesture()
        isEditingDocumentName = true
        renameSourceURL = url
        documentNameField.stringValue = url.deletingPathExtension().lastPathComponent
        documentNameField.isEditable = true
        documentNameField.isSelectable = true
        documentNameField.drawsBackground = true
        documentNameField.backgroundColor = Theme.controlBackground
        documentNameField.alignment = .left
        documentNameField.lineBreakMode = .byClipping
        documentExtensionLabel.stringValue = url.pathExtension.isEmpty ? "" : "." + url.pathExtension
        documentExtensionLabel.isHidden = url.pathExtension.isEmpty
        renameButton?.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
        renameButton?.toolTip = L("确认")
        renameButton?.setAccessibilityLabel(L("确认"))
        documentNameField.selectText(nil)
    }

    private func finishRename(cancelled: Bool = false) {
        guard isEditingDocumentName else { return }
        let name = documentNameField.stringValue
        let source = renameSourceURL
        renameSourceURL = nil
        isEditingDocumentName = false
        window?.makeFirstResponder(canvas)
        do {
            if !cancelled, source == paintDocument.fileURL { try paintDocument.renameFile(to: name) }
            synchronizeWindowTitleWithDocumentName()
        } catch {
            updateDocumentTitle()
            window?.presentError(error)
        }
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        if notification.object as? NSTextField === documentNameField { finishRename() }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === documentNameField else { return false }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            finishRename(cancelled: true)
            return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            finishRename()
            return true
        }
        return false
    }

    private func configureHeader() {
        guard let window, let root = window.contentView else { return }
        let toolbar = NSToolbar(identifier: "paint.header")
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.showsBaselineSeparator = false
        window.toolbarStyle = .unified
        window.toolbar = toolbar
        let newButton = ActionButton(L("新建"), symbol: "plus") { NSDocumentController.shared.newDocument(nil) }
        let openButton = ActionButton(L("打开"), symbol: "folder") { NSDocumentController.shared.openDocument(nil) }
        let saveButton = ActionButton(L("保存"), symbol: "square.and.arrow.down") { [weak self] in self?.paintDocument.save(nil) }
        let undo = ActionButton("", symbol: "arrow.uturn.backward") { [weak self] in self?.undo(nil) }
        undo.toolTip = L("撤销 · ⌘Z"); undo.setAccessibilityLabel(L("撤销"))
        let redo = ActionButton("", symbol: "arrow.uturn.forward") { [weak self] in self?.redo(nil) }
        redo.toolTip = L("重做 · ⇧⌘Z"); redo.setAccessibilityLabel(L("重做"))
        undo.style = .quiet
        redo.style = .quiet
        historyButtons = [undo, redo]
        let actions = stack([newButton, openButton, saveButton, undo, redo], spacing: 8)
        let edit = ActionButton("", symbol: "square.and.pencil", symbolWeight: .regular) { [weak self] in
            guard let self else { return }
            if self.isEditingDocumentName { self.finishRename() }
            else { self.beginRename() }
        }
        edit.style = .plain
        edit.foregroundColor = Theme.documentName
        edit.fixed(width: 24, height: 28)
        renameButton = edit
        documentNameField.font = .systemFont(ofSize: 13, weight: .medium)
        documentNameField.textColor = Theme.secondary
        documentNameField.isBezeled = false
        documentNameField.focusRingType = .none
        documentNameField.delegate = self
        documentNameField.cell?.isScrollable = true
        documentNameField.cell?.wraps = false
        documentNameField.setAccessibilityLabel(L("文件名"))
        documentNameField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let name = stack([documentNameField, documentExtensionLabel, edit], spacing: 5)
        name.detachesHiddenViews = true
        let header = headerView
        root.addSubview(header)
        header.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            header.topAnchor.constraint(equalTo: root.topAnchor),
            header.heightAnchor.constraint(equalToConstant: 52)
        ])
        let appIcon = NSImageView(image: NSApplication.shared.applicationIconImage)
        appIcon.imageScaling = .scaleProportionallyUpOrDown
        appIcon.fixed(width: 28, height: 28)
        appIcon.setAccessibilityLabel(L("轻绘"))
        header.addSubview(appIcon)
        header.addSubview(actions)
        header.addSubview(name)
        actions.translatesAutoresizingMaskIntoConstraints = false
        name.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            appIcon.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: railWidth),
            actions.leadingAnchor.constraint(equalTo: appIcon.trailingAnchor, constant: 10),
            actions.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            appIcon.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            name.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            name.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            name.leadingAnchor.constraint(greaterThanOrEqualTo: actions.trailingAnchor, constant: 24),
            name.widthAnchor.constraint(lessThanOrEqualToConstant: 320),
            documentNameField.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
        updateDocumentTitle()
    }

    private func buildInterface() {
        guard let window, let root = window.contentView else { return }
        configureHeader()
        let body = NSView()
        let footer = NSView()
        [body, footer].forEach { root.addSubview($0); $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            body.leadingAnchor.constraint(equalTo: root.leadingAnchor), body.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            body.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            body.bottomAnchor.constraint(equalTo: footer.topAnchor),
            footer.leadingAnchor.constraint(equalTo: root.leadingAnchor), footer.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: root.bottomAnchor), footer.heightAnchor.constraint(equalToConstant: 38)
        ])
        let rail = NSView()
        let center = NSView()
        let inspector = NSView()
        [rail, center, inspector].forEach { body.addSubview($0); $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            rail.leadingAnchor.constraint(equalTo: body.leadingAnchor), rail.topAnchor.constraint(equalTo: body.topAnchor),
            rail.bottomAnchor.constraint(equalTo: body.bottomAnchor), rail.widthAnchor.constraint(equalToConstant: railWidth),
            center.leadingAnchor.constraint(equalTo: rail.trailingAnchor), center.topAnchor.constraint(equalTo: body.topAnchor),
            center.bottomAnchor.constraint(equalTo: body.bottomAnchor), center.trailingAnchor.constraint(equalTo: inspector.leadingAnchor),
            inspector.trailingAnchor.constraint(equalTo: body.trailingAnchor), inspector.topAnchor.constraint(equalTo: body.topAnchor),
            inspector.bottomAnchor.constraint(equalTo: body.bottomAnchor), inspector.widthAnchor.constraint(equalToConstant: inspectorWidth)
        ])
        buildRail(in: rail)
        let inspectorScroll = NSScrollView()
        inspectorScroll.hasVerticalScroller = true
        inspectorScroll.scrollerStyle = .overlay
        inspectorScroll.autohidesScrollers = true
        inspectorScroll.drawsBackground = false
        let inspectorContent = FlippedContainer(frame: .zero)
        inspectorScroll.documentView = inspectorContent
        inspectorContent.translatesAutoresizingMaskIntoConstraints = false
        inspectorContent.widthAnchor.constraint(equalTo: inspectorScroll.contentView.widthAnchor).isActive = true
        inspector.addSubview(inspectorScroll)
        inspectorScroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            inspectorScroll.leadingAnchor.constraint(equalTo: inspector.leadingAnchor),
            inspectorScroll.trailingAnchor.constraint(equalTo: inspector.trailingAnchor),
            inspectorScroll.topAnchor.constraint(equalTo: inspector.topAnchor),
            inspectorScroll.bottomAnchor.constraint(equalTo: inspector.bottomAnchor)
        ])
        buildInspector(in: inspectorContent)
        let canvasHeader = ThemeSurfaceView(color: Theme.workspace)
        center.addSubview(canvasHeader)
        center.addSubview(scrollView)
        canvasHeader.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            canvasHeader.leadingAnchor.constraint(equalTo: center.leadingAnchor), canvasHeader.trailingAnchor.constraint(equalTo: center.trailingAnchor),
            canvasHeader.topAnchor.constraint(equalTo: center.topAnchor), canvasHeader.heightAnchor.constraint(equalToConstant: 42),
            scrollView.leadingAnchor.constraint(equalTo: center.leadingAnchor), scrollView.trailingAnchor.constraint(equalTo: center.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: canvasHeader.bottomAnchor), scrollView.bottomAnchor.constraint(equalTo: center.bottomAnchor)
        ])
        let hint = label(L("画布"), size: 11, weight: .medium, color: Theme.secondary)
        let canvasHint = label(L("按住 Shift 约束形状比例或角度"), size: 10, color: Theme.secondary)
        let headerStack = stack([hint, NSView(), canvasHint])
        canvasHeader.addSubview(headerStack)
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            headerStack.leadingAnchor.constraint(equalTo: canvasHeader.leadingAnchor, constant: 24),
            headerStack.trailingAnchor.constraint(equalTo: canvasHeader.trailingAnchor, constant: -24),
            headerStack.centerYAnchor.constraint(equalTo: canvasHeader.centerYAnchor)
        ])
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = Theme.workspace
        scrollView.drawsBackground = true
        scrollView.documentView = stage
        stage.addSubview(canvas)
        canvas.wantsLayer = true
        canvas.layer?.shadowColor = NSColor.black.cgColor
        canvas.layer?.shadowOpacity = 0.12
        canvas.layer?.shadowRadius = 10
        canvas.layer?.shadowOffset = CGSize(width: 0, height: -2)
        canvas.layer?.masksToBounds = false

        let minus = ActionButton("", symbol: "minus", symbolWeight: .light) { [weak self] in self?.zoomOut(nil) }
        minus.setAccessibilityLabel(L("缩小"))
        let plus = ActionButton("", symbol: "plus", symbolWeight: .light) { [weak self] in self?.zoomIn(nil) }
        plus.setAccessibilityLabel(L("放大"))
        let fit = ActionButton(L("适合窗口")) { [weak self] in self?.fitCanvas(nil) }
        [minus, plus].forEach { $0.style = .quiet; $0.fixed(width: 24, height: 24) }
        fit.style = .quiet
        fit.fixed(height: 26)
        zoomLabel.alignment = .center
        zoomLabel.fixed(width: 48)
        let appearanceButtons = stack(AppearanceMode.allCases.map { AppearanceButton(mode: $0) }, spacing: 3)
        let status = stack([statusLabel, NSView(), dimensionLabel, separator(vertical: true), minus, zoomLabel, plus, fit, separator(vertical: true), appearanceButtons], spacing: 10)
        footer.addSubview(status)
        status.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            status.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 20),
            status.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -16), status.centerYAnchor.constraint(equalTo: footer.centerYAnchor)
        ])
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.widthAnchor.constraint(lessThanOrEqualTo: footer.widthAnchor, multiplier: 0.25).isActive = true
        tipLabel.isHidden = true
        tipLabel.lineBreakMode = .byTruncatingTail
        tipLabel.alignment = .center
        tipLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tipLabel.setAccessibilityLabel(L("使用提示"))
        footer.addSubview(tipLabel)
        tipLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tipLabel.centerXAnchor.constraint(equalTo: footer.centerXAnchor),
            tipLabel.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            tipLabel.leadingAnchor.constraint(greaterThanOrEqualTo: statusLabel.trailingAnchor, constant: 12),
            tipLabel.trailingAnchor.constraint(lessThanOrEqualTo: dimensionLabel.leadingAnchor, constant: -12)
        ])
        let footerLine = separator()
        footer.addSubview(footerLine)
        NSLayoutConstraint.activate([footerLine.topAnchor.constraint(equalTo: footer.topAnchor), footerLine.leadingAnchor.constraint(equalTo: footer.leadingAnchor), footerLine.trailingAnchor.constraint(equalTo: footer.trailingAnchor)])
        updateHistory()
    }

    private func toolRow(_ tools: [PaintTool]) -> NSStackView {
        let row = stack(tools.map { tool in
            let button = ToolButton(tool: tool)
            button.handler = { [weak self, weak button] in
                guard let self else { return }
                if tool == .more || tool == .moreLines, let button { self.showMoreShapes(from: button, lines: tool == .moreLines) }
                else { self.selectTool(tool) }
            }
            button.selected = tool == self.tool
            toolButtons[tool] = button
            return button
        }, spacing: 4)
        // 滚动条占用横向空间时，两列按钮均分剩余宽度，避免背景被裁切。
        row.distribution = .fillEqually
        return row
    }

    private func sectionHeading(_ title: String) -> NSView {
        let heading = label(L(title), size: 11, weight: .semibold, color: Theme.secondary)
        let row = stack([heading, NSView()], spacing: 4)
        row.fixed(height: 36)
        return row
    }

    private func buildTextControls() -> [NSView] {
        sizeSlider.applyGrayscaleStyle()
        sizeSlider.target = self
        sizeSlider.action = #selector(sizeChanged(_:))
        sizeSlider.isContinuous = true
        sizeSlider.setAccessibilityLabel(L("笔画粗细"))
        let sizeTitle = label(L("笔画粗细"), size: 11, color: Theme.sizeText)
        sizeTitle.maximumNumberOfLines = 2
        sizeTitle.lineBreakMode = .byWordWrapping
        let sizeHeading = stack([sizeTitle, NSView(), sizeLabel], spacing: 4)
        let font = NSSlider(value: 32, minValue: 8, maxValue: 150, target: self, action: #selector(fontChanged(_:)))
        font.applyGrayscaleStyle()
        font.isContinuous = true
        font.setAccessibilityLabel(L("文字大小"))
        let fontTitle = label(L("文字大小"), size: 11, color: Theme.sizeText)
        fontTitle.maximumNumberOfLines = 2
        fontTitle.lineBreakMode = .byWordWrapping
        let fontHeading = stack([fontTitle, NSView(), fontSizeLabel], spacing: 4)
        let fontFamily = NSPopUpButton(frame: .zero, pullsDown: false)
        fontFamily.font = .systemFont(ofSize: 11)
        fontFamily.fixed(height: 28)
        fontFamily.addItem(withTitle: L("系统字体"))
        let fontManager = NSFontManager.shared
        let families = fontManager.availableFontFamilies.filter { !$0.hasPrefix(".") }.map { family in
            (family: family, title: fontManager.localizedName(forFamily: family, face: nil))
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        for item in families {
            guard fontManager.font(withFamily: item.family, traits: [], weight: 5, size: fontSize) != nil else { continue }
            fontFamily.addItem(withTitle: item.title)
            fontFamily.lastItem?.representedObject = item.family
        }
        fontFamily.target = self
        fontFamily.action = #selector(fontFamilyChanged(_:))
        fontFamily.setAccessibilityLabel(L("字体"))
        for view in [sizeHeading, sizeSlider] {
            brushControls.addArrangedSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: brushControls.widthAnchor).isActive = true
        }
        for view in [fontHeading, font, label(L("字体"), size: 11, color: Theme.secondary), fontFamily] {
            textControls.addArrangedSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: textControls.widthAnchor).isActive = true
        }
        brushControls.isHidden = tool == .text
        textControls.isHidden = tool != .text
        return [brushControls, textControls]
    }

    private func buildRail(in parent: NSView) {
        let fillControl = ShapeStyleControl(frame: .zero)
        fillControl.fixed(height: 46)
        fillControl.onChange = { [weak self] filled in self?.fillShapes = filled }
        let sizeTopSpacing = NSView()
        sizeTopSpacing.fixed(height: 16)
        let groups: [NSView] = [label(L("绘图工具"), size: 11, weight: .semibold, color: Theme.secondary),
            toolRow([.brush, .pencil]), toolRow([.eraser, .fill]), toolRow([.picker, .text]),
            separator(), sectionHeading("线条"), toolRow([.line, .dashedLine]),
            toolRow([.arrow, .doubleArrow]), toolRow([.dashedArrow, .moreLines]), separator(),
            sectionHeading("形状"), fillControl, toolRow([.rectangle, .roundedRectangle]),
            toolRow([.ellipse, .ellipseBubble]), toolRow([.heart, .more]), separator(), sizeTopSpacing] + buildTextControls()
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.scrollerStyle = .overlay
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        parent.addSubview(scroll)
        scroll.pin(to: parent)
        let document = FlippedContainer(frame: .zero)
        scroll.documentView = document
        document.translatesAutoresizingMaskIntoConstraints = false
        document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        let content = stack(groups, vertical: true, spacing: 4)
        content.detachesHiddenViews = true
        document.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: document.topAnchor, constant: 16),
            content.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 8),
            content.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -8),
            content.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -16)
        ])
        groups.filter { $0 is NSStackView || !($0 is NSControl) }.forEach { $0.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true }
    }

    private func showCanvasActions(from anchor: NSView) {
        canvas.finishGesture()
        let menu = NSMenu(title: L("画布操作"))
        let actions: [(String, Selector)] = [
            (L("逆时针旋转 90°"), #selector(rotateCounterclockwise(_:))),
            (L("水平翻转"), #selector(flipHorizontal(_:))),
            (L("垂直翻转"), #selector(flipVertical(_:)))
        ]
        for action in actions {
            let item = NSMenuItem(title: action.0, action: action.1, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: anchor.bounds.maxX + 6, y: anchor.bounds.minY), in: anchor)
    }

    private func showMoreShapes(from anchor: NSView, lines: Bool = false) {
        canvas.finishGesture()
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = ShapePickerController(selected: tool, lines: lines) { [weak self, weak popover] shape in
            self?.selectTool(shape)
            popover?.close()
        }
        shapePopover = popover
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxX)
    }

    private func buildInspector(in parent: NSView) {
        let colorTitle = label(L("颜色"), size: 11, weight: .semibold, color: Theme.secondary)
        hexField.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        hexField.fixed(width: inspectorWidth - 16, height: 22)
        hexField.cell?.isScrollable = true
        hexField.cell?.wraps = false
        hexField.setContentCompressionResistancePriority(.required, for: .horizontal)
        hexField.textColor = Theme.ink
        hexField.isBezeled = false
        hexField.drawsBackground = false
        hexField.focusRingType = .none
        hexField.target = self
        hexField.action = #selector(hexChanged(_:))
        hexField.setAccessibilityLabel(L("十六进制颜色"))
        currentSwatch.handler = { [weak self] in self?.showColorPanel(nil) }
        currentSwatch.toolTip = L("打开系统色卡")
        let current = stack([currentSwatch, hexField], vertical: true, spacing: 4)
        let palette = stack([], vertical: true, spacing: 6)
        for row in 0..<4 {
            let buttons = Theme.palette[(row * 3)..<(row * 3 + 3)].map { value -> NSView in
                let button = SwatchButton(color: NSColor(hex: value), size: 28)
                button.toolTip = "#" + value
                button.setAccessibilityLabel(L("预设颜色 #") + value)
                button.handler = { [weak self] in self?.chooseColor(NSColor(hex: value)) }
                paletteButtons.append(button)
                return button
            }
            let row = inspectorRow(buttons, columns: 3)
            palette.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: palette.widthAnchor).isActive = true
        }
        let custom = ActionButton(L("更多颜色…")) { [weak self] in self?.showColorPanel(nil) }
        custom.style = .quiet
        custom.fixed(width: inspectorWidth - 16, height: 30)
        for _ in 0..<3 {
            let button = SwatchButton(color: nil, size: 28)
            recentButtons.append(button)
        }
        let recentRow = inspectorRow(recentButtons, columns: 3)
        toolLabel.fixed(width: inspectorWidth - 16)
        toolLabel.maximumNumberOfLines = 2
        toolLabel.lineBreakMode = .byWordWrapping
        toolTaglineLabel.fixed(width: inspectorWidth - 16)
        toolTaglineLabel.maximumNumberOfLines = 4
        toolTaglineLabel.lineBreakMode = .byWordWrapping
        let crop = RailActionButton(kind: .crop) { [weak self] _ in self?.cropSelection(nil) }
        cropButton = crop
        crop.isEnabled = false
        let clear = RailActionButton(kind: .clear) { [weak self] _ in self?.clearCanvas(nil) }
        let rotate = RailActionButton(kind: .rotate) { [weak self] _ in self?.rotateClockwise(nil) }
        let resize = RailActionButton(kind: .resize) { [weak self] _ in self?.resizeCanvas(nil) }
        let more = RailActionButton(kind: .more) { [weak self] button in self?.showCanvasActions(from: button) }
        let selectionTool = toolRow([.selection])
        selectionTool.fixed(width: 44)
        let selectionRow = inspectorRow([selectionTool, crop], columns: 2)
        let selectionHeading = sectionHeading("选区")
        selectionHeading.fixed(width: inspectorWidth - 16)
        let items: [NSView] = [toolLabel, toolTaglineLabel,
            separator(), colorTitle, current, palette, recentRow, custom,
            separator(), selectionHeading, selectionRow,
            inspectorRow([clear, rotate], columns: 2), inspectorRow([resize, more], columns: 2)]
        let content = stack(items, vertical: true, spacing: 9)
        parent.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: 8),
            content.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -8),
            content.topAnchor.constraint(equalTo: parent.topAnchor, constant: 20),
            content.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -20)
        ])
        items.forEach {
            $0.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        }
    }

    private func inspectorRow(_ views: [NSView], columns: Int) -> NSStackView {
        let row = stack([], spacing: 8)
        row.distribution = .fillEqually
        for index in 0..<columns {
            let cell = NSView()
            row.addArrangedSubview(cell)
            guard index < views.count else { continue }
            let view = views[index]
            cell.addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                view.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
                view.topAnchor.constraint(equalTo: cell.topAnchor),
                view.bottomAnchor.constraint(equalTo: cell.bottomAnchor)
            ])
        }
        return row
    }

    func selectTool(_ tool: PaintTool) {
        canvas.finishGesture()
        self.tool = tool
        if tool != .selection { canvas.selection = nil }
        toolButtons.forEach { $0.value.selected = $0.key == tool || ($0.key == .more && tool.isExtraShape && ![PaintTool.ellipseBubble, .heart].contains(tool)) || ($0.key == .moreLines && tool.isLine && ![PaintTool.line, .dashedLine, .arrow, .doubleArrow, .dashedArrow].contains(tool)) }
        toolButtons[.more]?.toolTip = tool.isExtraShape ? L("更多形状 · ") + tool.title : L("更多形状")
        brushControls.isHidden = tool == .text
        textControls.isHidden = tool != .text
        toolLabel.stringValue = tool.title
        toolTaglineLabel.stringValue = tool.tagline
        window?.invalidateCursorRects(for: canvas)
        window?.makeFirstResponder(canvas)
        updateStatus()
    }

    func chooseColor(_ color: NSColor, remember: Bool = false) {
        self.color = color.usingColorSpace(.sRGB) ?? .black
        if remember && !Theme.palette.contains(self.color.hex) {
            recentColors = UserDefaults.standard.stringArray(forKey: "recentCustomColors") ?? []
            recentColors.removeAll { $0 == self.color.hex }
            recentColors.insert(self.color.hex, at: 0)
            recentColors = Array(recentColors.prefix(3))
            UserDefaults.standard.set(recentColors, forKey: "recentCustomColors")
        }
        refreshColors()
    }

    private func refreshColors() {
        currentSwatch.swatch = color
        currentSwatch.needsDisplay = true
        hexField.stringValue = "#" + color.hex
        paletteButtons.forEach { $0.selected = $0.swatch?.hex == color.hex }
        for (index, button) in recentButtons.enumerated() {
            let value = index < recentColors.count ? recentColors[index] : nil
            button.swatch = value.map { NSColor(hex: $0) }
            button.selected = value == color.hex
            button.isEnabled = value != nil
            button.toolTip = value.map { "#" + $0 } ?? L("从色卡选取颜色后显示在这里")
            button.setAccessibilityLabel(value.map { L("最近颜色 #") + $0 } ?? L("空的最近颜色"))
            button.handler = { [weak self] in if let value { self?.chooseColor(NSColor(hex: value), remember: true) } }
            button.needsDisplay = true
        }
    }

    @objc func showColorPanel(_ sender: Any?) {
        let panel = NSColorPanel.shared
        panel.setTarget(self)
        panel.setAction(#selector(panelColorChanged(_:)))
        panel.showsAlpha = false
        panel.isContinuous = false
        panel.color = color
        panel.orderFront(nil)
    }
    @objc private func panelColorChanged(_ sender: NSColorPanel) { chooseColor(sender.color, remember: true) }
    @objc private func hexChanged(_ sender: NSTextField) {
        let value = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "").uppercased()
        guard value.count == 6, UInt32(value, radix: 16) != nil else {
            sender.stringValue = "#" + color.hex
            NSSound.beep()
            return
        }
        chooseColor(NSColor(hex: value), remember: true)
        window?.makeFirstResponder(canvas)
    }
    @objc private func sizeChanged(_ sender: NSSlider) { setBrushSize(CGFloat(sender.integerValue)) }
    func setBrushSize(_ size: CGFloat) {
        brushSize = Swift.max(1, Swift.min(48, size))
        sizeLabel.stringValue = "\(Int(brushSize)) px"
        sizeSlider.doubleValue = Double(brushSize)
    }
    @objc private func fontFamilyChanged(_ sender: NSPopUpButton) {
        textFontFamily = sender.selectedItem?.representedObject as? String
        sender.toolTip = sender.titleOfSelectedItem
        window?.makeFirstResponder(canvas)
    }
    @objc private func fontChanged(_ sender: NSSlider) {
        fontSize = Swift.max(8, Swift.min(150, CGFloat(sender.integerValue)))
        fontSizeLabel.stringValue = "\(Int(fontSize)) px"
    }

    func refreshCanvas(preserveSelection: Bool = false) {
        let bitmap = paintDocument.bitmap
        canvas.bounds = CGRect(x: 0, y: 0, width: bitmap.width, height: bitmap.height)
        if !preserveSelection { canvas.selection = nil }
        synchronizeWindowTitleWithDocumentName()
        layoutCanvas()
        canvas.needsDisplay = true
        updateStatus()
        updateHistory()
    }

    func layoutCanvas() {
        let bitmap = paintDocument.bitmap
        let size = CGSize(width: CGFloat(bitmap.width) * zoom, height: CGFloat(bitmap.height) * zoom)
        let visible = scrollView.contentSize
        let stageSize = CGSize(width: Swift.max(visible.width, size.width + 96), height: Swift.max(visible.height, size.height + 96))
        if stage.frame.size != stageSize { stage.setFrameSize(stageSize) }
        let frame = CGRect(x: (stageSize.width - size.width) / 2, y: (stageSize.height - size.height) / 2, width: size.width, height: size.height)
        if canvas.frame != frame { canvas.frame = frame }
        canvas.bounds = CGRect(x: 0, y: 0, width: bitmap.width, height: bitmap.height)
        canvas.updateSelectionControls()
    }

    func updateStatus(point: CGPoint? = nil) {
        cropButton?.isEnabled = canvas.selection.map { $0.width >= 1 && $0.height >= 1 } ?? false
        let bitmap = paintDocument.bitmap
        dimensionLabel.stringValue = "\(bitmap.width) × \(bitmap.height) px"
        if let point {
            statusLabel.stringValue = "\(tool.title) · X \(Int(point.x))  Y \(Int(point.y))"
        } else if let selection = canvas.selection {
            statusLabel.stringValue = L("选区 %ld × %ld px · 拖动移动 / Delete 删除", Int(selection.width), Int(selection.height))
        } else {
            let hints: [PaintTool: String] = [.selection: L("拖动框选 · 可移动、复制和裁剪"), .text: L("点击画布添加文字"), .fill: L("点击填充连通区域"), .picker: L("点击画布取色")]
            statusLabel.stringValue = tool.title + " · " + (hints[tool] ?? ((tool.isShape || tool.isLine) ? L("拖动绘制 · Shift 约束比例 / 角度") : L("拖动开始绘画")))
        }
    }

    private func updateHistory() {
        guard historyButtons.count == 2 else { return }
        historyButtons[0].isEnabled = paintDocument.undoManager?.canUndo ?? false
        historyButtons[1].isEnabled = paintDocument.undoManager?.canRedo ?? false
    }
    @objc func undo(_ sender: Any?) { canvas.cancelGesture(); paintDocument.undoManager?.undo(); updateHistory() }
    @objc func redo(_ sender: Any?) { canvas.cancelGesture(); paintDocument.undoManager?.redo(); updateHistory() }

    private func setZoom(_ value: CGFloat) {
        let oldCenter = canvas.convert(CGPoint(x: scrollView.contentView.bounds.midX, y: scrollView.contentView.bounds.midY), from: stage)
        zoom = Swift.max(0.02, Swift.min(8, value))
        zoomLabel.stringValue = "\(Int((zoom * 100).rounded()))%"
        layoutCanvas()
        let newCenter = canvas.convert(oldCenter, to: stage)
        let origin = CGPoint(x: newCenter.x - scrollView.contentSize.width / 2, y: newCenter.y - scrollView.contentSize.height / 2)
        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        canvas.needsDisplay = true
    }
    @objc func zoomIn(_ sender: Any?) { setZoom(zoom * 1.25) }
    @objc func zoomOut(_ sender: Any?) { setZoom(zoom / 1.25) }
    @objc func actualSize(_ sender: Any?) { setZoom(1) }
    @objc func fitCanvas(_ sender: Any?) {
        let available = scrollView.contentSize
        let bitmap = paintDocument.bitmap
        setZoom(Swift.min((available.width - 96) / CGFloat(bitmap.width), (available.height - 96) / CGFloat(bitmap.height)))
    }
    func windowDidResize(_ notification: Notification) { layoutCanvas() }
    func windowDidBecomeKey(_ notification: Notification) {
        recentColors = Array((UserDefaults.standard.stringArray(forKey: "recentCustomColors") ?? []).prefix(3))
        refreshColors()
        if NSColorPanel.shared.isVisible {
            NSColorPanel.shared.setTarget(self)
            NSColorPanel.shared.setAction(#selector(panelColorChanged(_:)))
            NSColorPanel.shared.color = color
        }
    }

    override func selectAll(_ sender: Any?) {
        selectTool(.selection)
        canvas.selection = nil
        canvas.selection = CGRect(x: 0, y: 0, width: paintDocument.bitmap.width, height: paintDocument.bitmap.height)
    }
    @objc func copySelection(_ sender: Any?) {
        let bitmap: Bitmap
        if let floating = canvas.floatingSelection { bitmap = floating.content }
        else if let rect = canvas.selection, let cropped = paintDocument.bitmap.cropped(to: rect) { bitmap = cropped }
        else { bitmap = paintDocument.bitmap }
        guard let png = try? bitmap.encoded(type: UTType.png.identifier) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(png, forType: .png)
    }
    @objc func cutSelection(_ sender: Any?) {
        guard canvas.selection != nil else { return }
        copySelection(sender)
        deleteSelection(sender)
    }
    @objc func deleteSelection(_ sender: Any?) {
        guard let rect = canvas.selection else { return }
        let previous = paintDocument.bitmap
        if let floating = canvas.floatingSelection { paintDocument.bitmap = floating.background }
        else {
            paintDocument.bitmap.draw { context in
                context.setFillColor(NSColor.white.cgColor)
                context.fill(rect)
            }
        }
        paintDocument.commit(previous: previous, action: L("删除选区"))
    }
    @objc func pasteImage(_ sender: Any?) { if !paste(from: .general) { NSSound.beep() } }
    @discardableResult func paste(from pasteboard: NSPasteboard) -> Bool {
        let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff)
            ?? NSImage(pasteboard: pasteboard)?.tiffRepresentation
        if let data {
            do {
                let image = try Bitmap(data: data)
                pasteBitmap(image)
                return true
            } catch { window?.presentError(error); return false }
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let url = urls.first {
            do { pasteBitmap(try Bitmap(data: Data(contentsOf: url))); return true }
            catch { window?.presentError(error) }
        }
        return false
    }
    private func pasteBitmap(_ image: Bitmap) {
        canvas.finishGesture()
        let origin = canvas.selection?.origin ?? .zero
        var background = paintDocument.bitmap
        let width = Swift.max(background.width, Int(ceil(origin.x)) + image.width)
        let height = Swift.max(background.height, Int(ceil(origin.y)) + image.height)
        do { try Bitmap.validate(width: width, height: height) }
        catch { window?.presentError(error); return }
        if background.width != width || background.height != height {
            background = background.resized(width: width, height: height, scaleImage: false)
        }
        var bitmap = background
        bitmap.paste(image, at: origin)
        paintDocument.replace(with: bitmap, action: L("粘贴图片"))
        selectTool(.selection)
        canvas.makeFloatingSelection(content: image, background: background, at: origin)
        window?.makeFirstResponder(canvas)
    }

    @objc func rotateClockwise(_ sender: Any?) { paintDocument.replace(with: paintDocument.bitmap.transformed(clockwise: true), action: L("顺时针旋转")) }
    @objc func rotateCounterclockwise(_ sender: Any?) { paintDocument.replace(with: paintDocument.bitmap.transformed(), action: L("逆时针旋转")) }
    @objc func flipHorizontal(_ sender: Any?) { paintDocument.replace(with: paintDocument.bitmap.transformed(horizontal: true), action: L("水平翻转")) }
    @objc func flipVertical(_ sender: Any?) { paintDocument.replace(with: paintDocument.bitmap.transformed(horizontal: false), action: L("垂直翻转")) }
    @objc func cropSelection(_ sender: Any?) {
        canvas.finishGesture()
        guard let rect = canvas.selection, let bitmap = paintDocument.bitmap.cropped(to: rect) else { NSSound.beep(); return }
        paintDocument.replace(with: bitmap, action: L("裁剪"))
    }
    @objc func clearCanvas(_ sender: Any?) {
        guard let window, window.attachedSheet == nil else { return }
        canvas.finishGesture()
        let alert = NSAlert()
        alert.messageText = L("清空画布？")
        alert.informativeText = L("画布上的所有内容都将被清除，清空后可通过撤销恢复。")
        let confirm = alert.addButton(withTitle: L("清空画布"))
        confirm.hasDestructiveAction = true
        let cancel = alert.addButton(withTitle: L("取消"))
        alert.layout()
        confirm.keyEquivalent = ""
        cancel.keyEquivalent = "\r"
        alert.window.defaultButtonCell = cancel.cell as? NSButtonCell
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            self.paintDocument.replace(with: Bitmap(width: self.paintDocument.bitmap.width, height: self.paintDocument.bitmap.height),
                                       action: L("清空画布"))
            window.makeFirstResponder(self.canvas)
        }
    }

    @objc func resizeCanvas(_ sender: Any?) {
        guard let window else { return }
        let alert = NSAlert()
        alert.messageText = L("调整画布尺寸")
        alert.informativeText = L("修改像素尺寸。扩展画布会添加透明区域，缩小画布会裁去右侧和下方内容。")
        alert.addButton(withTitle: L("应用"))
        alert.addButton(withTitle: L("取消"))
        let width = NSTextField(string: "\(paintDocument.bitmap.width)")
        let height = NSTextField(string: "\(paintDocument.bitmap.height)")
        width.fixed(width: 110); height.fixed(width: 110)
        let scale = NSButton(checkboxWithTitle: L("同时缩放图片内容"), target: nil, action: nil)
        let fields = stack([stack([label(L("宽度")), width, label(L("高度")), height]), scale], vertical: true, spacing: 16)
        fields.frame = NSRect(x: 0, y: 0, width: 350, height: 72)
        alert.accessoryView = fields
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            do {
                guard let w = Int(width.stringValue), let h = Int(height.stringValue) else { throw PaintError.message(L("请输入有效的整数尺寸。")) }
                try Bitmap.validate(width: w, height: h)
                self.paintDocument.replace(with: self.paintDocument.bitmap.resized(width: w, height: h, scaleImage: scale.state == .on), action: L("调整画布"))
                self.fitCanvas(nil)
            } catch { window.presentError(error) }
        }
    }

    func insertText(at point: CGPoint) {
        guard let window else { return }
        let alert = NSAlert()
        alert.messageText = L("添加文字")
        alert.informativeText = L("以当前颜色和 %ld px 字号绘制文字，支持多行输入。", Int(fontSize))
        alert.addButton(withTitle: L("添加"))
        alert.addButton(withTitle: L("取消"))
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 360, height: 120))
        let text = NSTextView(frame: scroll.bounds)
        text.isRichText = false
        let selectedFont = drawingFont
        text.font = NSFontManager.shared.convert(selectedFont, toSize: 16)
        text.isVerticallyResizable = true
        text.autoresizingMask = [.width]
        scroll.documentView = text
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        alert.accessoryView = scroll
        let selectedColor = color
        let insertionPoint = CGPoint(x: floor(point.x), y: floor(point.y))
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self, !text.string.isEmpty else { return }
            let previous = self.paintDocument.bitmap
            let background = self.paintDocument.bitmap
            let attributes: [NSAttributedString.Key: Any] = [.font: selectedFont, .foregroundColor: selectedColor]
            let available = CGSize(width: CGFloat(previous.width) - insertionPoint.x, height: CGFloat(previous.height) - insertionPoint.y)
            let measured = (text.string as NSString).boundingRect(with: available,
                options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes)
            let width = Swift.max(1, Swift.min(Int(available.width), Int(ceil(measured.width)) + 4))
            let height = Swift.max(1, Swift.min(Int(available.height), Int(ceil(measured.height)) + 4))
            var content = Bitmap(width: width, height: height, color: .clear)
            content.draw { context in
                context.setShouldAntialias(true)
                context.setShouldSmoothFonts(false)
                context.setShouldSubpixelPositionFonts(false)
                context.setShouldSubpixelQuantizeFonts(true)
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
                (text.string as NSString).draw(in: CGRect(x: 1, y: 1, width: width - 1, height: height - 1), withAttributes: attributes)
                NSGraphicsContext.restoreGraphicsState()
            }
            var bitmap = background
            bitmap.paste(content, at: insertionPoint)
            self.paintDocument.bitmap = bitmap
            self.paintDocument.commit(previous: previous, action: L("添加文字"))
            self.selectTool(.selection)
            self.canvas.makeFloatingSelection(content: content, background: background, at: insertionPoint)
        }
        alert.window.makeFirstResponder(text)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(undo(_:)): return paintDocument.undoManager?.canUndo ?? false
        case #selector(redo(_:)): return paintDocument.undoManager?.canRedo ?? false
        case #selector(cropSelection(_:)), #selector(cutSelection(_:)), #selector(deleteSelection(_:)): return canvas.selection != nil
        default: return true
        }
    }
}
