import SwiftUI

/// Painel flutuante discreto do Modo Apresentação (Slides / Tela Cheia)
/// com controle de navegação e indicador de página ("Slide 3 de 20").
public struct PDFPresentationOverlay: View {
    public let currentPage: Int
    public let totalPages: Int
    public let onNext: () -> Void
    public let onPrevious: () -> Void
    public let onExit: () -> Void

    public init(
        currentPage: Int,
        totalPages: Int,
        onNext: @escaping () -> Void,
        onPrevious: @escaping () -> Void,
        onExit: @escaping () -> Void
    ) {
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.onNext = onNext
        self.onPrevious = onPrevious
        self.onExit = onExit
    }

    public var body: some View {
        HStack(spacing: 14) {
            // Slide Anterior
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .disabled(currentPage <= 1)
            .opacity(currentPage <= 1 ? 0.4 : 1.0)
            .help("Slide anterior (← ou Espaço)")

            // Indicador de Slide
            Text("Slide \(currentPage) de \(totalPages)")
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)

            // Próximo Slide
            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .disabled(currentPage >= totalPages)
            .opacity(currentPage >= totalPages ? 0.4 : 1.0)
            .help("Próximo slide (→ ou Espaço)")

            Divider()
                .frame(height: 18)
                .background(Color.white.opacity(0.3))

            // Sair da Apresentação
            Button(action: onExit) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 11, weight: .bold))
                    Text("Sair")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .frame(height: 30)
            }
            .buttonStyle(.plain)
            .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            .help("Sair do modo apresentação (Esc)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.75))
                .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }
}
