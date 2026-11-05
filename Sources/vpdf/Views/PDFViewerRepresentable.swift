import SwiftUI
import AppKit
import PDFKit

/// Comando para aplicação de anotações no visualizador PDF
public enum AnnotationCommand: Equatable {
    case highlight(HighlightColorOption)
    case underline
    case strikeOut
    case copy
    case remove
}

/// Visualizador nativo de documentos PDF utilizando VPDFView (subclasse com suporte a pt-BR, anotações e apresentação).
public struct PDFViewerRepresentable: NSViewRepresentable {
    public let document: PDFDocument?
    public var isPresentationMode: Bool
    public var isSearchPresented: Bool
    public var searchQuery: String
    @Binding public var currentSearchIndex: Int
    @Binding public var totalSearchMatches: Int
    @Binding public var scaleFactor: CGFloat
    @Binding public var autoScales: Bool
    @Binding public var currentPage: Int
    @Binding public var totalPages: Int
    @Binding public var annotationCommand: AnnotationCommand?
    public var onDocumentEdited: (() -> Void)?
    public var onTogglePresentation: (() -> Void)?

    public init(
        document: PDFDocument?,
        isPresentationMode: Bool = false,
        isSearchPresented: Bool = false,
        searchQuery: String = "",
        currentSearchIndex: Binding<Int>,
        totalSearchMatches: Binding<Int>,
        scaleFactor: Binding<CGFloat>,
        autoScales: Binding<Bool>,
        currentPage: Binding<Int>,
        totalPages: Binding<Int>,
        annotationCommand: Binding<AnnotationCommand?>,
        onDocumentEdited: (() -> Void)? = nil,
        onTogglePresentation: (() -> Void)? = nil
    ) {
        self.document = document
        self.isPresentationMode = isPresentationMode
        self.isSearchPresented = isSearchPresented
        self.searchQuery = searchQuery
        self._currentSearchIndex = currentSearchIndex
        self._totalSearchMatches = totalSearchMatches
        self._scaleFactor = scaleFactor
        self._autoScales = autoScales
        self._currentPage = currentPage
        self._totalPages = totalPages
        self._annotationCommand = annotationCommand
        self.onDocumentEdited = onDocumentEdited
        self.onTogglePresentation = onTogglePresentation
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> VPDFView {
        let pdfView = VPDFView()
        pdfView.autoScales = autoScales
        pdfView.displayMode = isPresentationMode ? .singlePage : .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = !isPresentationMode
        pdfView.backgroundColor = isPresentationMode ? .black : NSColor.windowBackgroundColor

        let coordinator = context.coordinator
        pdfView.onPresentationModeToggle = { [weak coordinator] in
            coordinator?.parent.onTogglePresentation?()
        }

        pdfView.onAnnotationAdded = { [weak coordinator] in
            coordinator?.parent.onDocumentEdited?()
        }

        pdfView.onSlideChanged = { [weak coordinator] cur, tot in
            DispatchQueue.main.async {
                coordinator?.parent.currentPage = cur
                coordinator?.parent.totalPages = tot
            }
        }

        context.coordinator.attach(to: pdfView)
        return pdfView
    }

    public func updateNSView(_ pdfView: VPDFView, context: Context) {
        context.coordinator.parent = self

        // Sincroniza modo de Apresentação
        if pdfView.isPresentationMode != isPresentationMode {
            pdfView.isPresentationMode = isPresentationMode
        }

        // Sincroniza documento
        if pdfView.document !== document {
            pdfView.document = document
            context.coordinator.lastSearchQuery = ""
            context.coordinator.allSearchSelections = []
            DispatchQueue.main.async {
                self.totalSearchMatches = 0
                self.currentSearchIndex = 0
            }
            if autoScales {
                pdfView.autoScales = true
            }
            if let doc = document {
                let total = max(1, doc.pageCount)
                let current = (doc.index(for: pdfView.currentPage ?? doc.page(at: 0) ?? PDFPage())) + 1
                if totalPages != total { totalPages = total }
                if currentPage != current { currentPage = max(1, current) }
            }
        }

        // Sincroniza estado de Zoom
        if !isPresentationMode {
            if autoScales {
                if !pdfView.autoScales {
                    pdfView.autoScales = true
                }
            } else {
                if pdfView.autoScales {
                    pdfView.autoScales = false
                }
                if abs(pdfView.scaleFactor - scaleFactor) > 0.01 {
                    pdfView.scaleFactor = scaleFactor
                }
            }
        }

        // Executa comandos de anotação
        if let command = annotationCommand {
            DispatchQueue.main.async {
                self.annotationCommand = nil
            }
            switch command {
            case .highlight(let option):
                pdfView.addAnnotation(type: .highlight, color: option.nsColor)
            case .underline:
                pdfView.addAnnotation(type: .underline, color: .systemBlue)
            case .strikeOut:
                pdfView.addAnnotation(type: .strikeOut, color: .systemRed)
            case .copy:
                pdfView.copyCurrentSelection()
            case .remove:
                pdfView.removeAnnotationsFromSelection()
            }
        }

        // Sincroniza Busca de Texto
        if isSearchPresented && !searchQuery.isEmpty {
            if searchQuery != context.coordinator.lastSearchQuery {
                context.coordinator.lastSearchQuery = searchQuery
                let results = document?.findString(searchQuery, withOptions: [.caseInsensitive]) ?? []
                context.coordinator.allSearchSelections = results
                DispatchQueue.main.async {
                    self.totalSearchMatches = results.count
                    self.currentSearchIndex = results.isEmpty ? 0 : 1
                }
                pdfView.highlightedSelections = results
                if let first = results.first {
                    pdfView.go(to: first)
                    pdfView.setCurrentSelection(first, animate: true)
                }
            } else if currentSearchIndex > 0 && currentSearchIndex <= context.coordinator.allSearchSelections.count {
                let target = context.coordinator.allSearchSelections[currentSearchIndex - 1]
                if pdfView.currentSelection !== target {
                    pdfView.go(to: target)
                    pdfView.setCurrentSelection(target, animate: true)
                }
            }
        } else if (!isSearchPresented || searchQuery.isEmpty) && !context.coordinator.lastSearchQuery.isEmpty {
            context.coordinator.lastSearchQuery = ""
            context.coordinator.allSearchSelections = []
            DispatchQueue.main.async {
                self.totalSearchMatches = 0
                self.currentSearchIndex = 0
            }
            pdfView.highlightedSelections = nil
            pdfView.clearSelection()
        }
    }

    public final class Coordinator: NSObject {
        var parent: PDFViewerRepresentable
        weak var pdfView: VPDFView?
        var lastSearchQuery: String = ""
        var allSearchSelections: [PDFSelection] = []

        init(_ parent: PDFViewerRepresentable) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func attach(to view: VPDFView) {
            self.pdfView = view
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(pdfScaleChanged(_:)),
                name: .PDFViewScaleChanged,
                object: view
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(pdfPageChanged(_:)),
                name: .PDFViewPageChanged,
                object: view
            )
        }

        @objc private func pdfPageChanged(_ notification: Notification) {
            guard let view = pdfView, let doc = view.document, let current = view.currentPage else { return }
            let pageIndex = doc.index(for: current)
            let total = max(1, doc.pageCount)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let newPage = pageIndex + 1
                if self.parent.currentPage != newPage {
                    self.parent.currentPage = newPage
                }
                if self.parent.totalPages != total {
                    self.parent.totalPages = total
                }
            }
        }

        @objc private func pdfScaleChanged(_ notification: Notification) {
            guard let view = pdfView, !self.parent.isPresentationMode else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if abs(self.parent.scaleFactor - view.scaleFactor) > 0.01 {
                    self.parent.scaleFactor = view.scaleFactor
                }
                if self.parent.autoScales != view.autoScales {
                    self.parent.autoScales = view.autoScales
                }
            }
        }
    }
}
