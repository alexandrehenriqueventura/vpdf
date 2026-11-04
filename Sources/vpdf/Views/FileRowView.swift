import SwiftUI

/// Linha de exibição de um nó (pasta ou arquivo) na árvore da barra lateral.
public struct FileRowView: View {
    public let item: FileItem
    public var onExpandDirectory: ((FileItem) -> Void)?

    public init(item: FileItem, onExpandDirectory: ((FileItem) -> Void)? = nil) {
        self.item = item
        self.onExpandDirectory = onExpandDirectory
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.systemIconName)
                .foregroundStyle(item.isDirectory ? Color.accentColor : Color.secondary)
                .frame(width: 16)

            Text(item.name)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            if !item.isDirectory && !item.fileExtension.isEmpty {
                Text(item.fileExtension.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
        .contentShape(Rectangle())
        .onAppear {
            if item.isDirectory && !item.isLoaded {
                onExpandDirectory?(item)
            }
        }
    }
}
