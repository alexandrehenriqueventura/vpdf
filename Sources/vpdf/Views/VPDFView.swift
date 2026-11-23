import AppKit
import PDFKit

/// Subclasse personalizada do PDFView que traduz integralmente os menus de contexto
/// para o Português do Brasil (pt-BR) e provê suporte nativo a anotações e apresentação.
public final class VPDFView: PDFView {

    public var isPresentationMode: Bool = false {
        didSet {
            if isPresentationMode {
                displayMode = .singlePage
                displaysPageBreaks = false
                autoScales = true
                backgroundColor = .black
            } else {
                displayMode = .singlePageContinuous
                displaysPageBreaks = true
                backgroundColor = NSColor.windowBackgroundColor
            }
        }
    }

    public override var acceptsFirstResponder: Bool {
        return true
    }

    private enum KeyCode {
        static let rightArrow: UInt16 = 124
        static let downArrow: UInt16 = 125
        static let space: UInt16 = 49
        static let leftArrow: UInt16 = 123
        static let upArrow: UInt16 = 126
        static let escape: UInt16 = 53
        static let pageDown: UInt16 = 121
        static let pageUp: UInt16 = 116
        static let returnKey: UInt16 = 36
        static let keypadEnter: UInt16 = 76
        static let keyN: UInt16 = 45
        static let keyP: UInt16 = 35
    }

    public var onPresentationModeToggle: (() -> Void)?
    public var onAnnotationAdded: (() -> Void)?
    public var onSlideChanged: ((Int, Int) -> Void)?
    public var onRequestAddNoteForSelection: ((PDFSelection) -> Void)?
    public var onRequestAddStickyNoteAtPoint: ((PDFPage, CGPoint) -> Void)?
    public var onRequestEditNote: ((PDFAnnotation, PDFPage) -> Void)?

    private var lastRightClickPage: PDFPage?
    private var lastRightClickPoint: CGPoint = .zero
    private var lastRightClickAnnotation: PDFAnnotation?

    public override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if event.clickCount == 2 {
            let viewPoint = convert(event.locationInWindow, from: nil)
            guard let page = page(for: viewPoint, nearest: false) else { return }
            let pagePoint = convert(viewPoint, to: page)

            for annotation in page.annotations {
                if annotation.bounds.insetBy(dx: -6, dy: -6).contains(pagePoint) {
                    if annotation.type == "Text" || (annotation.contents != nil && !annotation.contents!.isEmpty) {
                        onRequestEditNote?(annotation, page)
                        return
                    }
                }
            }
        }
    }

    public func refreshLayout() {
        layoutDocumentView()
    }

    public override func keyDown(with event: NSEvent) {
        if isPresentationMode {
            switch event.keyCode {
            case KeyCode.rightArrow, KeyCode.downArrow, KeyCode.space, KeyCode.pageDown, KeyCode.returnKey, KeyCode.keypadEnter, KeyCode.keyN:
                goToNextPage(nil)
                notifySlideChanged()
                return
            case KeyCode.leftArrow, KeyCode.upArrow, KeyCode.pageUp, KeyCode.keyP:
                goToPreviousPage(nil)
                notifySlideChanged()
                return
            case KeyCode.escape:
                onPresentationModeToggle?()
                return
            default:
                if let specialKey = event.specialKey {
                    switch specialKey {
                    case .pageDown:
                        goToNextPage(nil)
                        notifySlideChanged()
                        return
                    case .pageUp:
                        goToPreviousPage(nil)
                        notifySlideChanged()
                        return
                    default:
                        break
                    }
                }
            }
        }
        super.keyDown(with: event)
    }

    private func notifySlideChanged() {
        guard let doc = document, let cur = currentPage else { return }
        let idx = doc.index(for: cur) + 1
        onSlideChanged?(idx, doc.pageCount)
    }

    public override func menu(for event: NSEvent) -> NSMenu? {
        guard let originalMenu = super.menu(for: event) else { return nil }

        // Traduz recursivamente todos os itens nativos para Português do Brasil
        localizeMenu(originalMenu)

        let viewPoint = convert(event.locationInWindow, from: nil)
        let clickedPage = page(for: viewPoint, nearest: false)
        let pagePoint = clickedPage != nil ? convert(viewPoint, to: clickedPage!) : .zero

        self.lastRightClickPage = clickedPage
        self.lastRightClickPoint = pagePoint

        var hitAnnotation: PDFAnnotation? = nil
        if let page = clickedPage {
            for anno in page.annotations {
                if anno.bounds.insetBy(dx: -6, dy: -6).contains(pagePoint) {
                    if anno.type == "Text" || (anno.contents != nil && !anno.contents!.isEmpty) {
                        hitAnnotation = anno
                        break
                    }
                }
            }
        }
        self.lastRightClickAnnotation = hitAnnotation

        // 1. Se clicou sobre uma nota existente (ícone ou realce com conteúdo)
        if hitAnnotation != nil {
            let editItem = NSMenuItem(title: "Editar Nota...", action: #selector(handleEditClickedAnnotationAction(_:)), keyEquivalent: "")
            editItem.target = self
            editItem.image = NSImage(systemSymbolName: "pencil", accessibilityDescription: nil)

            let deleteItem = NSMenuItem(title: "Excluir Nota", action: #selector(handleDeleteClickedAnnotationAction(_:)), keyEquivalent: "")
            deleteItem.target = self
            deleteItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)

            originalMenu.insertItem(NSMenuItem.separator(), at: 0)
            originalMenu.insertItem(deleteItem, at: 0)
            originalMenu.insertItem(editItem, at: 0)
        }
        // 2. Se houver texto selecionado, enriquece com notas e marcações
        else if let selection = currentSelection, let str = selection.string, !str.isEmpty {
            let addNoteItem = NSMenuItem(title: "Adicionar Nota ao Texto...", action: #selector(handleAddNoteToSelectionAction(_:)), keyEquivalent: "")
            addNoteItem.target = self
            addNoteItem.image = NSImage(systemSymbolName: "note.text.badge.plus", accessibilityDescription: nil)

            let markupMenu = NSMenu(title: "Realçar com Cor")
            
            let colors: [(name: String, color: NSColor)] = [
                ("Amarelo", NSColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 0.5)),
                ("Verde", NSColor(red: 0.55, green: 0.9, blue: 0.6, alpha: 0.5)),
                ("Azul", NSColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 0.5)),
                ("Rosa", NSColor(red: 1.0, green: 0.65, blue: 0.75, alpha: 0.5))
            ]

            for (name, color) in colors {
                let item = NSMenuItem(title: "Realçar (\(name))", action: #selector(handleHighlightColorAction(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = color
                markupMenu.addItem(item)
            }

            let highlightParentItem = NSMenuItem(title: "Realçar Texto", action: nil, keyEquivalent: "")
            highlightParentItem.image = NSImage(systemSymbolName: "highlighter", accessibilityDescription: nil)
            highlightParentItem.submenu = markupMenu

            let underlineItem = NSMenuItem(title: "Sublinhar Texto", action: #selector(handleUnderlineAction(_:)), keyEquivalent: "")
            underlineItem.target = self
            underlineItem.image = NSImage(systemSymbolName: "underline", accessibilityDescription: nil)

            let strikeOutItem = NSMenuItem(title: "Tachar Texto", action: #selector(handleStrikeOutAction(_:)), keyEquivalent: "")
            strikeOutItem.target = self
            strikeOutItem.image = NSImage(systemSymbolName: "strikethrough", accessibilityDescription: nil)

            let removeAnnoItem = NSMenuItem(title: "Remover Realces da Seleção", action: #selector(handleRemoveAnnotationsAction(_:)), keyEquivalent: "")
            removeAnnoItem.target = self
            removeAnnoItem.image = NSImage(systemSymbolName: "eraser", accessibilityDescription: nil)

            originalMenu.insertItem(NSMenuItem.separator(), at: 0)
            originalMenu.insertItem(removeAnnoItem, at: 0)
            originalMenu.insertItem(strikeOutItem, at: 0)
            originalMenu.insertItem(underlineItem, at: 0)
            originalMenu.insertItem(addNoteItem, at: 0)
            originalMenu.insertItem(highlightParentItem, at: 0)
        }
        // 3. Opção 2: Se clicou em qualquer ponto vazio da página (sem seleção e sem anotação prévia)
        else if clickedPage != nil {
            let addStickyItem = NSMenuItem(title: "Inserir Nota Adesiva Aqui...", action: #selector(handleAddStickyNoteAction(_:)), keyEquivalent: "")
            addStickyItem.target = self
            addStickyItem.image = NSImage(systemSymbolName: "note.text.badge.plus", accessibilityDescription: nil)

            originalMenu.insertItem(NSMenuItem.separator(), at: 0)
            originalMenu.insertItem(addStickyItem, at: 0)
        }

        // Adiciona opção para entrar/sair do Modo Apresentação no rodapé do menu
        originalMenu.addItem(NSMenuItem.separator())
        let presentationItem = NSMenuItem(
            title: "Modo Apresentação (Tela Cheia)",
            action: #selector(handlePresentationToggleAction(_:)),
            keyEquivalent: "f"
        )
        presentationItem.keyEquivalentModifierMask = [.command, .shift]
        presentationItem.target = self
        presentationItem.image = NSImage(systemSymbolName: "play.rectangle", accessibilityDescription: nil)
        originalMenu.addItem(presentationItem)

        return originalMenu
    }

    // MARK: - Ações de Anotação

    @objc private func handleHighlightColorAction(_ sender: NSMenuItem) {
        guard let color = sender.representedObject as? NSColor else { return }
        addAnnotation(type: .highlight, color: color)
    }

    @objc private func handleUnderlineAction(_ sender: NSMenuItem) {
        addAnnotation(type: .underline, color: NSColor.systemBlue)
    }

    @objc private func handleStrikeOutAction(_ sender: NSMenuItem) {
        addAnnotation(type: .strikeOut, color: NSColor.systemRed)
    }

    @objc private func handleRemoveAnnotationsAction(_ sender: NSMenuItem) {
        removeAnnotationsFromSelection()
    }

    @objc private func handlePresentationToggleAction(_ sender: NSMenuItem) {
        onPresentationModeToggle?()
    }

    @objc private func handleAddNoteToSelectionAction(_ sender: NSMenuItem) {
        triggerAddNoteForCurrentSelection()
    }

    @objc private func handleAddStickyNoteAction(_ sender: NSMenuItem) {
        guard let page = lastRightClickPage else { return }
        onRequestAddStickyNoteAtPoint?(page, lastRightClickPoint)
    }

    @objc private func handleEditClickedAnnotationAction(_ sender: NSMenuItem) {
        guard let anno = lastRightClickAnnotation, let page = lastRightClickPage else { return }
        onRequestEditNote?(anno, page)
    }

    @objc private func handleDeleteClickedAnnotationAction(_ sender: NSMenuItem) {
        guard let anno = lastRightClickAnnotation, let page = lastRightClickPage else { return }
        page.removeAnnotation(anno)
        onAnnotationAdded?()
    }

    public func triggerAddNoteForCurrentSelection() {
        guard let selection = currentSelection, let str = selection.string, !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onRequestAddNoteForSelection?(selection)
    }

    public func addAnnotation(type: PDFAnnotationSubtype, color: NSColor) {
        guard let selection = currentSelection else { return }
        for page in selection.pages {
            let bounds = selection.bounds(for: page)
            guard bounds.width > 0 && bounds.height > 0 else { continue }
            let annotation = PDFAnnotation(bounds: bounds, forType: type, withProperties: nil)
            annotation.color = color
            page.addAnnotation(annotation)
        }
        clearSelection()
        onAnnotationAdded?()
    }

    public func removeAnnotationsFromSelection() {
        guard let selection = currentSelection else { return }
        for page in selection.pages {
            let selBounds = selection.bounds(for: page)
            for annotation in page.annotations {
                if annotation.bounds.intersects(selBounds) {
                    page.removeAnnotation(annotation)
                }
            }
        }
        clearSelection()
        onAnnotationAdded?()
    }

    public func copyCurrentSelection() {
        guard let selection = currentSelection, let str = selection.string, !str.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(str, forType: .string)
    }

    // MARK: - Tradução Recursiva do Menu AppKit

    private static let menuTranslations: [String: String] = [
        "Copy": "Copiar",
        "Select All": "Selecionar Tudo",
        "Look Up": "Consultar no Dicionário",
        "Search with Google": "Pesquisar no Google",
        "Single Page Continuous": "Rolagem Contínua",
        "Single Page": "Página Única (Slide)",
        "Two Pages Continuous": "Duas Páginas Contínuas",
        "Two Pages": "Duas Páginas Lado a Lado",
        "Actual Size": "Tamanho Real (100%)",
        "Zoom In": "Aumentar Zoom",
        "Zoom Out": "Diminuir Zoom",
        "Zoom to Fit": "Ajustar à Janela",
        "Go to Page...": "Ir para a Página...",
        "Next Page": "Próxima Página",
        "Previous Page": "Página Anterior",
        "Go to Next Page": "Próxima Página",
        "Go to Previous Page": "Página Anterior",
        "First Page": "Primeira Página",
        "Last Page": "Última Página",
        "Highlight": "Realçar Texto",
        "Underline": "Sublinhar",
        "Strike Out": "Tachar",
        "Strikethrough": "Tachar",
        "Print...": "Imprimir...",
        "Share": "Compartilhar",
        "Rotate Left": "Girar para a Esquerda",
        "Rotate Right": "Girar para a Direita",
        "Open in Preview": "Abrir no Pré-Visualização",
        "Show Colors": "Mostrar Cores",
        "Add Note": "Adicionar Nota",
        "Delete": "Excluir",
        "Auto Resize": "Ajuste Automático"
    ]

    private func localizeMenu(_ menu: NSMenu) {
        for item in menu.items {
            item.title = translateTitle(item.title)
            if let submenu = item.submenu {
                localizeMenu(submenu)
            }
        }
    }

    private func translateTitle(_ title: String) -> String {
        if let direct = Self.menuTranslations[title] {
            return direct
        }

        // Casos dinâmicos como Look Up “palavra”
        if title.hasPrefix("Look Up “") {
            let query = title.replacingOccurrences(of: "Look Up “", with: "").replacingOccurrences(of: "”", with: "")
            return "Consultar “\(query)”"
        }
        if title.hasPrefix("Search with Google for “") {
            let query = title.replacingOccurrences(of: "Search with Google for “", with: "").replacingOccurrences(of: "”", with: "")
            return "Pesquisar “\(query)” no Google"
        }

        return title
    }
}
