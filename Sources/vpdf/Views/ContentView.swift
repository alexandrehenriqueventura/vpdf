import SwiftUI

/// View principal do aplicativo, baseada em NavigationSplitView nativo do macOS.
@MainActor
public struct ContentView: View {
    public var viewModel: AppViewModel

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public init() {
        self.viewModel = AppViewModel()
    }

    public var body: some View {
        @Bindable var viewModel = viewModel

        NavigationSplitView(columnVisibility: $viewModel.columnVisibility) {
            // MARK: - Barra Lateral (Árvore de Diretórios)
            VStack(alignment: .leading, spacing: 0) {
                if let rootURL = viewModel.rootURL {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(Color.accentColor)
                        Text(rootURL.lastPathComponent)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                    Divider()
                }

                if viewModel.rootItems.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                        Text(viewModel.rootURL == nil ? "Nenhuma pasta aberta" : "Pasta vazia")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Button("Abrir Pasta...") {
                            Task { await viewModel.openFolder() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List(viewModel.rootItems, children: \.children) { (item: FileItem) in
                        if item.isPlaceholder {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.mini)
                                Text("Carregando...")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                        } else {
                            FileRowView(item: item) { folderToExpand in
                                Task {
                                    await viewModel.loadChildren(for: folderToExpand)
                                }
                            }
                            .tag(item.id)
                            .listRowBackground(
                                viewModel.selectedItem?.id == item.id
                                    ? RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.15))
                                    : nil
                            )
                            .onTapGesture {
                                if item.isDirectory {
                                    if !item.isLoaded {
                                        Task {
                                            await viewModel.loadChildren(for: item)
                                        }
                                    }
                                } else {
                                    Task {
                                        await viewModel.selectFile(item)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.sidebar)
                }
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 310, max: 450)
        } detail: {
            // MARK: - Área de Detalhe (Visualizador PDF / Editor de Texto / Empty State)
            if viewModel.selectedItem != nil {
                VStack(spacing: 0) {
                    if let pdfDoc = viewModel.pdfDocument {
                        PDFViewerRepresentable(
                            document: pdfDoc,
                            searchText: viewModel.searchText
                        )
                        .background(Color(NSColor.windowBackgroundColor))
                    } else {
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
                    }

                    StatusBarView(
                        encodingName: viewModel.detectedEncodingName,
                        wordCount: viewModel.wordCount,
                        charCount: viewModel.charCount,
                        lineCount: viewModel.lineCount,
                        isDirty: viewModel.isDirty
                    )
                }
            } else {
                EmptyStateView {
                    Task {
                        await viewModel.openFolder()
                    }
                }
            }
        }
        .toolbar {
            // MARK: - Barra de Ferramentas Superior
            ToolbarItemGroup(placement: .primaryAction) {
                // Abrir Pasta
                Button {
                    Task { await viewModel.openFolder() }
                } label: {
                    Label("Abrir Pasta", systemImage: "folder")
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .help("Abrir uma pasta no disco (⇧⌘O)")

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
        .searchable(text: $viewModel.searchText, placement: .toolbar, prompt: "Buscar no texto (⌘F)")
        .alert(isPresented: $viewModel.showErrorAlert, error: viewModel.activeError) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.errorDescription ?? "Ocorreu um erro inesperado.")
        }
        .navigationTitle(viewModel.selectedItem?.name ?? (viewModel.rootURL?.lastPathComponent ?? "vpdf"))
        .navigationSubtitle(viewModel.selectedItem != nil ? (viewModel.isDirty ? "Modificado" : "Salvo") : "")
    }
}
