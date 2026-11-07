import SwiftUI
import AppKit

/// Ponte AppKit -> SwiftUI para NSTextView com alta performance para arquivos grandes,
/// suporte nativo a busca incremental e barra de busca do macOS.
public struct TextEditorRepresentable: NSViewRepresentable {
    @Binding public var text: String
    @Binding public var isDirty: Bool
    public var searchText: String
    @Binding public var currentSearchIndex: Int
    @Binding public var totalSearchMatches: Int

    public init(
        text: Binding<String>,
        isDirty: Binding<Bool>,
        searchText: String = "",
        currentSearchIndex: Binding<Int> = .constant(0),
        totalSearchMatches: Binding<Int> = .constant(0)
    ) {
        self._text = text
        self._isDirty = isDirty
        self.searchText = searchText
        self._currentSearchIndex = currentSearchIndex
        self._totalSearchMatches = totalSearchMatches
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let textView = NSTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.minSize = NSSize(width: 0.0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        // Configurações de tipografia e estilo
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = NSColor.textColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.drawsBackground = true

        // Funcionalidades de editor
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isIncrementalSearchingEnabled = true
        textView.usesFindBar = true

        textView.textContainerInset = NSSize(width: 36, height: 28)
        textView.delegate = context.coordinator

        scrollView.documentView = textView
        context.coordinator.textView = textView

        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }

        if !searchText.isEmpty && searchText != context.coordinator.lastSearchText {
            context.coordinator.lastSearchText = searchText
            context.coordinator.highlightSearchMatches(in: textView, for: searchText)
        } else if searchText.isEmpty && !context.coordinator.lastSearchText.isEmpty {
            context.coordinator.lastSearchText = ""
            context.coordinator.clearSearchHighlights(in: textView)
        } else if !searchText.isEmpty && context.coordinator.lastSearchIndex != currentSearchIndex {
            context.coordinator.navigateToMatch(at: currentSearchIndex, in: textView)
        }
    }

    public final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TextEditorRepresentable
        weak var textView: NSTextView?
        var lastSearchText: String = ""
        var searchMatches: [NSRange] = []
        var lastSearchIndex: Int = 0

        init(_ parent: TextEditorRepresentable) {
            self.parent = parent
        }

        public func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            if self.parent.text != tv.string {
                self.parent.text = tv.string
                self.parent.isDirty = true
            }
        }

        func highlightSearchMatches(in textView: NSTextView, for query: String) {
            guard let layoutManager = textView.layoutManager,
                  let textStorage = textView.textStorage else { return }

            let fullText = textStorage.string as NSString
            let fullRange = NSRange(location: 0, length: fullText.length)

            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
            searchMatches.removeAll()

            var searchRange = fullRange

            while searchRange.location < fullText.length {
                searchRange.length = fullText.length - searchRange.location
                let foundRange = fullText.range(of: query, options: .caseInsensitive, range: searchRange)
                if foundRange.location == NSNotFound { break }

                searchMatches.append(foundRange)

                // Destaca com amarelo suave padrão macOS
                layoutManager.addTemporaryAttribute(
                    .backgroundColor,
                    value: NSColor.systemYellow.withAlphaComponent(0.35),
                    forCharacterRange: foundRange
                )

                searchRange.location = foundRange.location + foundRange.length
            }

            let count = searchMatches.count
            lastSearchIndex = count > 0 ? 1 : 0

            DispatchQueue.main.async {
                self.parent.totalSearchMatches = count
                self.parent.currentSearchIndex = count > 0 ? 1 : 0
            }

            if let first = searchMatches.first {
                layoutManager.addTemporaryAttribute(
                    .backgroundColor,
                    value: NSColor.systemOrange.withAlphaComponent(0.6),
                    forCharacterRange: first
                )
                textView.scrollRangeToVisible(first)
            }
        }

        func navigateToMatch(at index: Int, in textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  !searchMatches.isEmpty,
                  index >= 1,
                  index <= searchMatches.count else { return }

            lastSearchIndex = index

            // Re-aplica cor suave a todas as ocorrências
            for range in searchMatches {
                layoutManager.addTemporaryAttribute(
                    .backgroundColor,
                    value: NSColor.systemYellow.withAlphaComponent(0.35),
                    forCharacterRange: range
                )
            }

            // Destaca a ocorrência ativa com cor âmbar/laranja
            let activeRange = searchMatches[index - 1]
            layoutManager.addTemporaryAttribute(
                .backgroundColor,
                value: NSColor.systemOrange.withAlphaComponent(0.6),
                forCharacterRange: activeRange
            )
            textView.scrollRangeToVisible(activeRange)
        }

        func clearSearchHighlights(in textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  let textStorage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: textStorage.string.count)
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
            searchMatches.removeAll()
            lastSearchIndex = 0
            DispatchQueue.main.async {
                self.parent.totalSearchMatches = 0
                self.parent.currentSearchIndex = 0
            }
        }
    }
}
