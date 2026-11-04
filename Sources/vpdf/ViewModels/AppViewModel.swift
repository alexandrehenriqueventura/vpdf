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

    // MARK: - Estado de Busca
    public var searchText: String = ""

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
        if selectedItem?.id == item.id { return }

        // Se houver alterações pendentes no arquivo atual, salva automaticamente
        if isDirty, selectedItem != nil {
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
            let data = try await conversionService.convert(
                text: documentText,
                from: sourceFormat,
                to: targetFormat,
                documentTitle: baseName
            )

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
}
