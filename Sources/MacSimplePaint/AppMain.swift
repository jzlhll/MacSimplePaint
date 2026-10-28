import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var receivedOpenRequest = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        createMenus()
        NSApplication.shared.activate(ignoringOtherApps: true)
        if !receivedOpenRequest && NSDocumentController.shared.documents.isEmpty { NSDocumentController.shared.newDocument(nil) }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        let window = NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow
        (window?.windowController as? EditorController)?.showRandomTip()
    }

    func applicationDidResignActive(_ notification: Notification) {
        for document in NSDocumentController.shared.documents {
            (document as? PaintDocument)?.editor?.hideTip()
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { NSDocumentController.shared.newDocument(nil) }
        return true
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        receivedOpenRequest = true
        for url in urls {
            NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
                if let error { application.presentError(error) }
            }
        }
    }

    private func createMenus() {
        let main = NSMenu()
        NSApplication.shared.mainMenu = main
        func submenu(_ title: String) -> NSMenu {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let menu = NSMenu(title: title)
            item.submenu = menu
            main.addItem(item)
            return menu
        }
        func item(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "", shift: Bool = false, target: AnyObject? = nil) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = shift ? [.command, .shift] : [.command]
            item.target = target
            menu.addItem(item)
        }
        let app = submenu(L("轻绘"))
        item(app, "About SimplePaint", #selector(showAbout(_:)), target: self)
        app.addItem(.separator())
        let languageItem = NSMenuItem(title: L("语言"), action: nil, keyEquivalent: "")
        let languageMenu = NSMenu(title: L("语言"))
        let languages = [(code: "", name: L("跟随系统"))] + AppLanguage.supported
        for language in languages {
            let choice = NSMenuItem(title: language.name, action: #selector(changeLanguage(_:)), keyEquivalent: "")
            choice.target = self
            choice.representedObject = language.code
            choice.state = (AppLanguage.override ?? "") == language.code ? .on : .off
            languageMenu.addItem(choice)
            if language.code.isEmpty { languageMenu.addItem(.separator()) }
        }
        languageItem.submenu = languageMenu
        app.addItem(languageItem)
        let services = NSMenu()
        let servicesItem = NSMenuItem(title: L("服务"), action: nil, keyEquivalent: "")
        servicesItem.submenu = services
        app.addItem(servicesItem)
        NSApplication.shared.servicesMenu = services
        app.addItem(.separator())
        item(app, L("隐藏轻绘"), #selector(NSApplication.hide(_:)), "h")
        item(app, L("显示全部"), #selector(NSApplication.unhideAllApplications(_:)))
        app.addItem(.separator())
        item(app, L("退出轻绘"), #selector(NSApplication.terminate(_:)), "q")

        let file = submenu(L("文件"))
        item(file, L("新建"), #selector(NSDocumentController.newDocument(_:)), "n")
        item(file, L("打开…"), #selector(NSDocumentController.openDocument(_:)), "o")
        let recent = NSMenu(title: L("最近打开"))
        recent.delegate = self
        let recentItem = NSMenuItem(title: L("最近打开"), action: nil, keyEquivalent: "")
        recentItem.submenu = recent
        file.addItem(recentItem)
        file.addItem(.separator())
        item(file, L("关闭窗口"), #selector(NSWindow.performClose(_:)), "w")
        item(file, L("保存"), #selector(NSDocument.save(_:)), "s")
        item(file, L("另存为…"), #selector(NSDocument.saveAs(_:)), "s", shift: true)

        let edit = submenu(L("编辑"))
        item(edit, L("撤销"), #selector(EditorController.undo(_:)), "z")
        item(edit, L("重做"), #selector(EditorController.redo(_:)), "z", shift: true)
        edit.addItem(.separator())
        item(edit, L("剪切"), #selector(CanvasView.cut(_:)), "x")
        item(edit, L("复制"), #selector(CanvasView.copy(_:)), "c")
        item(edit, L("粘贴图片"), #selector(CanvasView.paste(_:)), "v")
        item(edit, L("全选"), #selector(NSResponder.selectAll(_:)), "a")
        item(edit, L("删除选区"), #selector(EditorController.deleteSelection(_:)))

        let view = submenu(L("显示"))
        item(view, L("放大"), #selector(EditorController.zoomIn(_:)), "=")
        item(view, L("缩小"), #selector(EditorController.zoomOut(_:)), "-")
        item(view, L("实际大小"), #selector(EditorController.actualSize(_:)), "1")
        item(view, L("适合窗口"), #selector(EditorController.fitCanvas(_:)), "0")
        view.addItem(.separator())
        item(view, L("进入全屏幕"), #selector(NSWindow.toggleFullScreen(_:)), "f", shift: true)

        let window = submenu(L("窗口"))
        item(window, L("最小化"), #selector(NSWindow.performMiniaturize(_:)), "m")
        item(window, L("缩放"), #selector(NSWindow.performZoom(_:)))
        NSApplication.shared.windowsMenu = window
        let help = submenu(L("帮助"))
        item(help, L("轻绘使用说明"), #selector(showHelp(_:)), target: self)
    }

    @objc private func changeLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String,
              code != (AppLanguage.override ?? "") else { return }
        if code.isEmpty { UserDefaults.standard.removeObject(forKey: "AppleLanguages") }
        else { UserDefaults.standard.set([code], forKey: "AppleLanguages") }
        sender.menu?.items.forEach { $0.state = $0 === sender ? .on : .off }
        let alert = NSAlert()
        alert.messageText = L("语言已更改")
        alert.informativeText = L("重新打开轻绘后生效。请先保存正在编辑的图片。")
        alert.addButton(withTitle: L("好"))
        alert.runModal()
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        let urls = NSDocumentController.shared.recentDocumentURLs
        if urls.isEmpty {
            let item = NSMenuItem(title: L("暂无最近文件"), action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        for url in urls.prefix(12) {
            let item = NSMenuItem(title: url.lastPathComponent, action: #selector(openRecent(_:)), keyEquivalent: "")
            item.representedObject = url
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let clear = NSMenuItem(title: L("清除记录"), action: #selector(NSDocumentController.clearRecentDocuments(_:)), keyEquivalent: "")
        clear.target = NSDocumentController.shared
        menu.addItem(clear)
    }
    @objc private func openRecent(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
            if let error { NSApplication.shared.presentError(error) }
        }
    }
    @objc private func showAbout(_ sender: Any?) {
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "SimplePaint", .applicationVersion: "", .version: "",
            .credits: NSAttributedString(string: "Version 1.0\n\nA few simple strokes to capture every idea.\nA native macOS drawing app.")
        ])
    }
    @objc private func showHelp(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = L("轻绘使用说明")
        let shortcuts = [
            "⌘O " + L("打开") + " · ⌘V " + L("粘贴图片"),
            "⌘S " + L("保存") + " · ⇧⌘S " + L("另存为…"),
            "⌘Z " + L("撤销") + " · ⇧⌘Z " + L("重做"),
            "⌘0 " + L("适合窗口") + " · ⌘1 " + L("实际大小"),
            "B " + PaintTool.brush.title + " · P " + PaintTool.pencil.title + " · E " + PaintTool.eraser.title,
            "G " + PaintTool.fill.title + " · I " + PaintTool.picker.title + " · T " + PaintTool.text.title,
            "M " + PaintTool.selection.title + " · L " + PaintTool.line.title + " · D " + PaintTool.dashedLine.title,
            "R " + PaintTool.rectangle.title + " · O " + PaintTool.ellipse.title,
            L("按 [ / ] 调整笔画粗细")
        ].joined(separator: "\n")
        alert.informativeText = [L("help.intro"), shortcuts, L("help.gestures"), L("help.colors"), L("help.files")].joined(separator: "\n\n")
        alert.runModal()
    }
}

@main
struct MacSimplePaintApp {
    static func main() {
        let application = NSApplication.shared
        let documents = PaintDocumentController()
        let delegate = AppDelegate()
        AppearanceMode.current.apply()
        application.setActivationPolicy(.regular)
        application.delegate = delegate
        application.run()
        withExtendedLifetime((delegate, documents)) {}
    }
}
