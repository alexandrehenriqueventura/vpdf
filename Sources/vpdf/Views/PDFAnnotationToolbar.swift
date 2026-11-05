import SwiftUI
import AppKit

public enum HighlightColorOption: String, CaseIterable, Identifiable {
    case yellow = "Amarelo"
    case green = "Verde"
    case blue = "Azul"
    case pink = "Rosa"

    public var id: String { rawValue }

    private var rgbComponents: (r: CGFloat, g: CGFloat, b: CGFloat) {
        switch self {
        case .yellow: return (1.0, 0.88, 0.3)
        case .green: return (0.5, 0.88, 0.55)
        case .blue: return (0.45, 0.75, 1.0)
        case .pink: return (1.0, 0.6, 0.72)
        }
    }

    public var color: Color {
        let (r, g, b) = rgbComponents
        return Color(red: r, green: g, blue: b)
    }

    public var nsColor: NSColor {
        let (r, g, b) = rgbComponents
        return NSColor(red: r, green: g, blue: b, alpha: 0.55)
    }
}

/// Barra de ferramentas de seleção e anotação de texto (marcadores de cor, sublinhado, tachado e cópia rápida).
public struct PDFAnnotationToolbar: View {
    @Binding public var selectedColor: HighlightColorOption
    public let onHighlight: (HighlightColorOption) -> Void
    public let onUnderline: () -> Void
    public let onStrikeOut: () -> Void
    public let onCopy: () -> Void
    public let onRemoveAnnotation: () -> Void
    public let onClose: () -> Void

    public init(
        selectedColor: Binding<HighlightColorOption>,
        onHighlight: @escaping (HighlightColorOption) -> Void,
        onUnderline: @escaping () -> Void,
        onStrikeOut: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onRemoveAnnotation: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self._selectedColor = selectedColor
        self.onHighlight = onHighlight
        self.onUnderline = onUnderline
        self.onStrikeOut = onStrikeOut
        self.onCopy = onCopy
        self.onRemoveAnnotation = onRemoveAnnotation
        self.onClose = onClose
    }

    public var body: some View {
        HStack(spacing: 10) {
            // Seletor de Cores do Marca-Texto
            HStack(spacing: 6) {
                ForEach(HighlightColorOption.allCases) { option in
                    Circle()
                        .fill(option.color)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(selectedColor == option ? 0.9 : 0.2), lineWidth: selectedColor == option ? 2 : 1)
                        )
                        .scaleEffect(selectedColor == option ? 1.15 : 1.0)
                        .onTapGesture {
                            selectedColor = option
                            onHighlight(option)
                        }
                        .help("Realçar com \(option.rawValue)")
                }
            }
            .padding(.horizontal, 4)

            // Botão de Realce Primário
            Button {
                onHighlight(selectedColor)
            } label: {
                Label("Realçar", systemImage: "highlighter")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(selectedColor.color.opacity(0.85))
            .foregroundStyle(Color.black.opacity(0.85))
            .help("Realçar texto selecionado com a cor ativa")

            Divider()
                .frame(height: 18)
                .opacity(0.4)

            // Sublinhar
            Button(action: onUnderline) {
                Image(systemName: "underline")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            .help("Sublinhar texto selecionado")

            // Tachar
            Button(action: onStrikeOut) {
                Image(systemName: "strikethrough")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            .help("Tachar texto selecionado")

            // Limpar Realces
            Button(action: onRemoveAnnotation) {
                Image(systemName: "eraser")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            .help("Remover marcações e realces da seleção")

            Divider()
                .frame(height: 18)
                .opacity(0.4)

            // Copiar Seleção
            Button {
                onCopy()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                    Text("Copiar")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 8)
                .frame(height: 26)
            }
            .buttonStyle(.plain)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            .help("Copiar texto selecionado (⌘C)")

            Divider()
                .frame(height: 18)
                .opacity(0.4)

            // Fechar Barra de Anotações
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .background(Color.secondary.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Fechar ferramentas de seleção")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
    }
}
