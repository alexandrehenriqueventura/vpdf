import SwiftUI
import AppKit
import PDFKit

/// Visualização principal do aplicativo vpdf com arquitetura SplitView moderna do macOS 14+ Sonoma.
@MainActor
public struct ContentView: View {
    @Bindable public var viewModel: AppViewModel

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public init() {
        self.viewModel = AppViewModel()
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $viewModel.columnVisibility) {
            sidebarContent
        } detail: {
            detailContent
        }
        .toolbar {
            toolbarItems
        }
        .onKeyPress(.rightArrow) {
            if viewModel.isPresentationMode {
                viewModel.nextSlide()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.leftArrow) {
            if viewModel.isPresentationMode {
                viewModel.previousSlide()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.space) {
            if viewModel.isPresentationMode {
                viewModel.nextSlide()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.escape) {
            if viewModel.isPresentationMode {
                viewModel.togglePresentationMode()
                return .handled
            } else if viewModel.isSearchPresented {
                viewModel.closeSearch()
                return .handled
            } else if viewModel.isAnnotationToolbarPresented {
                viewModel.isAnnotationToolbarPresented = false
                return .handled
            }
            return .ignored
        }
        .alert(isPresented: $viewModel.showErrorAlert, error: viewModel.activeError) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.errorDescription ?? "Ocorreu um erro inesperado.")
        }
        .onChange(of: viewModel.selectedItem) { _, newItem in
            if let item = newItem, !item.isDirectory {
                Task {
                    await viewModel.selectFile(item)
                }
            }
        }
        .navigationTitle(viewModel.selectedItem?.name ?? (viewModel.rootURL?.lastPathComponent ?? "vpdf"))
        .navigationSubtitle(viewModel.selectedItem != nil ? (viewModel.isDirty ? "Modificado" : "Salvo") : "")
    }

    // MARK: - Barra Lateral

    @ViewBuilder
    private var sidebarContent: some View {
        VStack(spacing: 0) {
            if viewModel.rootItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(.tertiary)

                    Text("Nenhuma pasta aberta")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    Button("Abrir Pasta...") {
                        Task { await viewModel.openFolder() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List(selection: $viewModel.selectedItem) {
                    Section {
                        ForEach(viewModel.rootItems) { item in
                            renderFileItem(item)
                        }
                    } header: {
                        HStack {
                            Text(viewModel.rootURL?.lastPathComponent ?? "Arquivos")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                Task { await viewModel.openFolder() }
                            } label: {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .help("Trocar pasta aberta")
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .navigationSplitViewColumnWidth(min: 240, ideal: 310, max: 450)
    }

    @ViewBuilder
    private func renderFileItem(_ item: FileItem) -> some View {
        if item.isDirectory {
            DisclosureGroup {
                if let children = item.children {
                    ForEach(children) { child in
                        AnyView(renderFileItem(child))
                    }
                }
            } label: {
                FileRowView(
                    item: item,
                    onExpandDirectory: { dir in
                        Task { await viewModel.loadChildren(for: dir) }
                    }
                )
                .tag(item)
                .contentShape(Rectangle())
                .onTapGesture {
                    Task { await viewModel.loadChildren(for: item) }
                }
            }
        } else {
            FileRowView(item: item)
                .tag(item)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectedItem = item
                    Task { await viewModel.selectFile(item) }
                }
        }
    }

    // MARK: - Área de Detalhe

    @ViewBuilder
    private var detailContent: some View {
        if viewModel.selectedItem != nil {
            VStack(spacing: 0) {
                if let pdfDoc = viewModel.pdfDocument {
                    pdfDetailView(pdfDoc)
                } else {
                    textEditorDetailView
                }

                if !viewModel.isPresentationMode {
                    StatusBarView(
                        encodingName: viewModel.detectedEncodingName,
                        wordCount: viewModel.wordCount,
                        charCount: viewModel.charCount,
                        lineCount: viewModel.lineCount,
                        isDirty: viewModel.isDirty
                    )
                }
            }
        } else {
            EmptyStateView(
                onOpenFolder: {
                    Task { await viewModel.openFolder() }
                },
                onConvertWord: {
                    Task { await viewModel.convertWordFileToPDF() }
                }
            )
        }
    }

    @ViewBuilder
    private func pdfDetailView(_ pdfDoc: PDFDocument) -> some View {
        ZStack(alignment: .bottom) {
            PDFViewerRepresentable(
                document: pdfDoc,
                isPresentationMode: viewModel.isPresentationMode,
                isSearchPresented: viewModel.isSearchPresented,
                searchQuery: viewModel.searchText,
                currentSearchIndex: $viewModel.currentSearchMatchIndex,
                totalSearchMatches: $viewModel.totalSearchMatches,
                scaleFactor: $viewModel.pdfScaleFactor,
                autoScales: $viewModel.pdfAutoScales,
                currentPage: $viewModel.pdfCurrentPage,
                totalPages: $viewModel.pdfTotalPages,
                annotationCommand: $viewModel.activeAnnotationCommand,
                onDocumentEdited: { viewModel.isDirty = true },
                onTogglePresentation: { viewModel.togglePresentationMode() }
            )
            .background(viewModel.isPresentationMode ? Color.black : Color(NSColor.windowBackgroundColor))

            // Se em Modo Apresentação, exibe HUD de slides
            if viewModel.isPresentationMode {
                PDFPresentationOverlay(
                    currentPage: viewModel.pdfCurrentPage,
                    totalPages: viewModel.pdfTotalPages,
                    onNext: { viewModel.nextSlide() },
                    onPrevious: { viewModel.previousSlide() },
                    onExit: { viewModel.togglePresentationMode() }
                )
                .padding(.bottom, 24)
            } else {
                // Barra flutuante elegante de zoom e página
                PDFZoomControlBar(
                    scaleFactor: $viewModel.pdfScaleFactor,
                    autoScales: $viewModel.pdfAutoScales,
                    currentPage: viewModel.pdfCurrentPage,
                    totalPages: viewModel.pdfTotalPages,
                    onZoomIn: { viewModel.zoomIn() },
                    onZoomOut: { viewModel.zoomOut() },
                    onResetZoom: { viewModel.resetZoom() },
                    onZoomToFit: { viewModel.setZoomToFit() },
                    onSetZoomScale: { scale in viewModel.setZoomScale(scale) }
                )
                .padding(.bottom, 16)
            }

            // Barra de Ferramentas de Seleção e Anotações (ao topo)
            if viewModel.isAnnotationToolbarPresented && !viewModel.isPresentationMode {
                VStack {
                    PDFAnnotationToolbar(
                        selectedColor: $viewModel.selectedHighlightColor,
                        onHighlight: { opt in viewModel.applyAnnotation(.highlight(opt)) },
                        onUnderline: { viewModel.applyAnnotation(.underline) },
                        onStrikeOut: { viewModel.applyAnnotation(.strikeOut) },
                        onCopy: { viewModel.applyAnnotation(.copy) },
                        onRemoveAnnotation: { viewModel.applyAnnotation(.remove) },
                        onClose: { viewModel.isAnnotationToolbarPresented = false }
                    )
                    .padding(.top, 12)
                    Spacer()
                }
            }

            // Barra de Busca Integrada (ao topo à direita)
            if viewModel.isSearchPresented && !viewModel.isPresentationMode {
                VStack {
                    HStack {
                        Spacer()
                        PDFSearchBar(
                            searchQuery: $viewModel.searchText,
                            currentMatch: viewModel.currentSearchMatchIndex,
                            totalMatches: viewModel.totalSearchMatches,
                            onNext: { viewModel.searchNext() },
                            onPrevious: { viewModel.searchPrevious() },
                            onClose: { viewModel.closeSearch() }
                        )
                        .padding(.trailing, 16)
                        .padding(.top, 12)
                    }
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private var textEditorDetailView: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)

                TextEditorRepresentable(
                    text: $viewModel.documentText,
                    isDirty: $viewModel.isDirty,
                    searchText: viewModel.searchText
                )
                .frame(maxWidth: 880)
                .background(Color(NSColor.textBackgroundColor))
                .overlay(
                    Rectangle()
                        .frame(width: 1)
                        .foregroundStyle(Color(NSColor.separatorColor).opacity(0.35)),
                    alignment: .leading
                )
                .overlay(
                    Rectangle()
                        .frame(width: 1)
                        .foregroundStyle(Color(NSColor.separatorColor).opacity(0.35)),
                    alignment: .trailing
                )

                Spacer(minLength: 0)
            }
            .background(Color(NSColor.windowBackgroundColor).opacity(0.4))

            if viewModel.isSearchPresented {
                PDFSearchBar(
                    searchQuery: $viewModel.searchText,
                    currentMatch: 0,
                    totalMatches: 0,
                    onNext: { },
                    onPrevious: { },
                    onClose: { viewModel.closeSearch() }
                )
                .padding(.trailing, 16)
                .padding(.top, 12)
            }
        }
    }

    // MARK: - Barra de Ferramentas Superior

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            // Modo Apresentação em Tela Cheia (Slides)
            Button {
                viewModel.togglePresentationMode()
            } label: {
                Label(
                    viewModel.isPresentationMode ? "Sair da Apresentação" : "Apresentação",
                    systemImage: viewModel.isPresentationMode ? "arrow.down.right.and.arrow.up.left" : "play.rectangle"
                )
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(viewModel.pdfDocument == nil)
            .help("Modo Apresentação em Tela Cheia para Slides (⇧⌘F)")

            // Ferramentas de Seleção e Marca-Texto
            Button {
                viewModel.toggleAnnotationToolbar()
            } label: {
                Label("Anotações e Marcações", systemImage: "highlighter")
            }
            .disabled(viewModel.pdfDocument == nil)
            .help("Exibir ferramentas de seleção, marca-texto, sublinhado e cópia")

            // Buscar no Documento
            Button {
                viewModel.toggleSearch()
            } label: {
                Label("Buscar", systemImage: "magnifyingglass")
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(viewModel.selectedItem == nil)
            .help("Buscar palavras e frases no documento (⌘F)")

            Divider()

            // Abrir Pasta
            Button {
                Task { await viewModel.openFolder() }
            } label: {
                Label("Abrir Pasta", systemImage: "folder")
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .help("Abrir uma pasta no disco (⇧⌘O)")

            // Converter Word para PDF
            Button {
                Task { await viewModel.convertWordFileToPDF() }
            } label: {
                Label("Converter Word (.docx) para PDF", systemImage: "doc.badge.arrow.up")
            }
            .help("Selecionar e converter arquivo Word (.docx / .doc) para PDF")

            // Salvar Arquivo Atual
            Button {
                Task { await viewModel.saveCurrentFile() }
            } label: {
                Label("Salvar", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(viewModel.selectedItem == nil || !viewModel.isDirty)
            .help("Salvar alterações (⌘S)")

            // Menu de Conversão e Exportação
            Menu {
                ForEach(ConversionFormat.allCases) { format in
                    Button(format.displayName) {
                        viewModel.selectedConversionFormat = format
                        Task {
                            await viewModel.convertAndExport(to: format)
                        }
                    }
                }
            } label: {
                Label("Converter para...", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(viewModel.selectedItem == nil)
            .help("Converter documento aberto para outro formato")

            // Exportar Direto no Formato Selecionado
            Button {
                Task {
                    await viewModel.convertAndExport(to: viewModel.selectedConversionFormat)
                }
            } label: {
                Label("Exportar (\(viewModel.selectedConversionFormat.rawValue.uppercased()))", systemImage: "square.and.arrow.up")
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(viewModel.selectedItem == nil)
            .help("Exportar o documento ativo (⇧⌘E)")
        }
    }
}
