import SwiftUI

/// Barra de controle de zoom flutuante, elegante e translúcida (estilo macOS Sonoma/Sequoia HIG).
public struct PDFZoomControlBar: View {
    @Binding public var scaleFactor: CGFloat
    @Binding public var autoScales: Bool
    public var currentPage: Int
    public var totalPages: Int

    public var onZoomIn: () -> Void
    public var onZoomOut: () -> Void
    public var onResetZoom: () -> Void
    public var onZoomToFit: () -> Void
    public var onSetZoomScale: (CGFloat) -> Void

    public init(
        scaleFactor: Binding<CGFloat>,
        autoScales: Binding<Bool>,
        currentPage: Int = 1,
        totalPages: Int = 1,
        onZoomIn: @escaping () -> Void,
        onZoomOut: @escaping () -> Void,
        onResetZoom: @escaping () -> Void,
        onZoomToFit: @escaping () -> Void,
        onSetZoomScale: @escaping (CGFloat) -> Void
    ) {
        self._scaleFactor = scaleFactor
        self._autoScales = autoScales
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.onZoomIn = onZoomIn
        self.onZoomOut = onZoomOut
        self.onResetZoom = onResetZoom
        self.onZoomToFit = onZoomToFit
        self.onSetZoomScale = onSetZoomScale
    }

    private var percentageString: String {
        let percent = Int(round(scaleFactor * 100.0))
        return "\(percent)%"
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Indicador de Página (ex: "1 de 100")
            Text("\(currentPage) de \(totalPages)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            // Separador vertical sutil
            Divider()
                .frame(height: 14)
                .opacity(0.4)

            // Botão Reduzir Zoom (-)
            Button {
                onZoomOut()
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Reduzir Zoom (⌘-)")
            .keyboardShortcut("-", modifiers: .command)

            // Slider elegante de Zoom contínuo (25% a 300%)
            Slider(
                value: Binding(
                    get: { scaleFactor },
                    set: { newScale in
                        autoScales = false
                        scaleFactor = newScale
                    }
                ),
                in: 0.25...3.0
            )
            .accessibilityLabel("Nível de Zoom")
            .frame(width: 85)
            .controlSize(.mini)

            // Botão Aumentar Zoom (+)
            Button {
                onZoomIn()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Aumentar Zoom (⌘+)")
            .keyboardShortcut("+", modifiers: .command)
            .keyboardShortcut("=", modifiers: .command)

            // Separador vertical sutil
            Divider()
                .frame(height: 14)
                .opacity(0.4)

            // Menu de percentuais e atalhos rápidos
            Menu {
                Button("Ajustar à Janela") {
                    onZoomToFit()
                }
                .keyboardShortcut("0", modifiers: [.command, .shift])

                Divider()

                Button("50%") { onSetZoomScale(0.5) }
                Button("75%") { onSetZoomScale(0.75) }
                Button("100% (Tamanho Real)") {
                    onResetZoom()
                }
                .keyboardShortcut("0", modifiers: .command)

                Button("125%") { onSetZoomScale(1.25) }
                Button("150%") { onSetZoomScale(1.5) }
                Button("200%") { onSetZoomScale(2.0) }
                Button("300%") { onSetZoomScale(3.0) }
            } label: {
                HStack(spacing: 3) {
                    Text(percentageString)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .monospacedDigit()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Opções de Escala")

            // Separador vertical sutil
            Divider()
                .frame(height: 14)
                .opacity(0.4)

            // Botão Ajustar à Janela
            Button {
                onZoomToFit()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(autoScales ? Color.accentColor : Color.primary)
                    .frame(width: 22, height: 22)
                    .background(
                        autoScales
                            ? RoundedRectangle(cornerRadius: 5).fill(Color.accentColor.opacity(0.18))
                            : nil
                    )
            }
            .buttonStyle(.plain)
            .help("Ajustar à Janela (⇧⌘0)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
        )
        .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 4)
    }
}
