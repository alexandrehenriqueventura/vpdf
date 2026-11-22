import SwiftUI
import AppKit
import PDFKit

/// Painel lateral retrátil de miniaturas para visualização, reordenação e edição estrutural de páginas PDF.
public struct PDFThumbnailsSidebar: View {
    public let document: PDFDocument?
    public let revisionID: UUID
    @Binding public var currentPage: Int
    public let totalPages: Int
    public let onSelectPage: (Int) -> Void
    public let onMovePage: (Int, Int) -> Void
    public let onMovePageUp: (Int) -> Void
    public let onMovePageDown: (Int) -> Void
    public let onMovePageToStart: (Int) -> Void
    public let onMovePageToEnd: (Int) -> Void
    public let onRotatePage: (Int, Bool) -> Void
    public let onRotateAllPages: (Bool) -> Void
    public let onDeletePage: (Int) -> Void
    public let onShowCompression: () -> Void
    public let onClose: () -> Void

    public init(
        document: PDFDocument?,
        revisionID: UUID,
        currentPage: Binding<Int>,
        totalPages: Int,
        onSelectPage: @escaping (Int) -> Void,
        onMovePage: @escaping (Int, Int) -> Void,
        onMovePageUp: @escaping (Int) -> Void,
        onMovePageDown: @escaping (Int) -> Void,
        onMovePageToStart: @escaping (Int) -> Void,
        onMovePageToEnd: @escaping (Int) -> Void,
        onRotatePage: @escaping (Int, Bool) -> Void,
        onRotateAllPages: @escaping (Bool) -> Void,
        onDeletePage: @escaping (Int) -> Void,
        onShowCompression: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.document = document
        self.revisionID = revisionID
        self._currentPage = currentPage
        self.totalPages = totalPages
        self.onSelectPage = onSelectPage
        self.onMovePage = onMovePage
        self.onMovePageUp = onMovePageUp
        self.onMovePageDown = onMovePageDown
        self.onMovePageToStart = onMovePageToStart
        self.onMovePageToEnd = onMovePageToEnd
        self.onRotatePage = onRotatePage
        self.onRotateAllPages = onRotateAllPages
        self.onDeletePage = onDeletePage
        self.onShowCompression = onShowCompression
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Cabeçalho do Painel de Páginas
            HStack(spacing: 8) {
                Label("Páginas (\(totalPages))", systemImage: "rectangle.split.2x1")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                // Botão de Compressão de PDF (Ícone corrigido)
                Button(action: onShowCompression) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                .help("Comprimir e reduzir tamanho do arquivo PDF")

                // Fechar Painel de Miniaturas
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Fechar painel de miniaturas")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))

            Divider()

            // Lista de Miniaturas com Reordenação
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 12) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        renderThumbnailItem(index: index)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
            }
        }
        .frame(minWidth: 195, idealWidth: 215, maxWidth: 240)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
    }

    @ViewBuilder
    private func renderThumbnailItem(index: Int) -> some View {
        let isSelected = (currentPage == index + 1)

        VStack(spacing: 6) {
            // Imagem da Miniatura da Página
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))

                if let doc = document, let page = doc.page(at: index) {
                    let thumb = page.thumbnail(of: CGSize(width: 140, height: 180), for: .cropBox)
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                        .padding(4)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .frame(width: 160, height: 195)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: isSelected ? 2.5 : 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onSelectPage(index + 1)
            }
            // Suporte a Arrastar e Soltar (Drag & Drop) para reordenação direta
            .onDrag {
                NSItemProvider(object: String(index) as NSString)
            }
            .onDrop(of: [.text], isTargeted: nil) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: NSString.self) { stringItem, _ in
                    guard let str = stringItem as? String, let sourceIndex = Int(str) else { return }
                    DispatchQueue.main.async {
                        onMovePage(sourceIndex, index)
                    }
                }
                return true
            }

            // Rótulo da Página, Reordenação (⬆/⬇) e Ações Rápidas (↺/↻/🗑)
            HStack(spacing: 3) {
                Text("\(index + 1)")
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(minWidth: 18, alignment: .leading)

                // Mover para Cima (▲)
                Button {
                    onMovePageUp(index)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 18, height: 20)
                }
                .buttonStyle(.plain)
                .disabled(index == 0)
                .background(Color.primary.opacity(index == 0 ? 0.02 : 0.06), in: RoundedRectangle(cornerRadius: 4))
                .help(index > 0 ? "Mover página para cima" : "Esta é a primeira página")

                // Mover para Baixo (▼)
                Button {
                    onMovePageDown(index)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 18, height: 20)
                }
                .buttonStyle(.plain)
                .disabled(index >= totalPages - 1)
                .background(Color.primary.opacity(index >= totalPages - 1 ? 0.02 : 0.06), in: RoundedRectangle(cornerRadius: 4))
                .help(index < totalPages - 1 ? "Mover página para baixo" : "Esta é a última página")

                Spacer()

                // Girar para a Esquerda (↺)
                Button {
                    onRotatePage(index, false)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 9, weight: .medium))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                .help("Girar página para a esquerda (90° anti-horário)")

                // Girar para a Direita (↻)
                Button {
                    onRotatePage(index, true)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9, weight: .medium))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                .help("Girar página para a direita (90° horário)")

                // Excluir Página (🗑️)
                Button {
                    onDeletePage(index)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(totalPages > 1 ? Color.red.opacity(0.85) : Color.secondary.opacity(0.4))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .disabled(totalPages <= 1)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                .help(totalPages > 1 ? "Excluir página \(index + 1)" : "Não é possível excluir a única página do documento")
            }
            .padding(.horizontal, 4)
        }
        .padding(6)
        .background(isSelected ? Color.accentColor.opacity(0.07) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            // Opções de Reordenação
            Button {
                onMovePageUp(index)
            } label: {
                Label("Mover para Cima", systemImage: "arrow.up")
            }
            .disabled(index == 0)

            Button {
                onMovePageDown(index)
            } label: {
                Label("Mover para Baixo", systemImage: "arrow.down")
            }
            .disabled(index >= totalPages - 1)

            Button {
                onMovePageToStart(index)
            } label: {
                Label("Mover para o Início (1ª Página)", systemImage: "arrow.up.to.line")
            }
            .disabled(index == 0)

            Button {
                onMovePageToEnd(index)
            } label: {
                Label("Mover para o Fim (Última Página)", systemImage: "arrow.down.to.line")
            }
            .disabled(index >= totalPages - 1)

            Divider()

            // Opções de Rotação
            Button {
                onRotatePage(index, true)
            } label: {
                Label("Girar para a Direita (90°)", systemImage: "arrow.clockwise")
            }

            Button {
                onRotatePage(index, false)
            } label: {
                Label("Girar para a Esquerda (90°)", systemImage: "arrow.counterclockwise")
            }

            Button {
                onRotatePage(index, true)
                onRotatePage(index, true)
            } label: {
                Label("Girar 180°", systemImage: "arrow.uturn.down")
            }

            Divider()

            Button {
                onRotateAllPages(true)
            } label: {
                Label("Girar Todas as Páginas para a Direita", systemImage: "rotate.right")
            }

            Button {
                onRotateAllPages(false)
            } label: {
                Label("Girar Todas as Páginas para a Esquerda", systemImage: "rotate.left")
            }

            Divider()

            Button(role: .destructive) {
                onDeletePage(index)
            } label: {
                Label("Excluir Página \(index + 1)", systemImage: "trash")
            }
            .disabled(totalPages <= 1)
        }
        .id("\(revisionID)-\(index)")
    }
}
