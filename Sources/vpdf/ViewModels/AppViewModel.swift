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

    // MARK: - Serviços Injetados
    private let fileSystemService: FileSystemService
    private let encodingService: EncodingService
    private let conversionService: ConversionService

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
        guard let url = await fileSystemService.selectFolder() else {
            return
        }
        self.rootURL = url
        self.selectedItem = nil
        self.documentText = ""
        self.isDirty = false
        await loadRootItems(for: url)
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

    // MARK: - Ações de Arquivo

    /// Seleciona e carrega o arquivo na área principal (suporta TXT, MD, RTF, HTML e PDF).
    public func selectFile(_ item: FileItem) async {
        guard !item.isDirectory else { return }
        if selectedItem?.id == item.id && (pdfDocument != nil || !documentText.isEmpty) { return }

        // Se houver alterações pendentes no arquivo atual, salva automaticamente
        if isDirty, let current = selectedItem, current.id != item.id {
            await saveCurrentFile()
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await fileSystemService.readFileData(at: item.url)
            let ext = item.fileExtension

            // Extração de texto para documentos PDF
            if ext == "pdf" {
                guard let pdfDoc = PDFDocument(data: data) else {
                    throw AppError.conversionFailed("Documento PDF inválido ou protegido.")
                }

                var extractedText = ""
                for pageIndex in 0..<pdfDoc.pageCount {
                    if let page = pdfDoc.page(at: pageIndex), let pageString = page.string {
                        extractedText += pageString + "\n"
                    }
                }

                self.selectedItem = item
                self.pdfDocument = pdfDoc
                self.pdfAutoScales = true
                self.pdfScaleFactor = 1.0
                self.pdfCurrentPage = 1
                self.pdfTotalPages = max(1, pdfDoc.pageCount)
                self.documentText = extractedText.trimmingCharacters(in: .newlines)
                self.detectedEncoding = .utf8
                self.detectedEncodingName = "PDF (\(pdfDoc.pageCount) pág\(pdfDoc.pageCount == 1 ? "" : "s"))"
                self.isDirty = false
                return
            }

            // Para outros documentos, limpa o PDF ativo
            self.pdfDocument = nil

            // Extração de texto para documentos RTF
            if ext == "rtf" {
                if let attributedString = try? NSAttributedString(
                    data: data,
                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
                ) {
                    self.selectedItem = item
                    self.documentText = attributedString.string
                    self.detectedEncoding = .utf8
                    self.detectedEncodingName = "RTF (Rich Text)"
                    self.isDirty = false
                    return
                }
            }

            // Detecção precisa de codificação para arquivos de texto (.txt, .md, .html, etc.)
            let result = try encodingService.decode(data: data)

            self.selectedItem = item
            self.documentText = result.content
            self.detectedEncoding = result.encoding
            self.detectedEncodingName = result.encodingName
            self.isDirty = false
        } catch let appError as AppError {
            presentError(appError)
        } catch {
            presentError(.fileNotFound(item.url))
        }
    }

    /// Salva o conteúdo editado no arquivo aberto.
    public func saveCurrentFile() async {
        guard let item = selectedItem, isDirty else { return }

        do {
            if item.fileExtension == "rtf" {
                let rtfData = try conversionService.convertToRTF(text: documentText, from: .rtf)
                try await Task.detached {
                    try rtfData.write(to: item.url, options: .atomic)
                }.value
            } else {
                try await fileSystemService.saveText(documentText, to: item.url, encoding: detectedEncoding)
            }
            self.isDirty = false
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

            // Salva o arquivo .pdf no mesmo diretório de origem
            let targetURL = wordURL.deletingPathExtension().appendingPathExtension("pdf")
            try pdfData.write(to: targetURL, options: .atomic)

            // Se estiver dentro da pasta aberta na barra lateral, atualiza a árvore
            if let root = rootURL {
                await loadRootItems(for: root)
            }

            // Exibe imediatamente o PDF convertido no visualizador
            if let generatedDoc = PDFDocument(data: pdfData) {
                self.selectedItem = FileItem(url: targetURL, isDirectory: false)
                self.pdfDocument = generatedDoc
                self.pdfAutoScales = true
                self.pdfScaleFactor = 1.0
                self.detectedEncodingName = "PDF (\(generatedDoc.pageCount) pág\(generatedDoc.pageCount == 1 ? "" : "s"))"
                self.isDirty = false
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
