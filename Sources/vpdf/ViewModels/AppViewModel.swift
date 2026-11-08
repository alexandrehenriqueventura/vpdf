import Foundation
import SwiftUI
import Observation
import AppKit
import UniformTypeIdentifiers
import PDFKit

/// ViewModel principal da aplicação, utilizando o framework Observation do macOS 14+.
@Observable
@MainActor
public final class AppViewModel {
    // MARK: - Estado de Navegação e Sistema de Arquivos
    public var rootURL: URL?
    public var rootItems: [FileItem] = []
    public var selectedItem: FileItem?
    public private(set) var currentLoadedURL: URL? = nil
    public var columnVisibility: NavigationSplitViewVisibility = .automatic

    // MARK: - Estado do Documento Ativo
    public var documentText: String = ""
    public var pdfDocument: PDFDocument? = nil
    public var detectedEncoding: String.Encoding = .utf8
    public var detectedEncodingName: String = "UTF-8"
    public var isDirty: Bool = false
    public var isLoading: Bool = false

    // MARK: - Estado de Zoom e Paginação do Visualizador PDF
    public var pdfScaleFactor: CGFloat = 1.0
    public var pdfAutoScales: Bool = true
    public var pdfCurrentPage: Int = 1
    public var pdfTotalPages: Int = 1

    // MARK: - Estado do Modo Apresentação (Slides / Tela Cheia)
    public var isPresentationMode: Bool = false

    // MARK: - Estado de Busca Aprimorada
    public var searchText: String = ""
    public var isSearchPresented: Bool = false
    public var currentSearchMatchIndex: Int = 0
    public var totalSearchMatches: Int = 0

    // MARK: - Estado da Barra de Seleção e Anotações
    public var isAnnotationToolbarPresented: Bool = false
    public var selectedHighlightColor: HighlightColorOption = .yellow
    public var activeAnnotationCommand: AnnotationCommand? = nil

    // MARK: - Formato de Conversão Selecionado
    public var selectedConversionFormat: ConversionFormat = .pdf

    // MARK: - Tratamento de Erros
    public var activeError: AppError?
    public var showErrorAlert: Bool = false

    // MARK: - Alerta de Alterações Não Salvas
    public var showUnsavedChangesAlert: Bool = false
    public var pendingItemToSelect: FileItem? = nil

    // MARK: - Sistema de Abas (Tabs)
    public var openTabs: [DocumentTab] = []
    public var activeTabID: URL? = nil
    private var tabStates: [URL: DocumentTabState] = [:]
    public var pendingTabToClose: DocumentTab? = nil
    public var showCloseTabUnsavedAlert: Bool = false

    // MARK: - Restauração de Zoom na Apresentação
    private var prePresentationScaleFactor: CGFloat = 1.0
    private var prePresentationAutoScales: Bool = true

    // MARK: - Serviços Injetados
    private let fileSystemService: FileSystemService
    private let encodingService: EncodingService
    private let conversionService: ConversionService
    private var fileLoadTask: Task<Void, Never>? = nil

    public init(
        fileSystemService: FileSystemService = .shared,
        encodingService: EncodingService = .shared,
        conversionService: ConversionService = .shared
    ) {
        self.fileSystemService = fileSystemService
        self.encodingService = encodingService
        self.conversionService = conversionService

        // Restaura permissão segura da sessão anterior, se existente
        restorePreviousSession()
    }

    // MARK: - Métricas do Documento
    public var lineCount: Int {
        documentText.isEmpty ? 0 : documentText.components(separatedBy: .newlines).count
    }

    public var wordCount: Int {
        let trimmed = documentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        return trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }

    public var charCount: Int {
        documentText.count
    }

    public var lineEnding: String {
        if documentText.contains("\r\n") {
            return "CRLF"
        } else if documentText.contains("\r") {
            return "CR"
        } else {
            return "LF"
        }
    }

    // MARK: - Ações de Diretório

    /// Restaura diretório autorizado da sessão anterior.
    public func restorePreviousSession() {
        if let restoredURL = fileSystemService.restorePersistedDirectory() {
            self.rootURL = restoredURL
            Task {
                await loadRootItems(for: restoredURL)
            }
        }
    }

    /// Abre diálogo nativo para seleção de pasta.
    public func openFolder() async {
        do {
            guard let url = try await fileSystemService.selectFolder() else {
                return
            }
            self.rootURL = url
            self.openTabs.removeAll()
            self.tabStates.removeAll()
            self.activeTabID = nil
            self.selectedItem = nil
            self.currentLoadedURL = nil
            self.pdfDocument = nil
            self.documentText = ""
            self.isDirty = false
            await loadRootItems(for: url)
        } catch let appError as AppError {
            presentError(appError)
        } catch {
            presentError(.securityScopedBookmarkFailed(error.localizedDescription))
        }
    }

    /// Carrega os itens do primeiro nível da pasta raiz.
    private func loadRootItems(for url: URL) async {
        isLoading = true
        defer { isLoading = false }

        do {
            self.rootItems = try await fileSystemService.contentsOfDirectory(at: url)
        } catch let appError as AppError {
            presentError(appError)
        } catch {
            presentError(.permissionDenied(url))
        }
    }

    /// Carrega os filhos sob demanda (lazy loading) para uma subpasta.
    public func loadChildren(for item: FileItem) async {
        guard item.isDirectory else { return }

        do {
            let children = try await fileSystemService.contentsOfDirectory(at: item.url)
            updateChildren(in: &rootItems, for: item.id, with: children)
        } catch let appError as AppError {
            presentError(appError)
        } catch {
            presentError(.permissionDenied(item.url))
        }
    }

    private func updateChildren(in items: inout [FileItem], for targetID: URL, with newChildren: [FileItem]) {
        for i in 0..<items.count {
            if items[i].id == targetID {
                items[i].children = newChildren
                items[i].isLoaded = true
                return
            }
            if var subChildren = items[i].children {
                updateChildren(in: &subChildren, for: targetID, with: newChildren)
                items[i].children = subChildren
            }
        }
    }

    // MARK: - Ações de Arquivo e Abas

    /// Seleciona uma aba ativa e restaura seu documento e estado.
    public func selectTab(_ tab: DocumentTab) {
        saveActiveTabState()

        guard let state = tabStates[tab.id] else { return }
        self.activeTabID = tab.id
        self.selectedItem = state.fileItem
        self.currentLoadedURL = state.fileItem.url
        self.pdfDocument = state.pdfDocument
        self.documentText = state.documentText
        self.detectedEncoding = state.detectedEncoding
        self.detectedEncodingName = state.detectedEncodingName
        self.isDirty = state.isDirty
        self.pdfCurrentPage = state.pdfCurrentPage
        self.pdfTotalPages = state.pdfTotalPages
        self.pdfScaleFactor = state.pdfScaleFactor
        self.pdfAutoScales = state.pdfAutoScales
    }

    /// Salva o estado atual da aba ativa no cache em memória.
    private func saveActiveTabState() {
        guard let currentID = activeTabID, let state = tabStates[currentID] else { return }
        state.isDirty = self.isDirty
        state.documentText = self.documentText
        state.pdfDocument = self.pdfDocument
        state.pdfCurrentPage = self.pdfCurrentPage
        state.pdfTotalPages = self.pdfTotalPages
        state.pdfScaleFactor = self.pdfScaleFactor
        state.pdfAutoScales = self.pdfAutoScales

        if let idx = openTabs.firstIndex(where: { $0.id == currentID }) {
            openTabs[idx].isDirty = self.isDirty
        }
    }

    /// Notifica que o documento ativo sofreu edições (marca-texto, sublinhado, digitação, etc.).
    public func markCurrentDocumentEdited() {
        self.isDirty = true
        if let currentID = activeTabID {
            tabStates[currentID]?.isDirty = true
            if let idx = openTabs.firstIndex(where: { $0.id == currentID }) {
                openTabs[idx].isDirty = true
            }
        }
    }

    /// Solicita fechamento de uma aba, alertando se houver alterações não salvas.
    public func requestCloseTab(_ tab: DocumentTab) async {
        saveActiveTabState()
        let isTabDirty = tabStates[tab.id]?.isDirty ?? tab.isDirty
        if isTabDirty {
            pendingTabToClose = tab
            showCloseTabUnsavedAlert = true
            return
        }
        closeTab(tab)
    }

    /// Confirma o salvamento e fecha a aba pendente.
    public func confirmSaveAndCloseTab() async {
        showCloseTabUnsavedAlert = false
        guard let tab = pendingTabToClose else { return }
        if tab.id == activeTabID {
            await saveCurrentFile()
        } else if let state = tabStates[tab.id] {
            await saveTabStateDirectly(state)
        }
        closeTab(tab)
        pendingTabToClose = nil
    }

    /// Descarta alterações e fecha a aba pendente.
    public func confirmDiscardAndCloseTab() {
        showCloseTabUnsavedAlert = false
        guard let tab = pendingTabToClose else { return }
        closeTab(tab)
        pendingTabToClose = nil
    }

    /// Cancela fechamento da aba pendente.
    public func cancelCloseTab() {
        showCloseTabUnsavedAlert = false
        pendingTabToClose = nil
    }

    /// Fecha a aba especificada e atualiza a aba ativa.
    public func closeTab(_ tab: DocumentTab) {
        guard let index = openTabs.firstIndex(where: { $0.id == tab.id }) else { return }
        openTabs.remove(at: index)
        tabStates.removeValue(forKey: tab.id)

        if activeTabID == tab.id {
            if openTabs.isEmpty {
                activeTabID = nil
                selectedItem = nil
                currentLoadedURL = nil
                pdfDocument = nil
                documentText = ""
                isDirty = false
            } else {
                let newIndex = min(index, openTabs.count - 1)
                selectTab(openTabs[newIndex])
            }
        }
    }

    /// Salva diretamente o estado de uma aba não ativa.
    private func saveTabStateDirectly(_ state: DocumentTabState) async {
        let item = state.fileItem
        do {
            if item.fileExtension == "pdf", let pdfDoc = state.pdfDocument {
                guard fileSystemService.isURLWithinSandboxScope(item.url) else { return }
                await Task.detached(priority: .userInitiated) {
                    _ = pdfDoc.write(to: item.url)
                }.value
            } else if item.fileExtension == "rtf" {
                let rtfData = try conversionService.convertToRTF(text: state.documentText, from: .rtf)
                try await Task.detached {
                    try rtfData.write(to: item.url, options: .atomic)
                }.value
            } else {
                try await fileSystemService.saveText(state.documentText, to: item.url, encoding: state.detectedEncoding)
            }
            state.isDirty = false
        } catch {}
    }

    /// Solicita seleção de arquivo abrindo em uma aba ou alternando para a aba existente.
    public func requestSelectFile(_ item: FileItem) async {
        guard !item.isDirectory else { return }
        await selectFile(item)
    }

    /// Abre o arquivo diretamente em uma nova aba (ou foca na aba caso já esteja aberto).
    public func openInNewTab(_ item: FileItem) async {
        guard !item.isDirectory else { return }
        await selectFile(item)
    }

    /// Confirma o salvamento e prossegue com a abertura do arquivo pendente.
    public func confirmSaveAndLoadPending() async {
        showUnsavedChangesAlert = false
        if let pending = pendingItemToSelect {
            await saveCurrentFile()
            await selectFile(pending)
            pendingItemToSelect = nil
        }
    }

    /// Descarta alterações não salvas e abre o arquivo pendente.
    public func confirmDiscardAndLoadPending() async {
        showUnsavedChangesAlert = false
        isDirty = false
        if let pending = pendingItemToSelect {
            await selectFile(pending)
            pendingItemToSelect = nil
        }
    }

    /// Cancela a seleção do arquivo pendente e mantém o documento atual aberto.
    public func cancelPendingSelection() {
        showUnsavedChangesAlert = false
        pendingItemToSelect = nil
    }

    /// Seleciona e carrega o arquivo em uma aba (suporta TXT, MD, RTF, HTML e PDF).
    public func selectFile(_ item: FileItem) async {
        guard !item.isDirectory else { return }

        // Se o arquivo já está aberto em uma aba, alterna para ela imediatamente
        if let existingTab = openTabs.first(where: { $0.id == item.url }) {
            selectTab(existingTab)
            return
        }

        // Salva estado da aba ativa antes de carregar a nova
        saveActiveTabState()

        // Cancela qualquer tarefa de carregamento anterior ainda em execução
        fileLoadTask?.cancel()

        let targetURL = item.url
        let ext = item.fileExtension

        isLoading = true

        fileLoadTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            defer {
                if !Task.isCancelled {
                    self.isLoading = false
                }
            }

            do {
                let data = try await self.fileSystemService.readFileData(at: targetURL)
                guard !Task.isCancelled else { return }

                // Extração e montagem para documentos PDF
                if ext == "pdf" {
                    guard let pdfDoc = PDFDocument(data: data) ?? PDFDocument(url: targetURL) else {
                        throw AppError.conversionFailed("Documento PDF inválido ou protegido.")
                    }

                    guard !Task.isCancelled else { return }
                    let state = DocumentTabState(
                        fileItem: item,
                        pdfDocument: pdfDoc,
                        documentText: "",
                        detectedEncoding: .utf8,
                        detectedEncodingName: "PDF (\(pdfDoc.pageCount) pág\(pdfDoc.pageCount == 1 ? "" : "s"))",
                        isDirty: false,
                        pdfCurrentPage: 1,
                        pdfTotalPages: max(1, pdfDoc.pageCount),
                        pdfScaleFactor: 1.0,
                        pdfAutoScales: true
                    )
                    self.tabStates[targetURL] = state
                    self.openTabs.append(DocumentTab(fileItem: item, isDirty: false))
                    self.selectTab(DocumentTab(fileItem: item, isDirty: false))

                    // Extração de texto assíncrona em background para busca ou conversões sem travar a interface
                    Task.detached(priority: .utility) {
                        var extractedText = ""
                        for pageIndex in 0..<min(pdfDoc.pageCount, 100) {
                            if let page = pdfDoc.page(at: pageIndex), let pageString = page.string {
                                extractedText += pageString + "\n"
                            }
                        }
                        let trimmed = extractedText.trimmingCharacters(in: .newlines)
                        await MainActor.run { [weak self] in
                            if let self = self {
                                self.tabStates[targetURL]?.documentText = trimmed
                                if self.activeTabID == targetURL {
                                    self.documentText = trimmed
                                }
                            }
                        }
                    }
                    return
                }

                // Extração de texto para documentos RTF
                if ext == "rtf" {
                    if let attributedString = try? NSAttributedString(
                        data: data,
                        options: [.documentType: NSAttributedString.DocumentType.rtf],
                        documentAttributes: nil
                    ) {
                        guard !Task.isCancelled else { return }
                        let state = DocumentTabState(
                            fileItem: item,
                            pdfDocument: nil,
                            documentText: attributedString.string,
                            detectedEncoding: .utf8,
                            detectedEncodingName: "RTF (Rich Text)",
                            isDirty: false
                        )
                        self.tabStates[targetURL] = state
                        self.openTabs.append(DocumentTab(fileItem: item, isDirty: false))
                        self.selectTab(DocumentTab(fileItem: item, isDirty: false))
                        return
                    }
                }

                // Detecção precisa de codificação para arquivos de texto (.txt, .md, .html, etc.)
                let result = try self.encodingService.decode(data: data)
                guard !Task.isCancelled else { return }

                let state = DocumentTabState(
                    fileItem: item,
                    pdfDocument: nil,
                    documentText: result.content,
                    detectedEncoding: result.encoding,
                    detectedEncodingName: result.encodingName,
                    isDirty: false
                )
                self.tabStates[targetURL] = state
                self.openTabs.append(DocumentTab(fileItem: item, isDirty: false))
                self.selectTab(DocumentTab(fileItem: item, isDirty: false))
            } catch {
                guard !Task.isCancelled else { return }
                self.presentError(.permissionDenied(targetURL))
            }
        }

        await fileLoadTask?.value
    }

    /// Salva o conteúdo editado no arquivo aberto.
    public func saveCurrentFile() async {
        guard let item = selectedItem, isDirty else { return }

        do {
            if item.fileExtension == "pdf", let pdfDoc = self.pdfDocument {
                guard fileSystemService.isURLWithinSandboxScope(item.url) else {
                    throw AppError.permissionDenied(item.url)
                }
                try await Task.detached(priority: .userInitiated) {
                    guard pdfDoc.write(to: item.url) else {
                        throw AppError.saveFailed("Não foi possível gravar as alterações no arquivo PDF.")
                    }
                }.value
            } else if item.fileExtension == "rtf" {
                let rtfData = try conversionService.convertToRTF(text: documentText, from: .rtf)
                try await Task.detached {
                    try rtfData.write(to: item.url, options: .atomic)
                }.value
            } else {
                try await fileSystemService.saveText(documentText, to: item.url, encoding: detectedEncoding)
            }
            self.isDirty = false
            if let currentID = activeTabID {
                tabStates[currentID]?.isDirty = false
                if let idx = openTabs.firstIndex(where: { $0.id == currentID }) {
                    openTabs[idx].isDirty = false
                }
            }
        } catch let appError as AppError {
            presentError(appError)
        } catch {
            presentError(.saveFailed(error.localizedDescription))
        }
    }

    // MARK: - Ações de Conversão e Exportação

    /// Converte o arquivo aberto para o formato especificado e exibe diálogo de salvar.
    public func convertAndExport(to targetFormat: ConversionFormat) async {
        guard let item = selectedItem else { return }

        let sourceFormat = ConversionFormat.from(url: item.url) ?? .txt
        let baseName = item.url.deletingPathExtension().lastPathComponent
        let defaultExportName = "\(baseName).\(targetFormat.fileExtension)"

        isLoading = true
        defer { isLoading = false }

        do {
            let data: Data
            // Se o documento aberto for um PDF e o destino for Word (.docx / .doc), preserva a formatação original completa
            if let pdfDoc = self.pdfDocument, (targetFormat == .docx || targetFormat == .doc) {
                data = try conversionService.convertPDFDocumentToWord(document: pdfDoc, format: targetFormat)
            } else {
                data = try await conversionService.convert(
                    text: documentText,
                    from: sourceFormat,
                    to: targetFormat,
                    documentTitle: baseName
                )
            }

            promptSaveFile(data: data, defaultFilename: defaultExportName, uniformType: targetFormat.uniformType)
        } catch let appError as AppError {
            presentError(appError)
        } catch {
            presentError(.conversionFailed(error.localizedDescription))
        }
    }

    /// Exibe diálogo NSSavePanel para gravar o arquivo convertido.
    private func promptSaveFile(data: Data, defaultFilename: String, uniformType: UniformTypeIdentifiers.UTType) {
        let savePanel = NSSavePanel()
        savePanel.title = "Exportar Documento Convertido"
        savePanel.nameFieldStringValue = defaultFilename
        savePanel.allowedContentTypes = [uniformType]
        savePanel.canCreateDirectories = true

        let response = savePanel.runModal()
        guard response == .OK, let destinationURL = savePanel.url else {
            return
        }

        do {
            try data.write(to: destinationURL, options: .atomic)
        } catch {
            presentError(.saveFailed("Falha ao exportar o arquivo: \(error.localizedDescription)"))
        }
    }

    // MARK: - Exibição de Erros

    public func presentError(_ error: AppError) {
        self.activeError = error
        self.showErrorAlert = true
    }

    // MARK: - Ações de Zoom do PDF

    public func zoomIn() {
        pdfAutoScales = false
        pdfScaleFactor = min(pdfScaleFactor * 1.25, 5.0)
    }

    public func zoomOut() {
        pdfAutoScales = false
        pdfScaleFactor = max(pdfScaleFactor / 1.25, 0.25)
    }

    public func resetZoom() {
        pdfAutoScales = false
        pdfScaleFactor = 1.0
    }

    public func setZoomToFit() {
        pdfAutoScales = true
    }

    public func setZoomScale(_ scale: CGFloat) {
        pdfAutoScales = false
        pdfScaleFactor = max(0.25, min(scale, 5.0))
    }

    // MARK: - Conversão Nativa de Arquivos Word (.docx / .doc) para PDF

    /// Abre diálogo nativo para selecionar um arquivo Word (.docx ou .doc), converte para PDF e abre na tela.
    public func convertWordFileToPDF() async {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType("org.openxmlformats.wordprocessingml.document") ?? .data,
            UTType("com.microsoft.word.doc") ?? .data
        ]
        panel.prompt = "Converter para PDF"
        panel.message = "Selecione um arquivo Word (.docx ou .doc) para converter:"

        guard panel.runModal() == .OK, let wordURL = panel.url else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await fileSystemService.readFileData(at: wordURL)
            let ext = wordURL.pathExtension.lowercased()
            let format: ConversionFormat = (ext == "doc") ? .doc : .docx
            let pdfData = try conversionService.convertWordToPDF(data: data, format: format)

            // Salva o arquivo .pdf evitando sobrescrita acidental se já existir arquivo homônimo
            let defaultTargetURL = wordURL.deletingPathExtension().appendingPathExtension("pdf")
            let targetURL: URL
            if FileManager.default.fileExists(atPath: defaultTargetURL.path) {
                let savePanel = NSSavePanel()
                savePanel.title = "Salvar PDF Convertido"
                savePanel.message = "O arquivo '\(defaultTargetURL.lastPathComponent)' já existe. Escolha onde salvar ou confirme o destino:"
                savePanel.nameFieldStringValue = defaultTargetURL.lastPathComponent
                savePanel.directoryURL = wordURL.deletingLastPathComponent()
                savePanel.allowedContentTypes = [.pdf]
                savePanel.prompt = "Salvar"

                guard savePanel.runModal() == .OK, let chosenURL = savePanel.url else { return }
                targetURL = chosenURL
            } else {
                targetURL = defaultTargetURL
            }

            try pdfData.write(to: targetURL, options: .atomic)

            // Se estiver dentro da pasta aberta na barra lateral, atualiza a árvore
            if let root = rootURL {
                await loadRootItems(for: root)
            }

            // Exibe imediatamente o PDF convertido no visualizador e em uma nova aba
            if let generatedDoc = PDFDocument(data: pdfData) {
                let convertedItem = FileItem(url: targetURL, isDirectory: false)
                let state = DocumentTabState(
                    fileItem: convertedItem,
                    pdfDocument: generatedDoc,
                    documentText: "",
                    detectedEncoding: .utf8,
                    detectedEncodingName: "PDF (\(generatedDoc.pageCount) pág\(generatedDoc.pageCount == 1 ? "" : "s"))",
                    isDirty: false,
                    pdfCurrentPage: 1,
                    pdfTotalPages: max(1, generatedDoc.pageCount),
                    pdfScaleFactor: 1.0,
                    pdfAutoScales: true
                )
                self.tabStates[targetURL] = state
                if !self.openTabs.contains(where: { $0.id == targetURL }) {
                    self.openTabs.append(DocumentTab(fileItem: convertedItem, isDirty: false))
                }
                self.selectTab(DocumentTab(fileItem: convertedItem, isDirty: false))
            }
        } catch let appError as AppError {
            presentError(appError)
        } catch {
            presentError(.conversionFailed("Falha na conversão de \(wordURL.lastPathComponent): \(error.localizedDescription)"))
        }
    }

    // MARK: - Ações do Modo Apresentação (Slides / Tela Cheia)

    public func togglePresentationMode() {
        isPresentationMode.toggle()
        if isPresentationMode {
            prePresentationScaleFactor = pdfScaleFactor
            prePresentationAutoScales = pdfAutoScales
            columnVisibility = .detailOnly
            pdfAutoScales = true
            isSearchPresented = false
            isAnnotationToolbarPresented = false
            // Se janela disponível, alterna modo tela cheia
            if let window = NSApp.keyWindow, !window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
        } else {
            columnVisibility = .automatic
            pdfAutoScales = prePresentationAutoScales
            pdfScaleFactor = prePresentationScaleFactor
            if let window = NSApp.keyWindow, window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
        }
    }

    public func nextSlide() {
        guard let doc = pdfDocument else { return }
        if pdfCurrentPage < doc.pageCount {
            pdfCurrentPage += 1
        }
    }

    public func previousSlide() {
        if pdfCurrentPage > 1 {
            pdfCurrentPage -= 1
        }
    }

    // MARK: - Ações da Ferramenta de Busca

    public func toggleSearch() {
        isSearchPresented.toggle()
        if !isSearchPresented {
            closeSearch()
        }
    }

    public func closeSearch() {
        isSearchPresented = false
        searchText = ""
        currentSearchMatchIndex = 0
        totalSearchMatches = 0
    }

    public func searchNext() {
        guard totalSearchMatches > 0 else { return }
        if currentSearchMatchIndex >= totalSearchMatches {
            currentSearchMatchIndex = 1
        } else {
            currentSearchMatchIndex += 1
        }
    }

    public func searchPrevious() {
        guard totalSearchMatches > 0 else { return }
        if currentSearchMatchIndex <= 1 {
            currentSearchMatchIndex = totalSearchMatches
        } else {
            currentSearchMatchIndex -= 1
        }
    }

    // MARK: - Ações de Seleção e Anotações

    public func toggleAnnotationToolbar() {
        isAnnotationToolbarPresented.toggle()
    }

    public func applyAnnotation(_ command: AnnotationCommand) {
        self.activeAnnotationCommand = command
        if command != .copy {
            self.isDirty = true
        }
    }
}
