import MacDjVuCore
import SwiftUI

struct SearchHighlightOverlay: View {
    let pageNumber: Int
    @Environment(ViewerState.self) private var state

    var body: some View {
        let displayW = state.displayWidth
        let displayH = state.displayHeight(page: pageNumber)
        let nativeSize = state.pageSizes[pageNumber] ?? state.pageSizes[1]

        Canvas { context, _ in
            guard let nativeSize else { return }
            let pageText = state.pageTextCache[pageNumber]
            let displaySize = CGSize(width: displayW, height: displayH)

            for (matchIndex, match) in state.searchMatches.enumerated() where match.page == pageNumber {
                let isCurrent = matchIndex == state.currentMatchIndex
                let color: Color = isCurrent ? .orange : .yellow
                let opacity: Double = isCurrent ? 0.5 : 0.35

                for wordIndex in match.wordIndices {
                    guard wordIndex < (pageText?.words.count ?? 0),
                          let word = pageText?.words[wordIndex] else { continue }
                    let rect = DjVuRenderer.djvuToScreenRect(
                        word: word,
                        nativeSize: nativeSize,
                        displaySize: displaySize
                    )
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 2),
                        with: .color(color.opacity(opacity))
                    )
                }
            }
        }
        .frame(width: displayW, height: displayH)
        .allowsHitTesting(false)
    }
}
