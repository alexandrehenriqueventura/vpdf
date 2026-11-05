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

    public var onPresentationModeToggle: (() -> Void)?
    public var onAnnotationAdded: (() -> Void)?
    public var onSlideChanged: ((Int, Int) -> Void)?

    public override func keyDown(with event: NSEvent) {
        if isPresentationMode {
            switch event.keyCode {
            case 124, 125, 49: // Seta Direita, Seta Baixo, Barra de Espaço
                goToNextPage(nil)
                notifySlideChanged()
                return
            case 123, 126: // Seta Esquerda, Seta Cima
                goToPreviousPage(nil)
                notifySlideChanged()
                return
            case 53: // Escape
                onPresentationModeToggle?()
                return
            default:
                break
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

        // Se houver texto selecionado, enriquece o topo do menu com ações rápidas de anotação e cópia
        if let selection = currentSelection, let str = selection.string, !str.isEmpty {
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
            originalMenu.insertItem(highlightParentItem, at: 0)
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
