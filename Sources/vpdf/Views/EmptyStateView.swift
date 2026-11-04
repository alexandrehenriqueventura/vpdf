import SwiftUI

/// Tela exibida na área de detalhe quando nenhum arquivo estiver selecionado.
public struct EmptyStateView: View {
    public var onOpenFolder: () -> Void
    public var onConvertWord: (() -> Void)?

    public init(onOpenFolder: @escaping () -> Void, onConvertWord: (() -> Void)? = nil) {
        self.onOpenFolder = onOpenFolder
        self.onConvertWord = onConvertWord
    }

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        .frame(width: 80, height: 80)

                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.secondary)
                }

                Text("Nenhum Arquivo Selecionado")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Selecione um arquivo PDF na barra lateral para leitura, ou converta documentos Word (.docx) diretamente.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            HStack(spacing: 12) {
                Button(action: onOpenFolder) {
                    Label("Abrir Pasta...", systemImage: "folder")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                if let onConvertWord = onConvertWord {
                    Button(action: onConvertWord) {
                        Label("Converter Word (.docx) para PDF", systemImage: "doc.badge.arrow.up")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }

            Spacer()

            // Barra discreta de atalhos de produtividade na base
            HStack(spacing: 12) {
                Text("⌃⌘S Ocultar Barra Lateral")
                Text("•")
                Text("⌘F Buscar no Texto")
                Text("•")
                Text("⌘S Salvar Alterações")
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.tertiary)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
}
