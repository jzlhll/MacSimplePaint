import AppKit
import UniformTypeIdentifiers

// 每个窗口独立维护单张位图、撤销历史和保存状态。
@objc(PaintDocument)
final class PaintDocument: NSDocument {
    var bitmap = Bitmap(width: 1200, height: 800)
    var editor: EditorController? { windowControllers.first as? EditorController }
    override class var autosavesInPlace: Bool { false }

    override init() {
        super.init()
        undoManager = UndoManager()
        undoManager?.levelsOfUndo = 20
    }

    override func makeWindowControllers() { addWindowController(EditorController(document: self)) }

    override func updateChangeCount(_ change: NSDocument.ChangeType) {
        super.updateChangeCount(change)
        editor?.synchronizeWindowTitleWithDocumentName()
    }

    override func read(from data: Data, ofType typeName: String) throws {
        bitmap = try Bitmap(data: data)
        editor?.refreshCanvas()
    }

    override func data(ofType typeName: String) throws -> Data { try bitmap.encoded(type: typeName) }

    override func writableTypes(for saveOperation: NSDocument.SaveOperationType) -> [String] {
        [UTType.png.identifier, UTType.jpeg.identifier, UTType.tiff.identifier, UTType.bmp.identifier]
    }

    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        savePanel.isExtensionHidden = false
        return super.prepareSavePanel(savePanel)
    }

    // 协调原文件与目标路径，移动失败时保留原文件，且不覆盖已有文件。
    func renameFile(to name: String) throws {
        guard let source = fileURL else { return }
        let basename = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !basename.isEmpty, basename != ".", basename != "..",
              !basename.contains("/"), !basename.contains(":"),
              !basename.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            throw PaintError.message(L("请输入有效的文件名，不要包含 / 或 :。"))
        }
        let filename = source.pathExtension.isEmpty ? basename : basename + "." + source.pathExtension
        guard filename != source.lastPathComponent else { return }
        let target = source.deletingLastPathComponent().appendingPathComponent(filename, isDirectory: false)
        let coordinator = NSFileCoordinator(filePresenter: self)
        var coordinationError: NSError?
        var moveError: Error?
        var movedURL: URL?
        coordinator.coordinate(writingItemAt: source, options: .forMoving,
                               writingItemAt: target, options: [], error: &coordinationError) { oldURL, newURL in
            do {
                try FileManager.default.moveItem(at: oldURL, to: newURL)
                coordinator.item(at: oldURL, didMoveTo: newURL)
                movedURL = newURL
            } catch { moveError = error }
        }
        if let error = coordinationError ?? moveError as NSError? { throw error }
        guard let movedURL else { throw PaintError.message(L("无法重命名文件。")) }
        fileURL = movedURL
        NSDocumentController.shared.noteNewRecentDocumentURL(movedURL)
        editor?.synchronizeWindowTitleWithDocumentName()
    }

    func commit(previous: Bitmap, action: String, preserveSelection: Bool = false) {
        guard previous != bitmap else { return }
        let snapshotBytes = Swift.max(previous.pixels.count, bitmap.pixels.count)
        if undoManager?.isUndoing != true && undoManager?.isRedoing != true {
            undoManager?.levelsOfUndo = Swift.max(1, Swift.min(20, 192_000_000 / snapshotBytes))
        }
        undoManager?.registerUndo(withTarget: self) { document in document.replace(with: previous, action: action) }
        undoManager?.setActionName(action)
        editor?.refreshCanvas(preserveSelection: preserveSelection)
    }

    func replace(with bitmap: Bitmap, action: String) {
        let previous = self.bitmap
        self.bitmap = bitmap
        commit(previous: previous, action: action)
    }
}

final class PaintDocumentController: NSDocumentController {
    override var defaultType: String? { UTType.png.identifier }
    override func documentClass(forType typeName: String) -> AnyClass? { PaintDocument.self }
}
