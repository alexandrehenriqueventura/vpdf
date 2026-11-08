import SwiftUI
import AppKit

/// Barra superior de abas de documentos no estilo nativo do macOS.
public struct DocumentTabBar: View {
    public let tabs: [DocumentTab]
    public let activeTabID: URL?
    public let onSelectTab: (DocumentTab) -> Void
    public let onCloseTab: (DocumentTab) -> Void

    public init(
        tabs: [DocumentTab],
        activeTabID: URL?,
        onSelectTab: @escaping (DocumentTab) -> Void,
        onCloseTab: @escaping (DocumentTab) -> Void
    ) {
        self.tabs = tabs
        self.activeTabID = activeTabID
        self.onSelectTab = onSelectTab
        self.onCloseTab = onCloseTab
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(tabs) { tab in
                        tabItemView(tab)
                            .id(tab.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .background(Color(NSColor.windowBackgroundColor).opacity(0.65))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(Color(NSColor.separatorColor).opacity(0.35)),
                alignment: .bottom
            )
            .onChange(of: activeTabID) { _, newID in
                if let newID = newID {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
        }
        .frame(height: 36)
    }

    @ViewBuilder
    private func tabItemView(_ tab: DocumentTab) -> some View {
        let isActive = tab.id == activeTabID

        HStack(spacing: 6) {
            // Ícone do tipo de arquivo
            Image(systemName: tab.fileItem.systemIconName)
                .font(.system(size: 11))
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)

            // Nome do arquivo
            Text(tab.title)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(isActive ? Color.primary : Color.secondary)

            // Indicador de alterações não salvas (ponto colorido)
            if tab.isDirty {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
                    .help("Alterações não salvas")
            }

            // Botão Fechar Aba
            Button {
                onCloseTab(tab)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(3)
                    .background(Color.secondary.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Fechar aba (⌘W)")
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isActive ? Color(NSColor.controlBackgroundColor) : Color.clear)
                .shadow(color: Color.black.opacity(isActive ? 0.06 : 0), radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isActive ? Color.primary.opacity(0.12) : Color.clear, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelectTab(tab)
        }
    }
}
