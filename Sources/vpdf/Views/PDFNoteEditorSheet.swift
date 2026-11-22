import SwiftUI
import AppKit

/// Janela modal elegante para inserção e edição de notas/comentários em documentos PDF.
public struct PDFNoteEditorSheet: View {
    public let title: String
    public let isExisting: Bool
    @Binding public var noteText: String
    @Binding public var selectedColor: HighlightColorOption
    @FocusState private var isEditorFocused: Bool

    public let onSave: () -> Void
    public let onDelete: (() -> Void)?
    public let onCancel: () -> Void

    public init(
        title: String,
        isExisting: Bool = false,
        noteText: Binding<String>,
        selectedColor: Binding<HighlightColorOption>,
        onSave: @escaping () -> Void,
        onDelete: (() -> Void)? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.isExisting = isExisting
        self._noteText = noteText
        self._selectedColor = selectedColor
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Cabeçalho
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selectedColor.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                    Text("Anotação compatível com Pré-Visualização e Acrobat")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Seletor de Cores
            HStack(spacing: 8) {
                Text("Cor:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    ForEach(HighlightColorOption.allCases) { option in
                        Circle()
                            .fill(option.color)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(selectedColor == option ? 0.9 : 0.2), lineWidth: selectedColor == option ? 2 : 1)
                            )
                            .scaleEffect(selectedColor == option ? 1.15 : 1.0)
                            .onTapGesture {
                                selectedColor = option
                            }
                            .help(option.rawValue)
                    }
                }
            }

            // Área de Texto
            VStack(alignment: .leading, spacing: 4) {
                TextEditor(text: $noteText)
                    .font(.system(size: 13))
                    .focused($isEditorFocused)
                    .frame(height: 110)
                    .padding(6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
            }

            Divider()

            // Rodapé com botões de ação
            HStack {
                if isExisting, let onDelete = onDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Excluir Nota", systemImage: "trash")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Button("Cancelar") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Salvar Nota") {
                    let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 440)
        .background(.regularMaterial)
        .onAppear {
            isEditorFocused = true
        }
    }
}
