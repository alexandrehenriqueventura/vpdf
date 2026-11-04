import SwiftUI

/// Barra de rodapé nativa macOS com informações de codificação, linhas, palavras e estado de salvamento.
public struct StatusBarView: View {
    public let encodingName: String
    public let wordCount: Int
    public let charCount: Int
    public let lineCount: Int
    public let isDirty: Bool

    public init(
        encodingName: String,
        wordCount: Int,
        charCount: Int,
        lineCount: Int,
        isDirty: Bool
    ) {
        self.encodingName = encodingName
        self.wordCount = wordCount
        self.charCount = charCount
        self.lineCount = lineCount
        self.isDirty = isDirty
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Indicador de Codificação e Quebra de Linha
            HStack(spacing: 6) {
                Text(encodingName)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                Text("LF")
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }

            Spacer()

            // Métricas de Leitura
            HStack(spacing: 8) {
                Text("\(wordCount) palavras")
                Text("•")
                Text("\(charCount) caracteres")
                Text("•")
                Text("\(lineCount) linhas")
            }
            .foregroundStyle(.secondary)

            Spacer()

            // Estado de Modificação
            HStack(spacing: 6) {
                Circle()
                    .fill(isDirty ? Color.orange : Color.green)
                    .frame(width: 7, height: 7)

                Text(isDirty ? "Modificado" : "Salvo")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color(NSColor.separatorColor)),
            alignment: .top
        )
    }
}
