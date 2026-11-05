import SwiftUI

/// Barra de busca flutuante e responsiva (estilo Safari / Preview no macOS)
/// com contador de ocorrências ("3 de 15") e navegação anterior/próxima.
public struct PDFSearchBar: View {
    @Binding public var searchQuery: String
    public let currentMatch: Int
    public let totalMatches: Int
    public let onNext: () -> Void
    public let onPrevious: () -> Void
    public let onClose: () -> Void

    @FocusState private var isFieldFocused: Bool

    public init(
        searchQuery: Binding<String>,
        currentMatch: Int,
        totalMatches: Int,
        onNext: @escaping () -> Void,
        onPrevious: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self._searchQuery = searchQuery
        self.currentMatch = currentMatch
        self.totalMatches = totalMatches
        self.onNext = onNext
        self.onPrevious = onPrevious
        self.onClose = onClose
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Buscar no documento...", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFieldFocused)
                .onSubmit {
                    onNext()
                }
                .frame(minWidth: 160, idealWidth: 200, maxWidth: 260)

            // Contador de resultados
            if !searchQuery.isEmpty {
                if totalMatches > 0 {
                    Text("\(currentMatch) de \(totalMatches)")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                } else {
                    Text("Nenhum resultado")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.red.opacity(0.85))
                        .padding(.horizontal, 4)
                }
            }

            Divider()
                .frame(height: 16)
                .opacity(0.4)

            // Botão Anterior
            Button(action: onPrevious) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(totalMatches == 0)
            .help("Ocorrência anterior (⇧↵)")

            // Botão Próximo
            Button(action: onNext) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(totalMatches == 0)
            .help("Próxima ocorrência (↵)")

            Divider()
                .frame(height: 16)
                .opacity(0.4)

            // Botão Fechar
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(3)
                    .background(Color.secondary.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Fechar busca (Esc)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
        .onAppear {
            isFieldFocused = true
        }
    }
}
