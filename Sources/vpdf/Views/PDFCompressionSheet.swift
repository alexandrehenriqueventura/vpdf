import SwiftUI
import AppKit

/// Janela modal moderna para configuração e execução de compressão de arquivos PDF.
public struct PDFCompressionSheet: View {
    public let fileName: String
    public let isCompressing: Bool
    public let compressionResult: (data: Data, originalSize: Int64, compressedSize: Int64)?
    @Binding public var selectedLevel: CompressionLevel
    public let onLevelChange: (CompressionLevel) -> Void
    public let onApplyToCurrent: () -> Void
    public let onExportCopy: (URL) -> Void
    public let onCancel: () -> Void

    public init(
        fileName: String,
        isCompressing: Bool,
        compressionResult: (data: Data, originalSize: Int64, compressedSize: Int64)?,
        selectedLevel: Binding<CompressionLevel>,
        onLevelChange: @escaping (CompressionLevel) -> Void,
        onApplyToCurrent: @escaping () -> Void,
        onExportCopy: @escaping (URL) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.fileName = fileName
        self.isCompressing = isCompressing
        self.compressionResult = compressionResult
        self._selectedLevel = selectedLevel
        self.onLevelChange = onLevelChange
        self.onApplyToCurrent = onApplyToCurrent
        self.onExportCopy = onExportCopy
        self.onCancel = onCancel
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Cabeçalho
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Comprimir Arquivo PDF")
                        .font(.system(size: 15, weight: .bold))
                    Text(fileName)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Seleção de Nível de Compressão
            VStack(alignment: .leading, spacing: 8) {
                Text("Nível de Otimização:")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)

                Picker("", selection: $selectedLevel) {
                    ForEach(CompressionLevel.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedLevel) { _, newLevel in
                    onLevelChange(newLevel)
                }

                Text(selectedLevel.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }

            // Painel Comparativo de Tamanhos
            VStack(spacing: 8) {
                if isCompressing {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Otimizando e recalculando streams do PDF...")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 14)
                } else if let result = compressionResult {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tamanho Original")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(formatBytes(result.originalSize))
                                .font(.system(size: 14, weight: .bold))
                        }

                        Spacer()

                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Tamanho Comprimido")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 4) {
                                Text(formatBytes(result.compressedSize))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.green)

                                if result.originalSize > 0 && result.compressedSize < result.originalSize {
                                    let percent = Double(result.originalSize - result.compressedSize) / Double(result.originalSize) * 100.0
                                    Text("(-\(Int(percent))%)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.green)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            Divider()

            // Botões de Ação
            HStack {
                Button("Cancelar") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                // Exportar Como Cópia
                Button {
                    promptExportSavePanel()
                } label: {
                    Label("Exportar Cópia...", systemImage: "square.and.arrow.up")
                }
                .disabled(isCompressing || compressionResult == nil)

                // Salvar no Arquivo Atual
                Button("Substituir Arquivo Atual") {
                    onApplyToCurrent()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(isCompressing || compressionResult == nil)
            }
        }
        .padding(18)
        .frame(width: 460)
        .background(.regularMaterial)
    }

    private func promptExportSavePanel() {
        guard compressionResult != nil else { return }
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        let originalBase = (fileName as NSString).deletingPathExtension
        panel.nameFieldStringValue = "\(originalBase)_comprimido.pdf"
        panel.allowedContentTypes = [.pdf]
        panel.prompt = "Exportar PDF"

        if panel.runModal() == .OK, let destinationURL = panel.url {
            onExportCopy(destinationURL)
        }
    }
}
